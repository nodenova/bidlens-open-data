# Changelog

Each snapshot is a tag here and on the Hugging Face dataset, named `v<YYYY.MM>` after the
month it was cut. Load a pinned snapshot with `revision="v2026.10"`.

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
