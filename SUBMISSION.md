# Complyance PSE Assignment — Invoicely Lite

- **Name:** Aftab Rahim Khan
- **Date:** 14 November 2026
- **Repository:** https://github.com/Aftabrahim/pse-support-lab
- **Time spent:** Not accurately tracked; enter the actual duration if the evaluator requires it.

## Evidence scope and integrity

I reviewed the supplied application repository, five inbox cases, five Excel attachments, application source, Docker Compose configuration, database schema/seed data, and Grafana/Prometheus definitions. The findings below are source-code and workbook-level findings. I could not start Docker/Compose, PostgreSQL, Grafana, or the application in the preparation environment. Accordingly, I do not claim live database observations, runtime logs, Grafana measurements, container OOM state, ASP message IDs, or that customer emails were sent. Customer replies are drafts only. Runtime verification commands are provided under `evidence/runtime-collection/`.

## Executive summary

| Inbox item | Priority assessment | Finding / recommended handling |
|---|---|---|
| 01 — Oasis Builders: upload stuck | P2, reassess if broader outage | 600 workbook rows trigger repeated participant lookups; proxy timeout is shorter than estimated lookup time. Stop repeat uploads and reconcile invoice/import/ASP state before retrying. |
| 02 — Alert: API restarted | P2 pending runtime confirmation | API memory limit is 128 MB; an in-memory cache retains uploaded workbook/invoice objects without visible TTL/eviction. Memory pressure is plausible, not proven OOM. |
| 03 — Al Noor Fuel: BR-CO-15 | P2 | Three invoices show one- or two-cent mismatch consistent with inconsistent rounding bases. Correct calculation logic and add regression tests; do not ask customer to change correct values. |
| 04 — BluePeak / Sahara Medical: HTTP 429 | P2 | ASP throttling is not handled safely; invoice state may be set to Submitted before successful ASP acceptance. Reconcile before any resend. |
| 05 — Ghaf Tree Café: date validation | P3 | Slash-formatted date strings are not accepted by the parser. Convert to ISO dates or true Excel date cells, preserving intended dates. |

## 01 — Oasis Builders: monthly upload stuck on Processing

**Assessment:** The workbook contains 600 data rows, eight invoice numbers, and five distinct buyer Peppol participant IDs. The validation path performs a participant-directory lookup for each row. The mock directory lookup has 200 ms latency, giving approximately 120 seconds of lookup time alone (600 × 0.2 s), while the web proxy timeout is 60 seconds. The importer uses a detached background context, so the browser can receive a 504 while server-side processing continues.

The importer inserts invoice records before group validation. A repeated upload can therefore encounter invoice numbers from the earlier import and produce duplicate warnings. This is a source-level explanation; the actual winning import and current invoice/ASP states require live database reconciliation.

**Relevant paths:** `web/app/api/[...path]/route.ts`; `services/api/internal/importer/importer.go`; validation/directory lookup code under `services/api/internal`; `services/asp-mock/main.go`; store code under `services/api/internal`.

**Immediate actions:** Ask the customer not to upload the workbook again. Reconcile import IDs, invoice statuses, and ASP receipts invoice-by-invoice. Retry only confirmed unaccepted invoices after the state is understood.

**Longer-term fixes:** Deduplicate directory lookups by participant ID within a batch; move long-running imports to an asynchronous job model; expose progress and durable job status; make import idempotency explicit; validate before committing invoice records or use a transaction with safe rollback.

## 02 — Marina Bay: API container restarts

**Assessment:** Docker Compose sets the API container memory limit to 128 MB. The source contains an in-memory cache that retains uploaded data/workbook/invoice objects in a map without an evident TTL, eviction, or delete path. The supplied load profile includes a peak path of 240 uploads with eight concurrent workers. These facts make memory pressure a credible hypothesis, not proof that the container was OOM-killed.

**Evidence still required:** Docker restart count, container exit code and `State.OOMKilled`, API logs around restart time, container memory usage, Go heap/GC metrics, request rate, 5xx rate, and queue/backlog. Use the runtime commands in `evidence/runtime-collection/grafana-promql.md`.

**Immediate actions:** Preserve timestamps and logs; correlate restarts with upload/load activity; check whether the API is healthy and whether work was lost or duplicated. Do not report OOM as confirmed until runtime state proves it.

**Longer-term fixes:** Bound the cache with TTL/size limits and explicit cleanup; avoid retaining full workbook and invoice payloads unnecessarily; stream or process uploads incrementally; review memory limit against measured peak working set; add restart/OOM alerting.

## 03 — Al Noor Fuel: BR-CO-15 VAT rounding mismatch

**Assessment:** The supplied workbook has six invoices and 13 line rows. The implementation appears to calculate VAT from rounded line-net values while independently deriving the inclusive invoice total from quantity × unit price × (1 + VAT). With three-decimal unit prices, the two paths can differ by cents.

| Invoice | Generated total | Expected total | Difference |
|---|---:|---:|---:|
| ANF-2611-0042 | 15022.42 | 15022.43 | -0.01 |
| ANF-2611-0044 | 11817.57 | 11817.59 | -0.02 |
| ANF-2611-0046 | 5610.99 | 5611.00 | -0.01 |

**Recommended fix:** Calculate the inclusive total consistently from the rounded line-net and VAT amounts (the same tax basis used for the corresponding PINT totals), and add regression tests for all three invoices plus boundary cases. Do not ask the customer to alter correct source data merely to accommodate inconsistent rounding.

## 04 — BluePeak / Sahara Medical: ASP HTTP 429

**Assessment:** The ASP mock allows an initial burst of eight documents and then two documents per second. The submit worker changes an invoice to Submitted before sending it. The source does not show a safe HTTP 429 handling branch, while the retry endpoint accepts only Validated and Failed states. An HTTP 429 can therefore leave an invoice marked Submitted without a corresponding ASP message ID, even though the ASP did not accept it.

**Immediate actions:** Pause bulk resends. Reconcile the 40 invoice numbers against the ASP's received-document list and message IDs. Do not resend any document already accepted. For unaccepted documents stuck in an inconsistent state, use an audited engineering repair path; do not perform an ad hoc database update.

**Longer-term fixes:** Handle 429 explicitly; respect Retry-After; use bounded exponential backoff with jitter; set Submitted only after acceptance or introduce a distinct Submitting state; persist attempts and idempotency keys; make retry transitions safe and observable.

## 05 — Ghaf Tree Café: invoice date format

**Assessment:** The four invoices (eight line rows) contain slash-separated date text such as `13/11/2026`. The parser supports ISO dates and Excel serial dates, while validation reports AE-BR-04 for unsupported text formats.

**Customer action:** Convert the date cells to actual Excel date cells or ISO `YYYY-MM-DD` text, preserving the intended calendar date, then re-upload the corrected workbook once. Confirm the date interpretation with the customer if the slash format is ambiguous.

## Customer communications

Customer-facing acknowledgements and updates should be sent only after verifying current case state and applicable SLA. The guidance above is the investigation and action plan; no customer email is represented as sent.

## Final validation checklist

- [ ] Run the application stack and capture actual runtime evidence where available.
- [ ] Confirm Oasis import and ASP state before any retry.
- [ ] Confirm or rule out API OOM/restart cause using container state and metrics.
- [ ] Add and run BR-CO-15 rounding regression tests.
- [ ] Reconcile all 40 ASP submissions and safely repair only confirmed unaccepted invoices.
- [ ] Validate corrected Ghaf workbook dates.
- [ ] Replace this checklist with actual test outputs and timestamps before final submission if the evaluator expects runtime proof.
