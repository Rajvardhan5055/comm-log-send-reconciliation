-- Validate the final result.
-- Check the contribution of each campaign chain.
WITH RECURSIVE
eligible_campaign AS (
    SELECT id, merchant_id, parent_id, name
    FROM campaign
    WHERE merchant_id = 501 AND name LIKE '%Diwali%'
      AND creation_status IN ('approved','aborted','resumed','stopped')
      AND processing_status = 'processed'
),
root_walk(id, root_id) AS (
    SELECT id, id FROM eligible_campaign WHERE parent_id IS NULL
    UNION ALL
    SELECT ec.id, rw.root_id FROM eligible_campaign ec JOIN root_walk rw ON ec.parent_id = rw.id
),
is_standalone AS (
    SELECT c.id,
        CASE WHEN c.parent_id IS NULL
              AND c.id NOT IN (SELECT parent_id FROM campaign WHERE parent_id IS NOT NULL)
             THEN 1 ELSE 0 END AS standalone
    FROM eligible_campaign c
),
qualifying_sends AS (
    SELECT cl.customer_id, rw.root_id, s.standalone
    FROM communication_log cl
    JOIN root_walk rw ON cl.communication_id = rw.id
    JOIN is_standalone s ON s.id = rw.id
    WHERE cl.merchant_id = 501 AND cl.communication_type = '2'
      AND cl.sent_time >= '2026-10-01' AND cl.sent_time < '2026-11-01'
)
SELECT root_id,
       MAX(standalone) AS standalone,
       COUNT(*) AS raw_sends,
       COUNT(DISTINCT customer_id) AS distinct_customers,
       CASE WHEN MAX(standalone) = 1 THEN COUNT(*) ELSE COUNT(DISTINCT customer_id) END AS contribution
FROM qualifying_sends
GROUP BY root_id
ORDER BY root_id;

-- Independent cross-check using the campaign groups.
SELECT
    (SELECT COUNT(DISTINCT customer_id) FROM communication_log
     WHERE communication_id IN (9001, 9002, 9003))
  + (SELECT COUNT(*) FROM communication_log WHERE communication_id = 9101)
  + (SELECT COUNT(DISTINCT customer_id) FROM communication_log
     WHERE communication_id IN (9201, 9202))
AS target_base_check;
