-- BidLens Open Data: worked DuckDB queries.
--
-- Run against a local download:
--   hf download NodeNovaOrg/bidlens-open-data --repo-type dataset --local-dir bidlens-open-data
--   cd bidlens-open-data && duckdb -init examples/queries.sql
-- or replace 'data/' with 'hf://datasets/NodeNovaOrg/bidlens-open-data/data/' to read remotely.

CREATE OR REPLACE VIEW notices          AS SELECT * FROM 'data/notices/*.parquet';
CREATE OR REPLACE VIEW criteria         AS SELECT * FROM 'data/criteria/*.parquet';
CREATE OR REPLACE VIEW outcomes         AS SELECT * FROM 'data/outcomes/*.parquet';
CREATE OR REPLACE VIEW buyers           AS SELECT * FROM 'data/buyers/*.parquet';
CREATE OR REPLACE VIEW suppliers        AS SELECT * FROM 'data/suppliers/*.parquet';
CREATE OR REPLACE VIEW criterion_roles  AS SELECT * FROM 'data/criterion_roles/*.parquet';
CREATE OR REPLACE VIEW frameworks       AS SELECT * FROM 'data/frameworks/*.parquet';
CREATE OR REPLACE VIEW buyer_routes     AS SELECT * FROM 'data/buyer_routes/*.parquet';

-- What a criterion actually is: the role where known, else the TED column it came from.
CREATE OR REPLACE VIEW criteria_roled AS
SELECT c.*,
       CASE WHEN r.role IS NOT NULL AND r.role <> 'unknown' THEN r.role
            WHEN c.criterion_type IN ('price', 'quality') THEN c.criterion_type
            ELSE 'unknown' END AS role
FROM criteria c LEFT JOIN criterion_roles r ON r.name = c.name;

-- 1. Price / quality / social value split per UK authority, averaged over lots.
--    UK-native feeds only. Lots whose scheme has a weighted non-competed or undisclosed line
--    are dropped whole, and zero-weight non-scoring lines are ignored.
WITH lots AS (
    SELECT notice_id, lot_id, buyer_name,
           sum(weight_pct) FILTER (WHERE role = 'price')        AS price,
           sum(weight_pct) FILTER (WHERE role = 'quality')      AS quality,
           sum(weight_pct) FILTER (WHERE role = 'social_value') AS social_value,
           bool_or(role IN ('not_competed', 'undisclosed', 'unsplit') AND weight_value > 0) AS no_contest
    FROM criteria_roled
    WHERE source IN ('fts_bulk_xml', 'fts_api') AND lot_id IS NOT NULL AND weight_pct IS NOT NULL
    GROUP BY ALL
)
SELECT b.canonical_name,
       count(*) AS lots,
       round(avg(coalesce(price, 0)), 1)        AS price_pct,
       round(avg(coalesce(quality, 0)), 1)      AS quality_pct,
       round(avg(coalesce(social_value, 0)), 1) AS social_value_pct
FROM lots JOIN buyers b ON b.buyer_name = lots.buyer_name AND b.buyer_id IS NOT NULL
WHERE NOT no_contest
GROUP BY b.buyer_id, b.canonical_name
HAVING count(*) >= 10
ORDER BY lots DESC
LIMIT 25;

-- 2. How competitive is a sector? Median bids per award, UK-native feeds, by CPV division.
SELECT n.cpv_division,
       count(*)                     AS awards_with_bid_count,
       median(o.n_bids)             AS median_bids,
       round(avg((o.n_bids = 1)::INT) * 100, 1) AS pct_single_bid
FROM outcomes o
JOIN notices n USING (source, notice_id)
WHERE o.source IN ('fts_bulk_xml', 'fts_api', 'contracts_finder') AND o.n_bids IS NOT NULL
GROUP BY 1 HAVING count(*) >= 200
ORDER BY pct_single_bid DESC;

-- 3. Who wins, resolved to one identity per company (never group on the raw name).
SELECT s.canonical_name, s.company_number,
       count(*) AS awards, count(DISTINCT o.buyer_name) AS buyer_spellings
FROM outcomes o JOIN suppliers s ON s.winner_name = o.winner_name
WHERE o.source IN ('fts_bulk_xml', 'fts_api', 'contracts_finder') AND s.supplier_id IS NOT NULL
GROUP BY s.supplier_id, s.canonical_name, s.company_number
ORDER BY awards DESC
LIMIT 25;

-- 4. Framework dilution: headline ceiling vs mean share per appointed supplier.
SELECT canonical_name, ceiling, n_suppliers, round(per_supplier) AS per_supplier, currency
FROM frameworks
WHERE shape = 'framework' AND ceiling > 0 AND n_suppliers >= 21
ORDER BY ceiling DESC
LIMIT 25;

-- 5. How much of an authority's work was ever open to a bid (all sectors).
SELECT canonical_name, sum(n_awards) AS awards,
       round(100.0 * sum(n_competed) / nullif(sum(n_awards - n_unknown), 0), 1) AS pct_competed,
       sum(n_direct) AS direct, sum(n_framework) AS via_framework
FROM buyer_routes
GROUP BY buyer_id, canonical_name
HAVING sum(n_awards - n_unknown) >= 50
ORDER BY pct_competed
LIMIT 25;

-- 6. UK tenders still open when the snapshot was cut (stage, not a date filter, separates a
--    competition from a plan). A snapshot is not live: for today's tenders, read Find a Tender.
WITH cut AS (
    SELECT max(try_cast(left(published, 10) AS DATE)) AS cut_date
    FROM notices WHERE source = 'fts_bulk_xml'
)
SELECT notice_id, buyer_name, title, deadline, url
FROM notices, cut
WHERE stage = 'tender' AND try_cast(left(deadline, 10) AS DATE) > cut_date
  AND source IN ('fts_bulk_xml', 'fts_api', 'contracts_finder')
ORDER BY deadline
LIMIT 50;
