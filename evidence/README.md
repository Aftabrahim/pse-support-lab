# Evidence index

## Source analysis
- `source-analysis/CASE_ANALYSIS.md` — consolidated static investigation.
- `source-analysis/oasis-upload-analysis.md` — upload timeout and duplicate-risk analysis.
- `source-analysis/api-restarts-analysis.md` — memory/cache hypothesis and verification requirements.
- `source-analysis/al-noor-root-cause.md` — BR-CO-15 calculation defect.
- `source-analysis/al-noor-br-co-15-calculation.csv` — reproducible invoice calculations.
- `source-analysis/sahara-rate-limit-analysis.md` — HTTP 429 and ambiguous submission-state defect.
- `source-analysis/ghaf-date-analysis.md` — workbook date-format analysis.

## Runtime evidence
- `runtime/runtime-verification.txt` — Docker status, current API/ASP state, ASP acceptance logs and PostgreSQL invoice records captured on 15 November 2026.
- `runtime-collection/queries.sql` — read-only SQL used for verification.
- `runtime-collection/grafana-promql.md` — suggested monitoring queries.

## Evidence limitations
The runtime capture is a point-in-time snapshot. API and ASP containers were running and healthy at capture, with current restart count zero and `OOMKilled=false`; this does not rule out earlier restarts or OOM events.

The captured database output contains 16 Oasis records (eight October and eight November) and 12 accepted Sahara October records. It does not establish the outcome of the 40-invoice November Sahara batch. The eight November Oasis ASP acceptance records are also present in the ASP logs with message IDs.

No Grafana screenshots or historical API OOM confirmation are claimed. Customer communications are drafts only and were not sent.
