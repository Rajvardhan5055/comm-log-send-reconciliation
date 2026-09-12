# Comm-Log Send Reconciliation

Take-home: reconcile the `target_base` metric for merchant 501's Diwali
campaigns in October 2026, and get from a naive row count to Finance's
number (22) with every step justified by the data.

## Structure

```
data/                    raw data as given (SQLite db + CSVs)
sql/00_naive_baseline.sql       the first, obvious query -> 30
sql/01_investigation.sql        queries used to find each discrepancy
sql/02_final_target_base.sql    final query -> 22, nothing hardcoded
sql/03_validation.sql           two independent checks on the result
RECONCILIATION.md               write-up: bridge, findings, summary
```

## Running it

```
sqlite3 data/comm_log.db < sql/00_naive_baseline.sql
sqlite3 data/comm_log.db < sql/02_final_target_base.sql
sqlite3 data/comm_log.db < sql/03_validation.sql
```

## TL;DR

A plain `COUNT(*)` over the scoped data gives 30. That number is wrong for
two reasons: one campaign in the mix was never approved (its sends still
happened, but they don't count for reporting), and two of the campaign
groups are retry chains where the same customer was messaged more than
once for the same underlying communication. Once unapproved sends are
dropped and retry chains are collapsed to distinct customers, the result
is 22 -- matching Finance. Full reasoning is in `RECONCILIATION.md`.
