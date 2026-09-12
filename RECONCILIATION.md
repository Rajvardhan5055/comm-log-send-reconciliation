# Reconciliation: target_base for merchant 501, Diwali campaigns, Oct 2026

## Data model

`campaign` is one row per campaign. `parent_id` marks a retry -- if
campaign B has `parent_id = A`, B is a re-attempt of the same underlying
communication as A, and chains can go more than one level deep.
`creation_status` tracks approval, `processing_status` tracks whether the
send pipeline actually ran.

`communication_log` is one row per individual send attempt, linked to
`campaign` via `communication_id`.

Two rules from `README.md` drive the metric:

- A campaign only counts once `creation_status` is finalized (`approved`,
  or the other finalized values `aborted`/`resumed`/`stopped`) **and**
  `processing_status = 'processed'`. The send pipeline can run ahead of
  approval, so a campaign can have real rows in `communication_log` and
  still not qualify.
- `target_base` counts **distinct customers per underlying communication**
  (a campaign plus everything chained off it). A standalone campaign --
  no parent, nothing retries it -- is the exception: every send under it
  is its own event, even if the same customer shows up twice.

## What's actually in the data

Merchant 501, October 2026, all campaign names contain "Diwali":

| id | parent | creation_status | processing_status |
|----|--------|------------------|--------------------|
| 9001 | -- | approved | processed |
| 9002 | 9001 | approved | processed |
| 9003 | 9002 | approved | processed |
| 9004 | 9001 | **approval_awaiting** | processed |
| 9101 | -- | approved | processed |
| 9201 | -- | approved | processed |
| 9202 | 9201 | approved | processed |

Three structures: a three-deep retry chain (9001->9002->9003, with an
unapproved fourth retry 9004 hanging off 9001), one standalone campaign
(9101), and a two-campaign retry chain (9201->9202).

30 rows total in `communication_log` for this scope. 26 delivered, 4
failed.

## Naive baseline

```sql
SELECT COUNT(*) AS naive_count
FROM communication_log cl
JOIN campaign c ON c.id = cl.communication_id
WHERE c.merchant_id = 501
  AND c.name LIKE '%Diwali%'
  AND cl.sent_time >= '2026-10-01' AND cl.sent_time < '2026-11-01';
```

**Result: 30.** Reasonable first attempt -- scope filters are right -- but
it treats every log row as a qualifying send, with no regard for
approval status or retry chains.

## Working through the gap (30 -> 22)

**1. Campaign 9004 was never approved.**
It has `creation_status = 'approval_awaiting'` and 4 rows in
`communication_log`. Per the README, unapproved campaigns don't count
even if sends already happened for them. Drop those 4 rows.
`30 - 4 = 26`

**2. Chain 9001->9002->9003 has customers retried more than once.**
Customer `C2` appears under 9001 (failed) and 9002 (delivered) -- one
underlying communication, retried once. Customer `C3` appears under
9001, 9002, and 9003 -- retried twice before delivering. The README is
explicit that a retry chain represents one communication, so each of
these customers should count once, not once per attempt. Raw rows in
this chain: 13. Distinct customers: 10.
`26 - 3 = 23`

**3. Chain 9201->9202 has the same pattern.**
Customer `D1` failed on 9201, was retried and delivered on 9202. Raw
rows: 6. Distinct customers: 5.
`23 - 1 = 22`

**4. Checked: standalone campaign 9101 should NOT be deduped.**
Customer `C20` appears twice under 9101 (Oct 10 and Oct 20), but 9101 has
no parent and nothing retries it -- it's not a retry chain, it's a
standalone campaign, and the README says every send under a standalone
campaign counts on its own. No adjustment here; confirms we didn't
over-apply the dedup rule from steps 2-3.

Lands exactly on 22.

## Reconciliation bridge

| Step | Description | Result | Reason |
|---|---|---|---|
| 0 | Naive `COUNT(*)` of all Diwali sends, merchant 501, Oct 2026 | 30 | Starting point -- every log row treated as a qualifying send |
| 1 | Exclude campaign 9004 (4 rows) | 26 | `approval_awaiting` -- never cleared approval, doesn't count even though sends exist |
| 2 | Collapse chain 9001->9002->9003 from 13 raw sends to 10 distinct customers | 23 | C2 and C3 are retries of the same underlying communication -- count once each |
| 3 | Collapse chain 9201->9202 from 6 raw sends to 5 distinct customers | 22 | D1 retried, same underlying communication -- counts once |
| -- | Standalone campaign 9101 left un-deduped (7 rows, C20 counted twice) | 22 (no change) | Not a retry chain -- every send counts on its own per the README |
| **Final** | **Reconciled target_base** | **22** | Matches Finance |

## Final query

See `sql/02_final_target_base.sql`. It doesn't hardcode 22 -- the number
falls out of the eligibility filter and the recursive walk up
`parent_id`. Validated two ways in `sql/03_validation.sql`: a per-chain
breakdown (9001-chain -> 10, 9101 -> 7, 9201-chain -> 5) and an
independent, non-recursive cross-check built from plain subqueries.

## What stood out

The easiest mistake to make here is joining `communication_log` without
also checking `campaign.creation_status` -- campaign 9004 has real send
rows despite never being approved, so a naive join silently pulls in
sends Finance would never sign off on. The other thing worth flagging:
"same customer appears twice" doesn't mean the same thing everywhere in
this dataset. Inside a `parent_id`-linked retry chain it means one
message, retried, and should be deduped. Under a standalone campaign it
can mean a genuine second, independent send, and shouldn't be.

## Summary

Finance's target_base of 22 reflects distinct customers reached per
underlying communication, not raw send volume. The naive count of 30
overcounts for two reasons: 4 sends belong to a campaign that was never
approved, and two of the campaign groups are retry chains where the same
customer was attempted multiple times before finally delivering. Once
those are corrected -- and the one standalone campaign is deliberately
left alone, since its repeat send is a separate legitimate event -- the
number is 22: 10 from the first retry chain, 7 from the standalone
campaign, 5 from the second retry chain.
