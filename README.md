# Comm-Log Send Reconciliation

Take-home assignment to reconcile the `target_base` metric for **merchant 501's Diwali campaigns during October 2026**.

**Finance target_base: 22**

## Objective

The goal is to start with a simple row count, investigate why it differs from Finance's number, and apply the business rules from the provided data dictionary to arrive at the correct `target_base`.

The reconciliation is:

```text
30  →  26  →  23  →  22
```

* **30** — initial scoped communication-log rows
* **26** — exclude sends from the campaign that was still awaiting approval
* **23** — collapse duplicate customers within the first retry chain
* **22** — collapse the duplicate customer within the second retry chain

The detailed investigation and reasoning are documented in `RECONCILIATION.md`.

## Repository Structure

```text
.
├── README.md
├── RECONCILIATION.md
│
├── data/
│   ├── campaign.csv
│   ├── communication_log.csv
│   └── comm_log.db
│
└── sql/
    ├── 00_naive_baseline.sql
    ├── 01_investigation.sql
    ├── 02_final_target_base.sql
    └── 03_validation.sql
```

## SQL Files

| File                       | Purpose                                     |
| -------------------------- | ------------------------------------------- |
| `00_naive_baseline.sql`    | Initial straightforward query → 30          |
| `01_investigation.sql`     | Queries used to investigate the differences |
| `02_final_target_base.sql` | Final calculation → 22                      |
| `03_validation.sql`        | Additional checks to validate the result    |

## Running the Queries

The queries can be run using SQLite:

```bash
sqlite3 data/comm_log.db < sql/00_naive_baseline.sql
```

Run the investigation queries:

```bash
sqlite3 data/comm_log.db < sql/01_investigation.sql
```

Run the final calculation:

```bash
sqlite3 data/comm_log.db < sql/02_final_target_base.sql
```

Run the validation checks:

```bash
sqlite3 data/comm_log.db < sql/03_validation.sql
```

## Result

The final query produces:

```text
target_base
-----------
22
```

The final SQL does not hardcode `22`; the result comes from applying the campaign eligibility and retry-chain rules to the underlying data.

## Documentation

See [`RECONCILIATION.md`](RECONCILIATION.md) for:

* the reconciliation bridge
* investigation steps
* reasons for each adjustment
* final SQL explanation
* validation results
* observations from the data

