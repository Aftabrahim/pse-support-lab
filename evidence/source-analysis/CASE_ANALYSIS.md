# Source analysis — five inbox cases

This document records source/workbook-level findings. It does not claim live runtime verification.

## Oasis Builders — upload timeout and duplicate risk

- 600 data rows, eight invoice numbers, five distinct buyer participant IDs.
- Per-row directory lookup at 200 ms implies roughly 120 seconds of lookup time.
- Proxy timeout is 60 seconds; importer processing uses a detached background context.
- Invoice records are inserted before group validation, so repeated uploads can encounter existing records.
- Reconcile import and ASP state before retrying; batch/cache participant lookups and make import idempotent.

## Marina Bay — API restarts

- API container memory limit: 128 MB.
- In-memory cache retains upload/workbook/invoice objects without an evident TTL, eviction, or delete path.
- Load profile includes 240 uploads with eight concurrent workers.
- This supports a memory-pressure hypothesis only. Confirm with Docker OOMKilled, exit code, restart count, logs, memory/heap metrics and request/error rates.

## Al Noor Fuel — BR-CO-15

| Invoice | Generated | Expected | Difference |
|---|---:|---:|---:|
| ANF-2611-0042 | 15022.42 | 15022.43 | -0.01 |
| ANF-2611-0044 | 11817.57 | 11817.59 | -0.02 |
| ANF-2611-0046 | 5610.99 | 5611.00 | -0.01 |

The likely defect is inconsistent rounding bases: VAT is calculated from rounded line-net amounts while the inclusive total is independently calculated from quantity × unit price × (1 + VAT). Calculate the inclusive total consistently and add regression tests.

## BluePeak / Sahara Medical — HTTP 429

- ASP mock allows an initial burst of eight, then two documents per second.
- Submit worker sets Submitted before sending.
- No safe 429 branch is evident; retry endpoint accepts only Validated and Failed.
- Reconcile the 40 invoice numbers with ASP received documents/message IDs. Pause bulk retries; do not resend accepted invoices. Use an audited repair for confirmed unaccepted documents.

## Ghaf Tree Café — date validation

- Four invoices and eight line rows.
- Slash-separated text dates such as 13/11/2026 are not accepted by the parser, which supports ISO and Excel serial dates.
- Convert to true Excel date cells or ISO YYYY-MM-DD while preserving intended dates.
