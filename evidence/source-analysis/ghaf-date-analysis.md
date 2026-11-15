# Incident 5 — Ghaf: workbook cell type confirms unsupported text date

The attached `samples/ghaf-cafe-nov-2026.xlsx` has 8 non-empty line rows grouped into four invoices. In the `Invoices` sheet:
- Issue date cells D2:D9 are stored as shared-string/text (`data_type='s'`), not Excel date serials.
- Due date cells E2:E9 are also shared-string/text.
- Values include `13/11/2026`, `14/11/2026`, `15/11/2026` and corresponding December dates.

The documented template rule requires `YYYY-MM-DD` text or real Excel date cells. `services/api/internal/sheet/sheet.go:167-185` accepts ISO date text or numeric Excel date serials; it rejects slash-separated text. `validate.go:113-118` reports AE-BR-04.

Root cause is customer workbook date values stored as text in an unsupported ambiguous format, not a date parser outage. Correct the text values to ISO strings (`2026-11-13`, etc.) or convert to actual Excel dates and apply `yyyy-mm-dd`. Preserve the intended calendar dates. This is a documented how-to issue (P4) unless a broader defect is discovered.
