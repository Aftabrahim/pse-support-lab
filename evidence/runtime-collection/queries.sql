-- Run against `make psql` after `make up` and the relevant `make replay`/`make load`.
-- These are read-only evidence queries; do not update production rows.

-- Oasis (seller_id=2): find all recent imports and invoice status distribution.
SELECT i.id AS import_id, i.filename, i.status AS import_status, i.created_at,
       i.row_count, i.invoice_count, i.duration_ms
FROM imports i
WHERE i.seller_id = 2
ORDER BY i.created_at DESC
LIMIT 20;

SELECT i.import_id, i.status, i.rejected_by, COUNT(*) AS invoices,
       MIN(i.created_at) AS first_created, MAX(i.updated_at) AS last_updated
FROM invoices i
WHERE i.seller_id = 2
  AND i.invoice_number LIKE 'OBS-2611-%'
GROUP BY i.import_id, i.status, i.rejected_by
ORDER BY i.import_id, i.status;

SELECT v.invoice_number, v.import_id, v.status, v.rejected_by,
       v.asp_message_id, v.errors, v.updated_at
FROM invoices v
WHERE v.seller_id = 2 AND v.invoice_number LIKE 'OBS-2611-%'
ORDER BY v.invoice_number, v.created_at;

-- Al Noor (seller_id=4): compare persisted PINT totals and ASP rejection response.
SELECT invoice_number, status, rejected_by,
       payload->'totals'->>'taxExclusiveAmount' AS ibt109,
       payload->'totals'->>'taxAmount' AS ibt110,
       payload->'totals'->>'taxInclusiveAmount' AS ibt112,
       errors, asp_response
FROM invoices
WHERE seller_id = 4 AND invoice_number LIKE 'ANF-2611-%'
ORDER BY invoice_number;

-- Sahara (seller_id=5): stuck Submitted records and missing references.
SELECT invoice_number, status, asp_message_id, asp_response, updated_at
FROM invoices
WHERE seller_id = 5 AND invoice_number LIKE 'SMS-1116-%'
ORDER BY invoice_number;

SELECT status, COUNT(*) AS invoice_count
FROM invoices
WHERE seller_id = 5 AND invoice_number LIKE 'SMS-1116-%'
GROUP BY status
ORDER BY status;

-- Ghaf (seller_id=6): portal rejection details.
SELECT invoice_number, status, rejected_by, errors
FROM invoices
WHERE seller_id = 6 AND invoice_number LIKE 'GTC-%'
ORDER BY invoice_number;
