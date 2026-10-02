---
license: cc-by-4.0
pretty_name: BidLens Open Data — UK & EU public procurement, award criteria and outcomes
language:
  - en
  - multilingual
size_categories:
  - 10M<n<100M
task_categories:
  - tabular-classification
  - text-classification
tags:
  - public-procurement
  - tenders
  - government-contracts
  - ted
  - ocds
  - find-a-tender
  - contracts-finder
  - award-criteria
  - open-data
configs:
  - config_name: uk_criteria
    default: true
    data_files: data/criteria/criteria-uk-*.parquet
  - config_name: uk_notices
    data_files: data/notices/notices-uk-*.parquet
  - config_name: uk_outcomes
    data_files: data/outcomes/outcomes-uk-*.parquet
  - config_name: criteria
    data_files: data/criteria/*.parquet
  - config_name: notices
    data_files: data/notices/*.parquet
  - config_name: outcomes
    data_files: data/outcomes/*.parquet
  - config_name: buyers
    data_files: data/buyers/*.parquet
  - config_name: suppliers
    data_files: data/suppliers/*.parquet
  - config_name: criterion_roles
    data_files: data/criterion_roles/*.parquet
  - config_name: frameworks
    data_files: data/frameworks/*.parquet
  - config_name: buyer_routes
    data_files: data/buyer_routes/*.parquet
  - config_name: documents
    data_files: data/documents/*.parquet
  - config_name: tender_documents
    data_files: data/tender_documents/*.parquet
---

# BidLens Open Data

**How do public buyers in the UK and EU score bids, and who wins them?** This dataset
harmonises six official feeds from three public procurement services into ten linked
Parquet tables. It covers EU-wide TED notices from 2005 and the UK's Find a Tender and
Contracts Finder services. Each
**published award criterion** carries its weight, normalised to a share of its lot.
Criteria join to the **award outcome** of the same lot (winner, number of bids, price
range) and to **resolved buyer and supplier identities**. UK suppliers carry Companies House
numbers.

Built by [NodeNova](https://github.com/nodenova) as the open layer of BidLens.
Snapshot **v2026.10**, CC BY 4.0.

- Hugging Face: <https://huggingface.co/datasets/NodeNovaOrg/bidlens-open-data>
- GitHub (card, schema, examples): <https://github.com/nodenova/bidlens-open-data>

## Why another procurement dataset

Raw procurement feeds are already open, and several good aggregations exist (the
[OCP Data Registry](https://data.open-contracting.org/), [OpenTender](https://opentender.eu/),
the [GTI global dataset](https://data.mendeley.com/datasets/fwzpywbhgw/3)). None of them
links these three things:

1. **Weighted award criteria per lot.** A 60/40, a 600/400 and a 60-points scheme all become
   one `weight_pct` scale, and `criterion_roles` corrects the many UK TED notices that list
   "Price" as a *quality* criterion.
2. **The outcome of that lot**: winner, `n_bids`, lowest and highest bid, award value
   against estimate.
3. **Who the buyer and winner really are.** `buyers` and `suppliers` resolve thousands of
   spellings to one identity. UK winners carry the Companies House number, so you can join
   incorporation date and status from the
   [register](https://download.companieshouse.gov.uk/en_output.html).

## Quick start

```python
import duckdb

con = duckdb.connect()
# Mean weight of price criteria, per UK authority (UK-native feeds only, see caveats)
con.sql("""
    SELECT b.canonical_name,
           round(avg(c.weight_pct) FILTER (WHERE r.role = 'price'), 1) AS mean_price_weight_pct,
           count(DISTINCT c.notice_id) AS notices
    FROM 'hf://datasets/NodeNovaOrg/bidlens-open-data/data/criteria/*.parquet' c
    JOIN 'hf://datasets/NodeNovaOrg/bidlens-open-data/data/buyers/*.parquet' b
      ON b.buyer_name = c.buyer_name AND b.buyer_id IS NOT NULL
    LEFT JOIN 'hf://datasets/NodeNovaOrg/bidlens-open-data/data/criterion_roles/*.parquet' r
      ON r.name = c.name
    WHERE c.source IN ('fts_bulk_xml', 'fts_api') AND c.weight_pct IS NOT NULL
    GROUP BY b.buyer_id, b.canonical_name HAVING notices >= 10 ORDER BY notices DESC LIMIT 20
""").show()
```

```python
from datasets import load_dataset

uk_criteria = load_dataset(
    "NodeNovaOrg/bidlens-open-data", "uk_criteria", split="train", streaming=True
)
```

The default view is **UK**: `uk_criteria`, `uk_notices` and `uk_outcomes` hold the rows from
the three UK-native feeds plus the GB rows of TED. `criteria`, `notices` and `outcomes` hold
everything, UK and EU. On disk the split is in the file names (`criteria-uk-*.parquet`,
`criteria-other-*.parquet`), so a glob picks either half or both.

More in [`examples/`](examples/). For serious work, download once
(`hf download NodeNovaOrg/bidlens-open-data --repo-type dataset --local-dir bidlens-open-data`)
and query the local files.

## Tables

<!-- stats:tables:start -->
| Table | Grain | Rows | of which UK | Size |
|---|---|---:|---:|---:|
| `notices` | one notice; one notice per lot on `ted_bulk` | 25,452,313 | 1,800,414 | 740 MB |
| `criteria` | one published award criterion (per lot) | 34,828,647 | 2,484,224 | 580 MB |
| `criterion_roles` | one raw criterion name → what it is (`price`, `quality`, `social_value`, …) | 157,014 | UK only | 2 MB |
| `outcomes` | one award result per winner; a lot with bid statistics but no award has a NULL winner | 34,374,398 | 1,629,001 | 354 MB |
| `buyers` | one raw `buyer_name` spelling → resolved `buyer_id` | 48,062 | UK only | 2 MB |
| `suppliers` | one raw `winner_name` spelling → resolved `supplier_id` and company number | 277,993 | UK only | 8 MB |
| `frameworks` | one multi-supplier award notice, ceiling read once | 37,506 | UK only | 2 MB |
| `buyer_routes` | one (authority, CPV division): competed / direct / framework award counts | 53,727 | UK only | 1 MB |
| `documents` | one tender-document link cited by a notice | 491,621 | UK only | 19 MB |
| `tender_documents` | one document actually opened, with its extracted marking-scheme facts | 7,767 | UK only | 1 MB |

Snapshot `v2026.10`, exported 2026-10-02, **1.71 GB** of zstd Parquet.

<!-- stats:tables:end -->

Column-by-column documentation is in [`SCHEMA.md`](SCHEMA.md). `manifest.json` lists every
file with its row count and SHA-256.

## Coverage by source

<!-- stats:coverage:start -->
| `source` | Notice rows | Criteria | Outcomes | First published | Last published |
|---|---:|---:|---:|---|---|
| `contracts_finder` | 633,109 | — | 575,305 | 2016-11-18 | 2026-09-30 |
| `fts_api` | 5,706 | 13,557 | 7,132 | 2021-01-01 | 2021-07-27 |
| `fts_bulk_xml` | 319,799 | 716,258 | 483,918 | 2021-01-01 | 2026-09-07 |
| `ted_api` | 2,045,235 | 10,271,001 | 21,362,084 | 2023-11-02 | 2026-09-08 |
| `ted_bulk` | 22,419,541 | 23,707,142 | 11,819,941 | 2005-08-06 | 2023-12-27 |
| `ted_xml` | 28,923 | 120,689 | 126,018 | 2024-01-02 | 2024-06-28 |
<!-- stats:coverage:end -->

What each `source` is:

| `source` | Feed | Licence |
|---|---|---|
| `ted_bulk` | TED bulk CSV exports (contract and award notices, pre-eForms) | EU open data, Decision 2011/833/EU |
| `ted_api` | TED eForms search API | EU open data, Decision 2011/833/EU |
| `ted_xml` | TED monthly XML packages: notices still published on the pre-eForms forms, Jan–Jun 2024. The API carries these as headers only, so they replace the `ted_api` row | EU open data, Decision 2011/833/EU |
| `fts_bulk_xml` | Find a Tender daily bulk (OCDS and legacy XML) | OGL v3.0 |
| `fts_api` | Find a Tender OCDS API (2021 only; mostly a duplicate of `fts_bulk_xml`) | OGL v3.0 |
| `contracts_finder` | Contracts Finder OCDS. Notices, outcomes and document links; **no award criteria** | OGL v3.0 |

TED reaches the dataset by three routes, one per era. `ted_bulk` runs to the end of 2023;
`ted_api` takes over in Nov 2023, when eForms became mandatory; `ted_xml` covers the notices
still published on the old forms in the first half of 2024. Each TED notice appears once:
where two routes carried the same notice, the copy with its criteria and outcomes was kept.

## Read this before analysing

Each of these produces a plausible wrong number with no error. All of them were found the
hard way while building the corpus.

- **Jurisdiction is a property of `source`, not `country`.** `country` is the buyer's
  address and is NULL on every Contracts Finder and `fts_api` row. For a UK slice, use
  `source IN ('fts_bulk_xml','fts_api','contracts_finder') OR country = 'GB'`.
- **`criterion_type` records which TED column a criterion came from, not what it is.**
  For the real role, join `criterion_roles` on the **raw** name and fall back to
  `criterion_type` where the role is `unknown`:
  `CASE WHEN r.role IS NOT NULL AND r.role <> 'unknown' THEN r.role WHEN c.criterion_type IN ('price','quality') THEN c.criterion_type ELSE 'unknown' END`.
  For UK weighting benchmarks, use the UK-native feeds. On `ted_bulk`, roughly half of UK
  groups list price only inside the quality column.
- **Not every criterion is scored.** The roles `template_slot`, `not_competed`,
  `undisclosed` and `unsplit` are not marks. Leave them out of any price/quality split.
  Drop the whole lot when `not_competed` carries weight, because nobody competed for it.
- **`weight_pct` is normalised per lot group, so it always sums to ~100.** Test whether a
  scheme is complete on `weight_value` instead. On `ted_api`, `weight_pct` is NULL where the
  feed carries no lot identity; that NULL does not mean no weights were published.
- **Joining criteria to outcomes:** `ON o.notice_id = c.notice_id AND o.lot_id = c.lot_id`,
  with **both** `lot_id IS NOT NULL`. Never `IFNULL(lot_id,'')`: it joins every criterion to
  every award in the notice.
- **Money has no currency on most of the EU estate.** `currency` and `value_currency` are
  empty on every `ted_api` and `ted_xml` row and on most `fts_bulk_xml` legacy rows, and
  those values are in the notice's own currency: euro, złoty, lei, forint, all in one
  column. Only `ted_bulk` (converted to EUR) and `contracts_finder` (GBP) are safe to sum or
  average as they stand. Elsewhere, compare within one country, or filter
  `currency IS NOT NULL`.
- **Never `SUM(award_value)` over multi-winner notices.** A framework publishes one ceiling
  and repeats it on every winner's row. Use `frameworks` (`ceiling`, read once), filter
  `shape = 'framework'`, and divide by `n_suppliers`, not `n_award_rows`.
- **`ted_bulk` rows are notice × lot.** Count `DISTINCT notice_id` when you mean notices.
  `ted_api` and `ted_xml` hold one row per notice, so a `COUNT(*)` of TED notices by year
  falls about threefold at the 2023/2024 switch while the real volume does not.
- **A TED series across 2023–2024 needs all three TED sources.** Filter
  `source IN ('ted_bulk','ted_api','ted_xml')`. Leaving out `ted_xml` drops about half of
  January 2024's award notices, which were published on the old forms.
- **Group on `buyer_id` / `supplier_id`, never on the raw names.** Join the lookup tables
  on the exact raw string (`b.buyer_name = c.buyer_name`), without case-folding, and filter
  `… IS NOT NULL`. A `---` in `buyer_name` is a list of co-buyers. `method` is the
  resolution tier: on the supplier side, `registry` means a real company number.
  `suppliers` covers the UK-native feeds only.
- **The same UK procurement can appear twice.** Above-threshold contracts go to both Find a
  Tender and Contracts Finder under different `ocid` namespaces, roughly 12% of FTS award
  notices.
- **Text columns are not corpus-wide.** `title` covers about a third of `ted_bulk` and none
  of it before 2009. `notices.description` is empty on `ted_api`, but
  `criteria.description` is 98.7% filled there. Treat any text-search count as a floor.
- **`published` has two shapes** (`2024-05-20…` and `20240520`). Use
  `try_strptime(replace(left(published,10),'-',''),'%Y%m%d')`.
- **Open tenders need `stage = 'tender'`, not a date filter.** Planning notices carry
  dates that look like deadlines. `deadline` is populated on the OCDS feeds and about half
  of `ted_api`, and is NULL on `ted_bulk` and `ted_xml`.
- **`documents` are links; `tender_documents` are documents that were actually read.** One
  is not the other's denominator.

## What was changed or left out, and why

- **Email addresses are replaced with `[email]`** in every text column except `url`. The
  feeds embed officials' contact addresses in free text, and bulk republication is a
  separate act under UK GDPR. Per-column counts are in `manifest.json`
  (`emails_redacted`). The `url` column links back to the original notice. Addresses
  written out to dodge spam filters (`jane.smith at council dot gov dot uk`) are not
  recognised and can remain: a few hundred, in notice descriptions.
- **Tender document text is not included.** `tender_documents` keeps only the facts
  extracted from each pack (band count, scales, band keywords, rubric score). The OGL
  covers what an authority authored, and an ITT pack often contains third-party
  material.
- **Not included:** FOI-released evaluation material (no redistribution licence, and it
  contains personal data), and the Companies House register itself (join it from source on
  `suppliers.company_number`).
- **Sole traders** can appear as `winner_name`, exactly as the publishing authority
  released them. To ask for a correction or removal of your own details, email
  <info@nodenova.co.uk>; for anything else,
  [open an issue](https://github.com/nodenova/bidlens-open-data/issues/new/choose).
  Accepted requests are applied at the next snapshot.

## Licence and attribution

This dataset is released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The code in `examples/` and `tools/` is MIT ([`LICENSE`](LICENSE)).
If you use it, please credit **"BidLens Open Data, NodeNova"**, and keep these source
attributions:

- Contains public sector information licensed under the
  [Open Government Licence v3.0](https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/)
  (Find a Tender, Contracts Finder).
- Source: Tenders Electronic Daily, © European Union, <https://ted.europa.eu>, reused under
  [Commission Decision 2011/833/EU](https://eur-lex.europa.eu/eli/dec/2011/833/oj).

NodeNova is not affiliated with or endorsed by the Cabinet Office, the Government Commercial
Agency or the Publications Office of the EU.

## Citation

```bibtex
@dataset{nodenova_bidlens_open_data_2026,
  title     = {BidLens Open Data: UK and EU public procurement award criteria and outcomes},
  author    = {{NodeNova}},
  year      = {2026},
  version   = {2026.10},
  publisher = {Hugging Face},
  url       = {https://huggingface.co/datasets/NodeNovaOrg/bidlens-open-data},
  license   = {CC-BY-4.0}
}
```
