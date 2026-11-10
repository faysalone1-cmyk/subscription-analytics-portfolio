# Payment Recovery Validation Review

Review date: 2026-11-05

## Summary

This change adds independent warehouse validation for the existing invoice-payment
lineage. It does not change model SQL, model grains, or production metrics. The
validation recomputes expected results from staging relations and compares them
with `int_invoice_payment_outcomes` and `mart_payment_recovery_daily`.

## Grain and lineage

The lineage changes grain deliberately:

1. `stg_payment_attempts` preserves one row per collection attempt.
2. `int_invoice_payment_outcomes` aggregates attempts and refunds to one row per
   invoice.
3. `mart_payment_recovery_daily` aggregates invoice outcomes to one row per
   invoice issue date.

An invoice with two failed attempts followed by one successful attempt therefore
has three staging attempt rows, one intermediate invoice row, and contributes to
one daily-mart row. This boundary prevents retry history from multiplying invoice
counts or billed amounts.

## Independent validation controls

`sql/validation/invoice_payment_outcomes_validation.sql` executes ten controls:

- Invoice-outcome row count equals staged invoice row count.
- `invoice_id` remains unique at the intermediate grain.
- Preserved invoice attributes agree with `stg_invoices`.
- Attempt counts, outcomes, sequence maximums, and collected amounts reconcile
  to `stg_payment_attempts`.
- Refund counts and amounts reconcile through payment attempts to `stg_refunds`.
- Payment outcome classification agrees with the approved business rules.
- Refund status classification agrees with cumulative refunded amounts.
- Collected, refunded, and net amounts reconcile in integer minor units and
  exact EUR values.
- Daily mart row count equals the number of invoice issue dates.
- Daily volumes and monetary totals reconcile to invoice-level outcomes.

The script is deliberately separate from dbt's attached tests. Attached tests
assert declared model rules; the independent query derives expected values from
upstream relations and checks the published outputs from another direction.

## Validation evidence

On 2026-11-05, the selected authenticated build ran:

```bash
dbt build \
  --project-dir dbt \
  --profiles-dir .tools/dbt \
  --select int_invoice_payment_outcomes+
```

Result:

- Two view models rebuilt.
- Forty-two data tests passed.
- `PASS=44 WARN=0 ERROR=0 SKIP=0`.

The independent query was run after the rebuild with EU location and a 2 GB
maximum-bytes guard. All ten controls returned `violation_count = 0` and
`passed = true`.

## Reproduction

From the repository root, activate the project toolchain and authenticated local
configuration before running dbt:

```bash
export PATH="$PWD/.tools/google-cloud-sdk/bin:$PATH"
export CLOUDSDK_CONFIG="$PWD/.tools/gcloud-config"
source .venv/bin/activate

dbt build \
  --project-dir dbt \
  --profiles-dir .tools/dbt \
  --select int_invoice_payment_outcomes+

bq query \
  --location=EU \
  --use_legacy_sql=false \
  --maximum_bytes_billed=2000000000 \
  < sql/validation/invoice_payment_outcomes_validation.sql
```

The local Google Cloud configuration, credentials, virtual environment, and
generated warehouse data remain ignored and are not part of the change.

## Scope and limitations

- Outcomes are attributed to the invoice issue-date cohort, not the later date
  on which a retry, collection, or refund occurred.
- The project uses synthetic EUR-denominated data and does not implement foreign
  exchange remeasurement or statutory revenue recognition.
- The validation proves the current full-refresh outputs; it does not test an
  incremental loading strategy.
- BigQuery execution requires local authentication because repository CI remains
  credential-free.

## Published Git scope

Include only:

- `sql/validation/invoice_payment_outcomes_validation.sql`
- `docs/payment-recovery-validation-review.md`

Pull request #12 included exactly these two files, passed CI, and merged into
`main`. The exploratory country and career-customer analyses remained outside
that production validation change and were reviewed later as a separate
documentation and analysis package.
