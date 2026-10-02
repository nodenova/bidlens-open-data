# Schema

Ten tables. All text columns except `url` have email addresses replaced with `[email]`
(addresses spelled out as `name at council dot gov` are not caught; see the README).
Five tables are loaded from the feeds and carry `source`: `notices`, `criteria`, `outcomes`,
`documents` and `tender_documents`. The other five are derived from those: `buyers`,
`suppliers`, `criterion_roles`, `frameworks` and `buyer_routes`.

`source` values: `ted_bulk` · `ted_api` · `ted_xml` · `fts_bulk_xml` · `fts_api` ·
`contracts_finder`. `ted_xml` holds TED notices published on the pre-eForms forms in
Jan–Jun 2024, read from the full XML because the API publishes them as headers only. Its
`notice_id` uses `ted_api`'s spelling (`28056-2024`).
On `tender_documents` they are `browser_docs` · `rubric_docs`: the harvester that fetched
the document.

Read the caveats in the [README](README.md#read-this-before-analysing) before writing
analysis.

## `criteria`

One published award criterion. One row per criterion per lot.

| column | notes |
|---|---|
| `source` | feed of origin |
| `notice_id` | native notice id (`079685-2026`, TED notice id, OCDS release id) |
| `ocid` | OCDS contracting process id, where the source has one |
| `lot_id` | lot identifier. NULL when the scheme is stated at notice level, or the feed carries no lot identity |
| `criterion_index` | order within the lot |
| `criterion_type` | **the TED column the criterion came from**, not its nature: `price` · `quality` · `cost` · `stated_in_procurement_documents`. Join `criterion_roles` for what it is |
| `name` | criterion name as published |
| `description` | criterion description, truncated to 4,000 chars. Rich on `ted_api`, absent on `ted_bulk` and `ted_xml` |
| `weight_value` | the weight as published |
| `weight_kind` | `percentageExact` · `pointsExact` · `decimalExact` · `order` · `percentage_or_points` · `raw_unsplit` |
| `weight_pct` | **derived**: this criterion's share of its lot's total weight × 100. NULL where the lot group cannot be resolved |
| `split_ok` | 0 when the feed's criteria and weights lists did not align and the row is kept raw |
| `n_lots` | number of lots on the notice, from the feed's own per-lot arrays |
| `country` · `buyer_name` · `cpv` · `cpv_division` · `published` · `notice_kind` · `url` | copied from the notice so most questions need no join |

## `notices`

One notice. On `ted_bulk`, one notice × lot.

| column | notes |
|---|---|
| `source` · `notice_id` · `ocid` | |
| `notice_kind` | the publisher's own notice type. Five vocabularies, so filter on `notice_kind_norm` |
| `notice_kind_norm` | normalised kind (`award`, `contract`, `planning`, …) |
| `form` | UK eForms form code (`UK4`, `UK6`, …), or the TED schema version on legacy-form rows (`R2.0.9.S05.E01`) |
| `published` | publication date. Two shapes, `2024-05-20…` and `20240520` |
| `country` | ISO 3166-1 alpha-2 of the buyer's address. NULL on all Contracts Finder and `fts_api` rows |
| `buyer_id` | the publisher's own buyer id, where given. For resolved identity, join `buyers` |
| `buyer_name` · `buyer_type` · `buyer_town` · `buyer_region` · `buyer_activity` | as published |
| `title` · `description` | description truncated to 4,000 chars. Neither covers the whole corpus (see README) |
| `cpv` · `cpv_division` | Common Procurement Vocabulary code. `cpv_division` (first two digits) is the usable sector key |
| `procedure` | procurement procedure as published (open, restricted, negotiated, direct award, …) |
| `award_model` | TED award basis, e.g. `Lowest price`, `The most economic tender` |
| `contract_nature` | works / supplies / services |
| `value_amount` · `value_currency` | estimated or total value as published. `value_currency` is empty on `ted_api`, `ted_xml` and most `fts_bulk_xml` legacy rows, whose amounts are in the notice's own national currency |
| `lot_id` | the lot, on `ted_bulk` rows |
| `n_criteria` · `n_documents` · `n_lots` | counts of the notice's criteria, document links and lots |
| `url` | link to the notice at its source |
| `deadline` | submission deadline. OCDS feeds and about half of `ted_api`; NULL on `ted_bulk` and `ted_xml` |
| `stage` | `planning` · `tender` · `cancelled` · `award`. **This column tells you whether a notice is a competition** |
| `tender_status` | the publisher's own tender status (`active`, `complete`, …), a second signal beside `stage` |

## `outcomes`

One award result. A lot with three suppliers on one award gives three rows. A lot with bid
statistics but no award gives one row with a NULL `winner_name`.

| column | notes |
|---|---|
| `source` · `notice_id` · `ocid` · `lot_id` | `lot_id` joins to `criteria.lot_id`, with both sides NOT NULL |
| `award_id` · `award_status` · `award_date` | |
| `winner_name` | as published. Join `suppliers` for resolved identity. On `ted_bulk`, a `---` packs several winners into one string |
| `winner_id` | the publisher's supplier id. A registry number for some schemes (`GB-COH-…`), a platform account id for others |
| `winner_country` · `winner_is_sme` | |
| `n_bids` | tenders received |
| `n_bids_sme` · `n_bids_foreign_eu` · `n_bids_foreign_non_eu` · `n_bids_electronic` | breakdowns of `n_bids`, where published |
| `lowest_bid_value` · `highest_bid_value` | price spread across bidders |
| `award_value` | the winning value. **Repeated on every winner's row of a multi-winner notice**: never `SUM` it raw (use `frameworks`). Set on only about 10% of `ted_api` rows, where it can be attributed to the right result |
| `estimated_value` · `currency` | the buyer's estimate, and the currency of the money columns. **Empty on every `ted_api` and `ted_xml` row and on most `fts_bulk_xml` legacy rows**: those amounts are in the notice's own currency, mixed in one column. `ted_bulk` is converted to EUR and `contracts_finder` is GBP |
| `country` · `buyer_name` · `cpv` · `published` · `url` | copied from the notice |

## `buyers`

One row per raw `buyer_name` spelling, with its resolved identity. Covers the UK-native feeds
and the GB rows of `ted_bulk`.

| column | notes |
|---|---|
| `buyer_name` | the raw string exactly as published. **The join key. Do not case-fold** |
| `buyer_id` | resolved identity, the same for every spelling of one authority. NULL for a `joint` co-buyer list |
| `canonical_name` | a spelling publishers actually used, preferring the parent body's own |
| `method` | `curated` (a person confirmed it) · `normalised` (case, punctuation, legal form) · `auto` (nothing collapsed it) · `joint` (a `---` list of co-buyers) |
| `n_notices` | notices carrying this exact string |

## `suppliers`

One row per raw `winner_name` spelling, with its resolved identity. Covers the UK-native feeds
only.

| column | notes |
|---|---|
| `winner_name` | the raw string exactly as published. **The join key** |
| `supplier_id` | resolved identity: a registry number (`GB-COH-02109168`) where one was published, else a normalised name. NULL where the string names no supplier (`Various`, prose) |
| `canonical_name` | a spelling publishers actually used |
| `method` | `registry` (a real company / charity / PPON number) · `curated` · `normalised` · `auto` · `unresolved` |
| `company_number` | the registry number backing the identity. For Companies House, strip `GB-COH-` and join the [register](https://download.companieshouse.gov.uk/en_output.html) |
| `n_awards` | outcome rows carrying this exact string |

## `criterion_roles`

One row per raw criterion name, with what the criterion actually is. Covers the criteria of
the UK estate.

| column | notes |
|---|---|
| `name` | criterion name exactly as published. Join `ON r.name = c.name` |
| `role` | `price` · `quality` · `social_value` · `template_slot` · `not_competed` · `undisclosed` · `unsplit` · `unknown`. Only `price`, `quality` and `social_value` are scored marks |
| `method` | which rule decided it: `vocabulary` · `heading` · `pattern` · `rejected` · `unsplit` · `unknown` |
| `n_rows` | `criteria` rows carrying this exact name |

## `frameworks`

One row per multi-supplier award notice, with the headline ceiling read once.

| column | notes |
|---|---|
| `notice_id` · `ocid` · `source` | the same procurement can appear under two `ocid`s (Find a Tender and Contracts Finder) |
| `buyer_name` · `buyer_id` · `canonical_name` | resolved through `buyers` |
| `cpv` · `cpv_division` · `published` · `currency` | |
| `ceiling` | the published value, read once (`MAX(award_value)` per notice) |
| `n_suppliers` | **distinct winners**, resolved through `suppliers` |
| `n_award_rows` | award rows. **Not the same number**: a supplier on several lots gives several rows |
| `n_lots` | distinct lots |
| `shape` | `framework` (one shared agreement) · `multi_lot` (separate lots awarded to different suppliers) |
| `per_supplier` | `ceiling / n_suppliers`. A mean, not an entitlement |

## `buyer_routes`

One row per (authority, CPV division): how much of the authority's work was ever open to a
bid. Counts award notices only. There is no rollup row; `GROUP BY buyer_id` for all sectors.

| column | notes |
|---|---|
| `buyer_id` · `canonical_name` | from `buyers` |
| `cpv_division` | the sector. NULL where the notice carried no CPV |
| `n_awards` | award notices |
| `n_competed` · `n_limited` · `n_direct` · `n_framework` · `n_unknown` | the procurement route split |
| `pct_competed` | `n_competed` over readable awards (`n_awards - n_unknown`) |

## `documents`

One tender-document link cited by a notice. These are links, not downloaded files.

| column | notes |
|---|---|
| `source` · `notice_id` · `ocid` · `published` · `buyer_name` | |
| `url` · `host` | `host` is pre-extracted, so you can see which eSourcing portal an authority uses |
| `doc_type` | OCDS `documentType`: `biddingDocuments`, `technicalSpecifications`, … |
| `description` · `format` | as published |

## `tender_documents`

One document that was actually fetched and read: a single attachment, or one file inside an
ITT pack zip. **The document text is not included.** Only facts extracted from it are.

| column | notes |
|---|---|
| `source` | `browser_docs` (Find a Tender / Contracts Finder attachments) · `rubric_docs` (gov.uk and seed list) |
| `origin` | `rubric_docs` only: `seed` or `govuk` |
| `url` · `member` | `member` is the filename inside a zip; NULL when the URL is the document |
| `host` · `notice_id` · `ocid` · `doc_type` · `title` · `buyer_name` · `published` | |
| `cited_by` | how many notices cite this URL. A high count suggests a framework pack |
| `content_type` · `bytes` · `text_chars` | `text_chars` = 0 with large `bytes` means a scanned document |
| `is_rubric` | 1 when a marking scheme (scored bands) was detected. Deliberately strict |
| `n_bands` · `bands_contiguous` · `rubric_score` | number of score bands, whether they run without gaps, detector confidence |
| `scales` · `band_keywords` | JSON: the score scales found, and band labels (`excellent`, `good`, `poor`, …) |
| `retrieved_at` | when it was fetched |

Misses are rows too: a document with no marking scheme has `is_rubric = 0`. Count everything
for the denominator.
