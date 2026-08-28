# Raw Data Generation and BigQuery Load Validation

Validated: 2026-08-27

## Purpose

Prove that the approved synthetic source contract can be generated reproducibly, loaded into BigQuery with explicit schemas, and reconciled across all canonical relationships before dbt transformations begin.

## Reproducible inputs

- Contract: `docs/source-data-contract.md`
- Generator: `scripts/generate_synthetic_data.py`
- Independent file validator: `scripts/validate_generated_data.py`
- BigQuery schemas: `data/schemas/*.json`
- Safe loader: `scripts/load_bigquery_raw.sh`
- Fixed random seed: `20260827`
- BigQuery target: `skillspring-analytics.skillspring_raw` in EU
- Reporting cutoff: 2026-06-30

Generated CSV files and their manifest remain in ignored `data/generated/full/`; no synthetic row data or credentials are committed.

## Final manifest counts

| Raw table | Rows |
|---|---:|
| `customers` | 50,000 |
| `plans` | 8 |
| `subscriptions` | 46,810 |
| `subscription_events` | 128,957 |
| `invoices` | 128,633 |
| `payment_attempts` | 148,006 |
| `refunds` | 4,093 |
| `product_events` | 1,998,136 |
| `experiment_assignments` | 8,220 |
| **Total** | **2,512,863** |

The generated product-event count is within 0.1% of the proposed two-million-row target. Child-table counts follow the approved conversion, lifecycle, retry, refund, and reactivation rules rather than being forced to arbitrary totals.

## Validation evidence

### Independent local validation

The full 2,512,863-row output passed 11 validation groups with zero errors, covering:

- Manifest completeness and SHA-256 file checksums.
- CSV headers against explicit BigQuery schemas.
- Primary-key uniqueness and foreign-key resolution.
- Subscription-event sequence and snapshot reconciliation.
- Invoice amounts against canonical plan versions.
- Payment-attempt sequence and invoice-status reconciliation.
- Refund linkage and cumulative-amount limits.
- Product-event customer, session, access-period, vocabulary, and context rules.
- Experiment assignment and exposure timing.
- Manifest-to-file row counts.

### BigQuery validation

All nine load jobs completed without rejected rows. The version-controlled query `sql/validation/raw_load_validation.sql` then passed all 27 warehouse checks under a 2 GB maximum-bytes guard:

- Nine exact row-count comparisons.
- Eight duplicate-key checks.
- Seven orphaned-relationship checks.
- Three commercial snapshot and amount reconciliation checks.

## Defects caught and corrected

1. The first 500-customer smoke run found 14 lesson events occurring just after subscription access ended. The generator had placed the session start within access but had not reserved time for lesson completion. The session scheduler was corrected; the repeated 25,280-row smoke run passed with zero errors.
2. The first loader invocation stopped before creating any table because macOS's older Bash handling of an empty optional-argument array conflicted with strict mode. The loader was made portable and its syntax checked before the successful rerun.
3. The first warehouse-validation query used a composite-key distinct expression unsupported in this BigQuery context. The check was rewritten using the two controlled identifiers joined into a deterministic key; the repeated capped query passed all checks.

## Result and boundary

The raw layer is loaded and validated. This proves reproducible source generation and warehouse integrity; it does not yet prove that dbt source declarations, staging transformations, or business metrics are correct. Those require separate tests and evidence.
