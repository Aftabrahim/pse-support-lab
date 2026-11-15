# Incident 1 — Oasis upload: static source + workbook analysis

## Workbook facts (read from `samples/oasis-builders-nov-2026.xlsx`)
- 600 non-empty invoice-line rows.
- 8 invoice numbers: `OBS-2611-001` through `OBS-2611-008`.
- Exactly 75 line rows per invoice.
- Five distinct buyer Peppol participant IDs across those rows:
  - `0235:1001415069`: 150 rows
  - `0235:1001748392`: 150 rows
  - `0235:1001859403`: 150 rows
  - `0235:1001304958`: 75 rows
  - `0235:1001526170`: 75 rows

## Code path and timing
1. `services/api/internal/importer/importer.go:37-39` creates a 10-minute context from `context.Background()` rather than the HTTP request context.
2. `services/api/internal/importer/importer.go:100-102` validates each invoice group.
3. `services/api/internal/validate/validate.go:67-71` loops through every row in each invoice group.
4. `services/api/internal/validate/validate.go:165-172` performs a participant directory lookup for every row with a buyer Peppol ID.
5. `services/api/internal/directory/directory.go` calls the ASP participant endpoint. The mock ASP deliberately sleeps `200ms` per participant lookup (`services/asp-mock/main.go:39-40` and `services/asp-mock/main.go` participant handler).

Therefore this 600-line file causes 600 sequential participant lookups, even though it has only five distinct participant IDs. At the mock's stated typical 200ms latency, the lookup component alone is approximately **120 seconds** (600 × 0.2s), excluding workbook parsing, database operations and other overhead.

6. The web proxy has a fixed 60-second upstream timeout (`web/app/api/[...path]/route.ts:6,21-25`) and returns HTTP 504 for timeout (`:41-52`).
7. Because the importer context is detached from the request (`context.Background()`), the proxy timing out does not cancel the importer. The backend can continue creating/validating the import after the browser receives a gateway timeout.
8. `importer.go:87-96` inserts invoice records and stores the source before the row-by-row validation is complete.
9. `validate.go:73-81` checks whether the same seller/invoice number exists in another import and emits AE-BR-09 when it finds a non-rejected record. `store.go:296-306` confirms the duplicate lookup excludes only the current import and rejected invoices.

## Conclusion
The best-supported explanation for the stuck upload is a synchronous import path with per-line uncached participant lookups: expected lookup time (~120s) exceeds the portal proxy's 60s timeout. The browser can show a gateway timeout while the API continues processing. Retrying can create further imports that encounter invoice numbers already inserted by the first attempt, resulting in AE-BR-09 duplicate messages.

**Not proven without runtime DB/log evidence:** which import ultimately completed, whether every invoice was submitted/accepted, exact duplicate statuses, and whether concurrent retries raced. Reconcile import IDs, invoice status history and ASP received documents before any retry. Do not upload the whole file again.
