# Incident 3 — Al Noor: BR-CO-15 reproducible from workbook + source algorithm

## Workbook and calculation method
The attached workbook contains six invoices and 13 lines. All lines use VAT category `S` at 5%. Three invoice numbers have three-decimal unit prices and produce an inclusive total that differs from the ASP's required arithmetic.

The API source (`services/api/internal/pint/pint.go`) calculates each line VAT as `round2(line net amount × rate / 100)` (line 147). In `computeTotals`, it sums the rounded line net and rounded line VAT (166–170), but calculates gross independently as `quantity × unit price × (1 + rate/100)` (171). It then rounds that independent gross total (184–185).

The ASP mock compares integer cents: `services/asp-mock/main.go` function `cents` and `validate`, where BR-CO-15 checks `taxInclusiveAmount == taxExclusiveAmount + taxAmount`.

## Reproduced from the actual attached workbook

| Invoice | Lines | IBT-109 | IBT-110 | Generated IBT-112 | Required IBT-109 + IBT-110 | Difference |
|---|---:|---:|---:|---:|---:|---:|
| ANF-2611-0041 | 1 | 13,749.75 | 687.49 | 14,437.24 | 14,437.24 | 0.00 |
| ANF-2611-0042 | 3 | 14,307.08 | 715.35 | 15,022.42 | 15,022.43 | -0.01 |
| ANF-2611-0043 | 2 | 18,684.00 | 934.20 | 19,618.20 | 19,618.20 | 0.00 |
| ANF-2611-0044 | 4 | 11,254.84 | 562.75 | 11,817.57 | 11,817.59 | -0.02 |
| ANF-2611-0045 | 1 | 11,283.30 | 564.17 | 11,847.47 | 11,847.47 | 0.00 |
| ANF-2611-0046 | 2 | 5,343.80 | 267.20 | 5,610.99 | 5,611.00 | -0.01 |

The same rows are in `al-noor-br-co-15-calculation.csv`.

## Root cause
This is a product calculation defect, not a customer workbook arithmetic error: IBT-112 is independently recomputed from unrounded `quantity × unit price`, while IBT-109 and IBT-110 are derived from the rounded line-net amounts and rounded line VAT. It causes BR-CO-15 for exactly `ANF-2611-0042`, `ANF-2611-0044` and `ANF-2611-0046` in this workbook.

## Support action
Do not ask the customer to alter correct dispatch values or manually adjust the totals. Preserve the workbook and payloads, escalate to Engineering, correct the total-calculation implementation to calculate IBT-112 consistently as IBT-109 + IBT-110 (and review currency rounding policy), add regression tests for 3-decimal unit prices, then reprocess only the rejected invoices after confirming they were not accepted by the ASP.
