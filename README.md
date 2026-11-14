# PSE Support Lab — Invoicely Lite

This repository contains the PSE support assignment investigation for the five customer inbox cases.

## Submission

- [Detailed submission report](SUBMISSION.md)
- [Evidence and investigation notes](evidence/)
- [Runtime verification queries](evidence/runtime-collection/queries.sql)
- [Grafana and Docker checks](evidence/runtime-collection/grafana-promql.md)

## Cases covered

1. Oasis Builders — upload stuck in Processing
2. Marina Bay — API container restarts / memory-pressure investigation
3. Al Noor Fuel — BR-CO-15 VAT rounding mismatch
4. BluePeak / Sahara Medical — ASP HTTP 429 and invoice-state reconciliation
5. Ghaf Tree Café — invoice date-format validation

## Evidence integrity

The analysis distinguishes source-code/workbook findings from runtime observations. Docker services were not started in the preparation environment, so no live database rows, container OOM state, runtime metrics, ASP message IDs, or customer emails sent are claimed. Customer communications are drafts only.

See `SUBMISSION.md` for detailed findings, limitations, and recommended next steps.
