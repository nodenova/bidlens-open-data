# Changelog

Each snapshot is a tag here and on the Hugging Face dataset, named `v<YYYY.MM>` after the
month it was cut. Load a pinned snapshot with `revision="v2026.10"`.

## Unreleased

- **`examples/queries.sql` query 1 corrected.** It had no column for weighted portal
  placeholder slots (`template_slot`, e.g. *Custom Metric*), so on 19% of lots the price,
  quality and social value columns summed to less than 100, and lots made only of such slots
  were averaged in as 0% price. Authorities on that portal template read far too low — Cumbria
  County Council 3.2% price where its classifiable lots average 40.0%. The query now adds an
  `unnamed_pct` column, so the four sum to 100 per lot, and drops lots with nothing to
  classify. The data is unchanged; only the example was wrong.
- The card asks users to say what they use the dataset for, in a discussion or an issue.

## v2026.10

First public snapshot.

- Ten linked tables: `notices`, `criteria`, `outcomes`, `buyers`, `suppliers`,
  `criterion_roles`, `frameworks`, `buyer_routes`, `documents`, `tender_documents`.
- UK configs (`uk_criteria`, `uk_notices`, `uk_outcomes`) beside the full UK + EU ones.
- TED without a gap across the eForms switch: the bulk export to 2023, the eForms API from
  Nov 2023, and `ted_xml` for the notices still published on the old forms in early 2024.
  Each TED notice appears once.
- Email addresses in free text replaced with `[email]`; counts in `manifest.json`.
- Tender document text withheld; only the extracted structure ships.
