-- Treats every communication_log row as a send.

SELECT COUNT(*) AS naive_count
FROM communication_log cl
JOIN campaign c ON c.id = cl.communication_id
WHERE c.merchant_id = 501
  AND c.name LIKE '%Diwali%'
  AND cl.sent_time >= '2026-10-01'
  AND cl.sent_time <  '2026-11-01';
