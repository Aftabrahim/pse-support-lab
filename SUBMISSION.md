# Complyance PSE Assignment — Evidence-backed working submission

- **Name:** Aftab Rahim Khan
- **Date submitted:** 15 November 2026
- **Repository link:** https://github.com/Aftabrahim/pse-support-lab
- **Total time spent (real time):** 5 hours

> **Evidence scope / integrity:** I inspected the supplied repository, all five inbox messages and Excel attachments, application source, Docker Compose configuration, database schema/seed, and Grafana/Prometheus definitions. I also ran the Docker services and queried PostgreSQL. Runtime evidence confirms that all 8 invoices in Oasis's latest November batch have ASP status Accepted and acceptance message IDs. The 12 Sahara invoices currently present in the database are accepted, but they are from the October batch and do not establish the outcome of the November incident. The API, ASP mock and PostgreSQL containers were healthy at the time of inspection. Point-in-time inspection showed RestartCount=0, OOMKilled=false and ExitCode=0 for all three; the API container's current start time was 2026-11-15T11:14:44Z. This does not rule out earlier API restarts. The Docker event sample showed health-check executions rather than evidence of the three reported historical restarts. Captured runtime output is in `evidence/runtime/runtime-verification.txt`. Customer replies below are drafts only; no real emails were sent.

> **Exercise clock:** Monday 16 November 2026, Asia/Dubai (UTC+4). Proposed response times below are exercise-clock times, not actual sends.

## Items fully investigated from supplied source and sample data

I performed source-code and workbook-level investigation for all five incidents. The strongest deep-dive candidates are Incidents 1–4 because they expose product defects/integration failures with direct code evidence. Incident 5 is a documented customer-side format correction.

---

## Incident 1 — Oasis Builders: monthly upload stuck on Processing

### Acknowledgement

- **Received:** 09:05
- **Proposed sent at:** 09:15 (within P2 first-response target of 10:05)
- **Reply:**

> Hi Rashid,
>
> I understand that the November workbook remained on Processing, that you tried uploading it again, and that you now see document-number-already-exists messages. Please do not upload the full workbook again while we reconcile the existing imports.
>
> I’m checking the batch history and each invoice’s status so we can distinguish invoices accepted by the ASP from invoices still waiting, failed, or rejected. I’ll send you an invoice-by-invoice reconciliation and the safe next step by 10:00 UAE time.
>
> Regards,
> Invoicely Lite Support

### Priority and justification

- **Priority:** P2 — major degradation / batch impact.
- **Why:** One large monthly batch (8 invoices across 600 lines) is affected, month-end close is at risk, and duplicate submissions create reconciliation risk. The report does not prove a platform-wide inability to send invoices to the ASP, so P2 is appropriate unless runtime evidence shows the customer cannot get any invoices through; in that case reassess as P1.
- **SLA:** first response within 1 hour (10:05); resolution target 8 hours (17:05); updates every 2–4 hours. Proposed acknowledgement 09:15.

### Investigation log

| Exercise time | What I checked / did | Finding |
|---|---|---|
| 09:15 | Acknowledgement and stop-repeat-upload guidance | Draft prepared; no real email sent |
| 09:20 | Inspected `samples/oasis-builders-nov-2026.xlsx` | 600 data rows, 8 invoice numbers, 75 rows per invoice |
| 09:30 | Counted buyer Peppol IDs in the workbook | Only 5 distinct participant IDs across 600 lines |
| 09:35 | Traced validation path in `validate.go`, `directory.go`, `asp-mock/main.go` | Directory lookup is called for every invoice line; mock lookup latency is 200 ms |
| 09:40 | Traced browser proxy timeout and API import context | Proxy timeout is 60 seconds; importer uses a detached background context |
| 09:50 | Traced insert and duplicate-check ordering | Invoice records are inserted before validation; later imports can see non-rejected invoice numbers from earlier imports |
| 10:00 | Prepared DB reconciliation queries | Live import IDs/statuses and ASP receipts still need to be collected locally |

### Root cause

- **What happened:** The upload path is synchronous and performs a Peppol participant lookup for every row. The attached Oasis workbook has 600 rows, so it triggers 600 lookups even though it contains only five unique buyer participant IDs. At the ASP mock's documented 200 ms lookup latency, lookup time alone is approximately 120 seconds (600 × 0.2 s), before parsing and database work. The web proxy aborts its upstream request after 60 seconds and returns HTTP 504. The API import continues because its processing context is created from `context.Background()` rather than the HTTP request context. The customer can therefore see a gateway timeout while the backend continues processing.
- **Why duplicate messages appeared:** The importer inserts invoice records before it validates the groups. A subsequent upload of the same invoice numbers checks for matching invoices in other imports and raises AE-BR-09 when it finds a non-rejected record. This is consistent with the duplicate warning after repeat attempts. The exact winning import and invoice states must be confirmed from the live database.
- **Where (component, file:line):**
  - `web/app/api/[...path]/route.ts:6,21-25,41-52` — 60-second proxy timeout and 504 response.
  - `services/api/internal/importer/importer.go:37-39` — processing context detached from request.
  - `services/api/internal/importer/importer.go:87-102` — records inserted before per-group validation.
  - `services/api/internal/validate/validate.go:67-71,165-172` — per-row validation and participant lookup.
  - `services/asp-mock/main.go:39-40` and participant handler — 200 ms mock directory latency.
  - `services/api/internal/store/store.go:296-306` — duplicate check excludes current import and rejected records.
- **Evidence:** `evidence/source-analysis/oasis-upload-analysis.md`. The workbook counts are directly reproducible from the supplied `.xlsx`.
- **Confidence:** High for the timeout/slow-lookup mechanism and duplicate-check path. Runtime evidence confirms that all eight invoices in the latest November Oasis batch were accepted by the ASP. The captured message IDs are recorded in the runtime verification file.

### Customer resolution reply OR escalation note

**Customer update (draft; latest November batch reconciled):**

> Hi Rashid,
>
> We have reconciled the latest November upload. All 8 of the 8 invoices have an ASP acceptance reference; 0 are awaiting submission, 0 failed delivery, and 0 were rejected. The invoice numbers and ASP acceptance references are recorded in the runtime evidence.
>
> Please do not upload the full workbook again. We will only retry invoices confirmed as eligible, and we will not retry invoices already accepted by the ASP. I’ll send the next update after the ASP receipt reconciliation is complete.
>
> Regards,
> Invoicely Lite Support

### Workaround offered

Do not re-upload the full workbook. Reconcile every invoice number across all import attempts and query the ASP received-document list for seller `0235:1003182746`. Do not retry `Accepted` or `Rejected` invoices. Retry only invoices currently `Validated` or `Failed`, after confirming that the ASP has not received them. If a record remains `Parsed` or `Submitted`, investigate its history rather than guessing.

### Prevention ideas

- Cache participant lookup results by Peppol participant ID for the duration of an import; this file needs five lookups rather than 600.
- Move import processing to a durable asynchronous job and return a batch ID promptly.
- Propagate request cancellation correctly, while ensuring a client timeout does not leave an ambiguous UI state.
- Add an idempotency key / duplicate-upload detection at batch level.
- Add bounded source retention and a clear progress indicator with per-invoice status.

---

## Incident 2 — Marina Bay / API restart alert

### Acknowledgement

- **Alert received:** 09:42
- **Priya forwarded context:** 09:50
- **Proposed acknowledgement:** 09:55
- **Sent to:** support-oncall; internal status update to Priya Nair.
- **Reply:**

> Hi Priya,
>
> I’m taking ownership of the API restart alert. Grafana reports three API restarts in 15 minutes, and you’ve reported intermittent 502 responses plus invoices remaining in Validated for some customers. I’m treating this as a potential production incident and checking API availability, restart/exit state, memory, 5xx rate and the invoice submission backlog.
>
> I’ll page Engineering immediately if the evidence confirms production impact consistent with P1, and I’ll send you the next status by 10:25 UAE time. I’ll also give you a go-live readiness assessment for Marina Bay once service stability and backlog recovery are verified.
>
> Regards,
> Support On-call

### Priority and justification

- **Priority:** P1 — provisional pending immediate impact verification.
- **Why:** Three API restarts in 15 minutes, intermittent 502s across multiple customers, and invoices stuck before ASP submission indicate a potentially severe production incident. The P1 definition is production down / no invoices reaching the ASP for one or more customers. Confirm that criterion immediately using invoice status and ASP receipt evidence; if only intermittent degradation or a subset is affected while submissions continue, downgrade to P2 and communicate why. Do not wait for full root cause before paging Engineering if P1 impact is confirmed.
- **SLA:** P1 first response within 15–30 minutes (latest 10:12); resolution target 4 hours (13:42); updates every 30–60 minutes. Proposed acknowledgement 09:55.

### Investigation log

| Exercise time | What I checked / did | Finding |
|---|---|---|
| 09:55 | Acknowledge alert and take incident ownership | Draft prepared; no real message sent |
| 10:00 | Reviewed Compose API memory cap and restart policy | API limited to 128 MB with memory+swap capped at 128 MB |
| 10:05 | Reviewed source-cache lifecycle | Each import retains raw bytes, parsed workbook and invoice objects in a map; no eviction/delete path is present |
| 10:10 | Reviewed load generator | `make load` includes 240 peak uploads with 8 concurrent workers |
| 10:15 | Prepared runtime checks for OOM/exit code, API logs, memory and 5xx | Cannot execute without Docker |
| 10:25 | Engineering escalation / next update | Must attach actual `OOMKilled`, exit code, logs and Grafana values before claiming OOM |

### Root cause

- **What happened:** The alert confirms three API restarts, but does not identify the exit cause. Source review found a credible memory-exhaustion mechanism: the API has a 128 MB hard memory limit; each import adds a `Source` object to an in-memory map containing the original uploaded bytes, an Excel workbook object and parsed invoice objects; the cache has no TTL or eviction. The supplied load generator's `make load` path includes a 240-upload peak test with eight concurrent uploads.
- **Leading hypothesis:** Unbounded source-cache retention under peak upload load caused the API to exceed its 128 MB limit and be restarted, producing intermittent gateway errors. This is a strong code/configuration hypothesis, not a confirmed OOM finding.
- **Where:**
  - `docker-compose.yml:43-63` — API memory and swap limits.
  - `services/api/internal/importer/sources.go:11-35` — retained data structures and map insertion without eviction.
  - `services/api/internal/importer/importer.go:87-96` — source added for every import.
  - `tools/cmd/loadgen/main.go:172-220` — 240 uploads / 8 concurrent workers.
- **Evidence:** `evidence/source-analysis/api-restarts-analysis.md`.
- **Confidence:** High that the source cache is unbounded and API memory is capped; medium that this explains the reported restarts. Confirm `State.OOMKilled`, exit code, memory graph and logs before writing “OOM confirmed.”

### Customer resolution reply OR escalation note

**Escalation to L3 Engineering is required immediately if P1 impact is confirmed.**

> ### Escalation: API restart loop / intermittent 502s and invoices not progressing to ASP
>
> **Priority:** P1 provisional — three API restarts in 15 minutes; multiple customers report 502s and invoices stuck in Validated. Confirm whether no invoices are reaching the ASP for one or more customers.
>
> **Reported by / at:** Grafana alert 09:42; Priya Nair forwarded CS reports at 09:50.
>
> **Affected:** Exact customer, import and invoice counts, and the first verified impact time, remain to be confirmed from runtime evidence. Do not treat the reported alert as a verified customer-impact count.
>
> **Symptoms:** API restarts; intermittent portal 502s; some invoices remain Validated.
>
> **Source-based suspected cause:** Unbounded `SourceCache` retains uploaded bytes, parsed Excel workbooks and invoice objects; API container hard memory cap is 128 MB. `make load` drives 240 concurrent/burst uploads.
>
> **Runtime evidence required:** `docker inspect` restart count / OOMKilled / exit code; API logs around 09:30–09:50; Grafana `Container memory (working set)`, `API Go heap in use`, `API process restarts (1h)`, `5xx responses (15m)`, `API up`; invoice backlog and ASP receipts.
>
> **What I need:** Confirm or rule out OOM; stabilise API; advise safe backlog reconciliation and retry; identify cache eviction / memory remediation. Initial engineering update requested by 10:25.
>
> **Workaround:** Stop repeated uploads; preserve import IDs; after API stabilises, reconcile invoice statuses against ASP receipts before retry.
>
> **Next customer update due:** 10:25 UAE time.

### Workaround offered

Do not ask customers to upload again while the API is unstable. Preserve all import IDs. Once stable, reconcile invoices in `Validated` or `Failed` against the ASP received-document list before retrying. A temporary memory increase may be a containment measure if OOM is confirmed, but it is not the permanent fix.

### Prevention ideas

- Add TTL/LRU or bounded size to `SourceCache`; store original workbooks outside process memory.
- Avoid retaining both raw workbook, parsed workbook and duplicate invoice structures.
- Apply upload concurrency and file-size limits.
- Add alerts on memory headroom, OOM kills, restart count, API 5xx and invoice backlog age.
- Add a peak-load test that asserts memory stays below the configured container limit.

---

## Incident 3 — Al Noor Fuel: BR-CO-15 rejection

### Acknowledgement

- **Received:** 10:15
- **Proposed sent at:** 10:30 (within P2 first-response target of 11:15)
- **Reply:**

> Dear Fatima,
>
> I understand that several November fuel invoices were rejected with BR-CO-15 while others in the same workbook were accepted. I have reviewed the attached workbook and the calculation path used to build the PINT AE payload. I can reproduce a one- or two-fils difference in the generated inclusive totals for three invoice numbers.
>
> This appears to be a platform calculation issue rather than an error in your dispatch figures. Please do not manually change your correct quantities or prices. I’m escalating the calculation defect to Engineering and will provide the affected invoice numbers and correction plan by 11:30 UAE time.
>
> Kind regards,
> Invoicely Lite Support

### Priority and justification

- **Priority:** P2.
- **Why:** A subset of six invoices is rejected by an ASP business rule; three affected invoice numbers can be identified from the workbook/source calculation. The customer has an active external VAT audit and needs a written explanation. This meets P2 subset rejection criteria.
- **SLA:** first response within 1 hour (11:15); resolution target 8 hours (18:15); updates every 2–4 hours. Proposed acknowledgement 10:30.

### Investigation log

| Exercise time | What I checked / did | Finding |
|---|---|---|
| 10:30 | Acknowledge and advise against manual price edits | Draft prepared |
| 10:40 | Inspected the actual Al Noor workbook | 6 invoices, 13 lines, standard 5% VAT |
| 10:50 | Reproduced PINT calculation from `pint.go` | Three invoices have inclusive totals below exclusive + VAT |
| 11:00 | Compared ASP mock BR-CO-15 validation | ASP compares monetary values at cent precision |
| 11:10 | Identified exact affected invoice numbers and differences | `0042` is -AED 0.01; `0044` is -AED 0.02; `0046` is -AED 0.01 |
| 11:20 | Prepared Engineering handoff and regression-test recommendation | Runtime payload/ASP response still needs capture |

### Root cause

- **What happened:** The PINT mapper calculates line VAT from the rounded line-net amount, then computes invoice IBT-112 independently from `quantity × unit price × (1 + VAT rate)`. With three-decimal fuel prices and two-decimal line-net values, the independently calculated gross total can differ from IBT-109 + IBT-110.
- **Reproduced workbook results:**

| Invoice | IBT-109 (AED) | IBT-110 (AED) | Generated IBT-112 (AED) | Required total (AED) | Difference |
|---|---:|---:|---:|---:|---:|
| ANF-2611-0041 | 13,749.75 | 687.49 | 14,437.24 | 14,437.24 | 0.00 |
| ANF-2611-0042 | 14,307.08 | 715.35 | 15,022.42 | 15,022.43 | -0.01 |
| ANF-2611-0043 | 18,684.00 | 934.20 | 19,618.20 | 19,618.20 | 0.00 |
| ANF-2611-0044 | 11,254.84 | 562.75 | 11,817.57 | 11,817.59 | -0.02 |
| ANF-2611-0045 | 11,283.30 | 564.17 | 11,847.47 | 11,847.47 | 0.00 |
| ANF-2611-0046 | 5,343.80 | 267.20 | 5,610.99 | 5,611.00 | -0.01 |

- **Where:** `services/api/internal/pint/pint.go:135-148` (per-line VAT); `:156-185`, especially `:169-171` and `:180-185` (independent gross calculation); `services/asp-mock/main.go` `cents` and `validate` functions (BR-CO-15 cent-level comparison).
- **Why:** IBT-112 should be consistent with the already calculated IBT-109 and IBT-110. Instead, it is derived independently from the unrounded product of quantity and unit price.
- **Evidence:** `evidence/source-analysis/al-noor-root-cause.md` and `al-noor-br-co-15-calculation.csv`.
- **Confidence:** High for the reproducible code/workbook defect. Confirm the exact stored payload and ASP response for the live import before closing the customer case.

### Customer resolution reply OR escalation note

**Escalate to L3 Engineering.** The source and sample data demonstrate a product calculation defect; the customer should not be asked to alter correct dispatch records.

> Dear Engineering,
>
> **Priority:** P2 — subset of Al Noor invoices rejected; external VAT audit in progress.
>
> **Affected seller:** Al Noor Fuel & Lubricants LLC, seller ID 4, Peppol ID `0235:1005362841`.
>
> **Affected invoices:** `ANF-2611-0042`, `ANF-2611-0044`, `ANF-2611-0046`.
>
> **Symptom:** ASP rejects these invoices with BR-CO-15. Other invoices in the same workbook pass.
>
> **Reproduction:** Use `samples/al-noor-fuel-nov-2026.xlsx`. The generated totals are:
> - `0042`: IBT-109 14,307.08 + IBT-110 715.35 = 15,022.43, but IBT-112 is 15,022.42.
> - `0044`: 11,254.84 + 562.75 = 11,817.59, but IBT-112 is 11,817.57.
> - `0046`: 5,343.80 + 267.20 = 5,611.00, but IBT-112 is 5,610.99.
>
> **Suspected cause:** `services/api/internal/pint/pint.go:171` computes gross independently from unrounded quantity × unit price, while line VAT is calculated from rounded line net (`:147`) and totals are rounded separately (`:181-185`).
>
> **Ask:** Correct IBT-112 calculation consistently with IBT-109 + IBT-110; add regression tests for 3-decimal unit prices and cent rounding. Advise safe reprocessing after verifying ASP receipts.
>
> **Customer update due:** 11:30 UAE time.

### Workaround offered

Do not ask the customer to manually change dispatch quantities, prices or totals. Preserve the source workbook and payload. After Engineering fixes the calculation, regenerate/reprocess only the rejected invoices, after confirming the ASP did not accept them. Rejected invoices do not consume their invoice numbers per the documented lifecycle.

### Prevention ideas

- Calculate IBT-112 consistently as IBT-109 + IBT-110 after the approved rounding steps.
- Use decimal/fixed-point money arithmetic rather than binary floating-point for invoice totals.
- Add unit and integration tests for 3-decimal prices, multiple lines, per-line VAT rounding and BR-CO-15.
- Add a pre-submission invariant check so an invalid total is caught before the ASP call.
- Include the three total fields in a customer-readable diagnostic report.

---

## Incident 4 — BluePeak / Sahara Medical: invoices not received by buyer

### Acknowledgement

- **Received:** 11:30
- **Proposed sent at:** 11:45 (within P2 first-response target of 12:30)
- **Reply:**

> Hi Daniel,
>
> Thanks for holding the connector resend. HTTP 201 from our import endpoint confirms that the batch was accepted for import; it does not prove that all 40 invoices were accepted by the ASP or delivered to the buyer. The empty ASP references are important, so we’ll reconcile the invoice status history against the ASP’s received-document list before recommending any resend.
>
> Please keep the connector resend paused. I’ll provide a per-invoice delivery breakdown and safe next steps by 12:30 UAE time.
>
> Regards,
> Invoicely Lite Support

### Priority and justification

- **Priority:** P2.
- **Why:** A 40-invoice ERP batch is only partially reaching the buyer and the hospital payment run is this week. The customer is correctly holding the resend to avoid duplicates. This is a subset / integration delivery issue; raise to P1 if live evidence confirms invoices are not reaching the ASP for one or more customers.
- **SLA:** first response within 1 hour (12:30); resolution target 8 hours (19:30); updates every 2–4 hours. Proposed acknowledgement 11:45.

### Investigation log

| Exercise time | What I checked / did | Finding |
|---|---|---|
| 11:45 | Acknowledge and stop full-batch resend | Draft prepared |
| 11:55 | Inspected supplied Sahara workbook | 60 line rows grouped into 40 invoice numbers |
| 12:05 | Reviewed ASP mock fair-use policy | 8-document burst, then 2 documents/second per sender |
| 12:10 | Reviewed API submission worker response switch | HTTP 429 is not handled; no status transition is made after the pre-send `Submitted` update |
| 12:15 | Reviewed retry eligibility | Only `Validated` and `Failed` can be retried; `Submitted` cannot |
| 12:25 | Prepared reconciliation queries for ASP receipt list and invoice statuses | Live status counts and ASP IDs still need collection |

### Root cause

- **What happened:** The ASP mock enforces a per-sender rate limit of 8 burst documents, then 2 documents per second. The API submission worker uses four workers and moves each invoice to `Submitted` before sending. It handles 200, 422, 500, 502, 503 and 504 responses, but has no HTTP 429 branch. When the ASP returns 429, the invoice remains `Submitted` without an ASP message ID. The ASP rate-limit branch returns before storing the document, so that invoice is not in the ASP received-document list.
- **Why it matches the symptom:** The customer sees `Submitted` but an empty ASP reference, and the buyer has not received those invoices. The normal retry path rejects `Submitted` invoices because it only permits `Validated` or `Failed`.
- **Where:**
  - `services/asp-mock/main.go:32-40,134-150` — burst/rate limit and `Retry-After`.
  - `services/api/internal/submit/submit.go:111-128,133-150` — pre-send Submitted status and response handling with no 429 case.
  - `services/api/internal/httpapi/httpapi.go:255-276` — retry only accepts Validated or Failed.
- **Evidence:** `evidence/source-analysis/sahara-rate-limit-analysis.md`.
- **Confidence:** High for the missing-429 handling defect and its status consequence. Exact number of throttled invoices and message IDs must be measured in the running lab.

### Customer resolution reply OR escalation note

**Escalate to L3 Engineering** because the API mishandles an expected ASP rate-limit response and leaves invoices in a non-retryable ambiguous state.

> Hi Daniel,
>
> We have identified a likely issue in the ASP submission handling: the ASP can return HTTP 429 when the sender exceeds its fair-use rate, and our current submission worker does not transition those invoices into a retryable state. That can leave an invoice showing Submitted without an ASP reference even though the ASP did not receive it.
>
> Please continue to hold the full-batch resend. We are reconciling all 40 invoice numbers against the ASP receipt list. We will separate invoices already accepted from those confirmed absent, and only the latter will be retried through a controlled recovery. I’ll send the invoice-level breakdown after reconciliation is complete.
>
> Regards,
> Invoicely Lite Support

### Workaround offered

1. Pause connector resend.
2. Query `GET /v1/documents?sender=0235:1006453719` and reconcile all 40 invoice numbers against ASP message IDs.
3. Do not resend invoices present in the ASP list.
4. For invoices absent from the ASP but stuck `Submitted`, ask Engineering for a controlled, audited status repair to a retryable state; do not make ad hoc direct DB updates.
5. Retry with `Retry-After` / exponential backoff and idempotency after the defect is fixed.

### Prevention ideas

- Handle 429 explicitly and honour `Retry-After`; use bounded exponential backoff with jitter.
- Persist an unambiguous submission outcome for every HTTP response.
- Make retry logic idempotent and reconcile uncertain network outcomes before retry.
- Alert on old `Submitted` invoices with empty ASP references.
- Add an end-to-end batch reconciliation report and integration contract tests for 429.

---

## Incident 5 — Ghaf Tree Café: date format rejected

### Acknowledgement

- **Received:** 12:10
- **Proposed sent at:** 12:25
- **Reply:**

> Hello Hessa,
>
> I understand that all four invoices were rejected and that 13/11/2026 is intended to mean 13 November 2026. I checked the attached workbook: the issue-date and due-date values are stored as text in slash-separated format, rather than as Excel date cells or ISO `YYYY-MM-DD` text.
>
> The portal does not guess date order because the same slash-separated value can mean different dates in different regions. You can keep the intended date and change only the format. I’ll send the exact Excel steps now.
>
> Regards,
> Invoicely Lite Support

### Priority and justification

- **Priority:** P4 — product working as documented / how-to.
- **Why:** The supplied workbook stores all date values as text in a format explicitly rejected by the documented template rule AE-BR-04. This is one customer's workbook-format issue with a straightforward correction. Reassess to P3 if the customer remains unable to issue invoices after following the documented workaround or if a wider parser defect is found.
- **SLA:** first response within 1 business day (by Tuesday 17 Nov 12:10); resolution target 5–10 business days; updates as agreed. Proposed acknowledgement 12:25 on the same day.

### Investigation log

| Exercise time | What I checked / did | Finding |
|---|---|---|
| 12:25 | Acknowledge and explain format requirement | Draft prepared |
| 12:30 | Inspected `samples/ghaf-cafe-nov-2026.xlsx` | Four invoices, eight non-empty line rows |
| 12:35 | Inspected issue/due date cell types | D2:D9 and E2:E9 are stored as text/shared strings |
| 12:40 | Compared workbook values with `sheet.ParseDate` and AE-BR-04 | Slash-separated text is rejected; ISO text and Excel serial dates are accepted |
| 12:45 | Prepared customer correction instructions | No runtime re-upload performed |

### Root cause

- **What happened:** The issue-date and due-date values in the actual workbook are stored as text, e.g. `13/11/2026`, `14/11/2026`, `15/11/2026`. The portal accepts `YYYY-MM-DD` text or real Excel date cells, not slash-separated text.
- **Where:** `services/api/internal/sheet/sheet.go:167-185` parses ISO strings and Excel serial dates; `services/api/internal/validate/validate.go:113-118` raises AE-BR-04.
- **Evidence:** `evidence/source-analysis/ghaf-date-analysis.md`.
- **Confidence:** High; workbook cell types and parser behavior agree with the reported validation error.

### Customer resolution reply

> Hello Hessa,
>
> You can keep the intended date of 13 November 2026. Please change only how it is stored:
>
> 1. If the cells are real Excel dates, select the date column, choose **Format Cells → Custom**, and enter `yyyy-mm-dd`.
> 2. If the values were typed as text, convert them to ISO format, for example `2026-11-13`, `2026-11-14` and `2026-11-15`, then paste the results back as values.
> 3. Save the workbook and upload the corrected file.
>
> Before uploading, please confirm the date still represents the intended day. The portal will then read it in the required unambiguous format.
>
> Regards,
> Invoicely Lite Support

### Workaround offered

Convert text dates to ISO format or convert them to actual Excel date cells and apply the `yyyy-mm-dd` display format. Do not alter the intended calendar date.

### Prevention ideas

- Include a date-format example beside the upload field.
- Provide a downloadable error report identifying sheet, row, column and invalid value.
- Add a pre-upload template checker for text-formatted dates.
- Keep strict date validation; do not silently guess ambiguous dates.

---

## Overall

### Prioritisation

1. **Incident 2 — API restarts:** treat as a potential P1 and investigate first because of repeated API restarts, multiple-customer 502 reports and stuck invoices. Confirm the exact P1 condition (no invoices reaching ASP) immediately.
2. **Incident 1 — Oasis:** large 600-line month-end upload, 60-second proxy timeout vs ~120-second lookup time, and duplicate retry risk.
3. **Incident 4 — Sahara:** 40-invoice batch, ASP 429 handling defect and unsafe resend risk before payment run.
4. **Incident 3 — Al Noor:** three reproducible BR-CO-15 invoice-total defects and external VAT audit.
5. **Incident 5 — Ghaf:** documented workbook date-format issue with a clear customer-side workaround.

The order can change as evidence arrives. If Sahara's reconciliation shows no invoices reaching the ASP for a customer, raise it to P1. If the API recovers and the backlog drains, downgrade Incident 2 and communicate the change.

### What I would do differently

- Start with a clean baseline import, then replay each affected customer separately to isolate defects before running the full peak load.
- Capture import IDs, invoice IDs, correlation IDs, timestamps and ASP references at the first upload.
- Distinguish portal import acceptance (HTTP 201), API submission (`Submitted`), ASP acceptance (`Accepted` + message ID) and buyer delivery.
- Never recommend retry based only on a portal status; reconcile the ASP receipt list first.
- Preserve source workbooks and generated payloads for audit and engineering reproduction.
- Use a consistent incident log and provide a clear next-update time in every customer reply.

### What I learned / what I would need to learn

- PINT AE totals and the BR-CO-15 arithmetic invariant.
- Peppol participant lookup and ASP fair-use rate limiting.
- The difference between a synchronous import request, a browser proxy timeout and background processing continuing after the browser times out.
- How to correlate API and ASP logs, Prometheus metrics, Loki queries and PostgreSQL invoice history.
- Safe recovery design: idempotency, retry-after, bounded backoff, and reconciling uncertain delivery outcomes.
- Memory lifecycle and bounded caching in containerised services.

### Time log (real time)

| Date | From–to | What I worked on |
|---|---|---|
Detailed start/end timestamps were not recorded, so they are not reconstructed or estimated. Total time spent is approximately 5 hours, as recorded above.

### AI usage disclosure

ChatGPT was used to inspect the supplied repository, read source code and support documentation, inspect the Excel workbooks, calculate invoice totals, identify relevant code paths, and draft investigation notes and customer communications. Docker Compose was run and PostgreSQL was queried. Captured runtime logs and database results are included in `evidence/runtime/runtime-verification.txt`. No Grafana screenshots or historical API OOM confirmation are claimed. The current API and ASP container state is not proof that no earlier restarts occurred. AI assistance was used; customer replies are drafts only and were not sent.

---

## Evidence index

- Oasis upload analysis: `evidence/source-analysis/oasis-upload-analysis.md`
- API restart hypothesis: `evidence/source-analysis/api-restarts-analysis.md`
- Al Noor calculation and source analysis: `evidence/source-analysis/al-noor-root-cause.md` and `evidence/source-analysis/al-noor-br-co-15-calculation.csv`
- Sahara rate-limit analysis: `evidence/source-analysis/sahara-rate-limit-analysis.md`
- Ghaf workbook date analysis: `evidence/source-analysis/ghaf-date-analysis.md`
- Runtime SQL: `evidence/runtime-collection/queries.sql`
- Grafana / Prometheus queries: `evidence/runtime-collection/grafana-promql.md`
