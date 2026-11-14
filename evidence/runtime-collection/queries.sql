-- Runtime reconciliation queries. Confirm table/column names against the supplied schema before execution.

-- Import batches and their status
SELECT * FROM imports ORDER BY created_at DESC;

-- Invoice state distribution
SELECT status, COUNT(*) AS invoice_count
FROM invoices
GROUP BY status
ORDER BY status;

-- Investigate invoices marked Submitted without an ASP message identifier
SELECT *
FROM invoices
WHERE status = 'Submitted'
  AND (asp_message_id IS NULL OR asp_message_id = '');

-- Duplicate invoice numbers across imports
SELECT invoice_number, COUNT(*) AS occurrences, COUNT(DISTINCT import_id) AS import_count
FROM invoices
GROUP BY invoice_number
HAVING COUNT(DISTINCT import_id) > 1
ORDER BY occurrences DESC;

-- Inspect one affected invoice number after confirming its exact value
-- SELECT * FROM invoices WHERE invoice_number = '<invoice-number>';
