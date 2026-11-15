# Incident 4 — Sahara: HTTP 429 leaves invoices stuck Submitted

## Workbook and ASP facts
- `samples/sahara-medical-batch-1116.xlsx` contains 60 line rows grouped into 40 invoice numbers.
- Seller Peppol ID: `0235:1006453719`.
- The ASP mock rate limit is per sender: burst capacity 8, then refill 2 documents/second (`services/asp-mock/main.go:32-40, 134-150`).
- The ASP returns HTTP 429 with `Retry-After` when the bucket is empty; this branch returns before the ASP document is stored (`main.go` handler `submit`, rate-limit branch).

## API defect
`services/api/internal/submit/submit.go:111-117` moves an invoice to `Submitted` before sending it. The response switch handles only:
- 200 (accepted) at 133-138,
- 422 (rejected) at 139-150,
- 500/502/503/504 (failed) immediately after this range.

There is no case for HTTP 429 and no default handler. Thus a 429 response is logged and counted as an ASP response, but the invoice remains `Submitted`; no ASP message ID is stored. The ASP did not accept/store the rate-limited document, which matches the empty ASP reference and buyer non-receipt.

The documented retry endpoint accepts only `Validated` or `Failed` invoices (`httpapi.go:255-276`; `status-lifecycle.md`). It will reject `Submitted` with HTTP 409, so the stuck invoices cannot be safely recovered through the normal retry button until status is repaired.

## Conclusion
The strongest code-supported root cause is missing 429 handling/backoff in the API submission worker. The actual number of 429s and accepted invoices must be confirmed from the live run's `invoicely_asp_responses_total`, `asp_documents_total`, API logs and invoice rows. Do not assert the exact accepted/rejected count without this evidence.

## Correct recovery
1. Pause connector resend.
2. Query ASP `GET /v1/documents?sender=0235:1006453719` and reconcile each invoice number/message ID.
3. For invoices definitely absent from ASP, Engineering should transition the affected stuck `Submitted` records to a retryable state through a controlled, audited repair (not by direct ad hoc update), then retry with `Retry-After` / exponential backoff and idempotency.
4. Never resend an invoice already present at the ASP.
