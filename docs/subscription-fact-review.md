# Subscription fact review

Review date: 2026-10-17. Status: identified validation gaps fixed and verified; ready for deliberate Git staging review. No commits or staging changes performed.

## How the model works

`fct_subscriptions.sql` materializes a BigQuery table from `ref('stg_subscriptions')`. A normal dbt table build replaces the table with the latest input; it is not an incremental update or historical snapshot mechanism. Each input subscription produces exactly one output row because there are no joins, filters, aggregations, or deduplication. Input uniqueness remains essential.

The model retains subscription/customer/initial-plan/current-plan keys and lifecycle timestamps. Dimensions are joined downstream; they need not be joined merely to retain their foreign keys. The staging model derives `converted_to_paid` from the existence of `paid_started_at`, and `is_canceled` from current status. Conversion means ever reached paid, not currently active.

It adds UTC creation date, first day of creation month, whole elapsed 24-hour days from trial to paid, and whole elapsed days from creation to ending. The CASE expressions return NULL when a milestone has not happened. Completed lifetime is not the age of an ongoing subscription. Duration calculations do not themselves reject reversed dates.

## Existing tests and evidence

All 19 output columns are documented. Nineteen generic tests cover subscription uniqueness, required values, three foreign-key relationships, controlled statuses, and Boolean flags. Relationships verify parent existence, not parent uniqueness; dimension uniqueness tests provide that separate protection.

The saved 2026-10-12 run recorded this model succeeding and all 19 attached tests passing; across both dimensions and the fact it recorded three builds and 40 passing tests. Before today's parse, the current model matched the manifest raw SQL after stripping surrounding whitespace. This connects the source to the saved build, but is not a fresh comparison with the live table definition.

On 2026-10-16, live warehouse checks found 46,810 fact rows, zero failures across 12 validation controls, and zero violations in five supplemental alignment/key controls. These historical checks were not rerun for this review. No warehouse rebuild was performed today.

Today's dbt parse passed. Working-tree formatting passed. Staged formatting failed because the staged fact contains an extra EOF blank line already removed in the working copy; refresh staging deliberately after review.

## Original findings (resolved below)

1. Paid-period validation misses required NULL values. In `subscription_fact_validation.sql`, lines 97–102 only count non-NULL starts whose end is <= start. An active row with both timestamps NULL, or a missing end, is not counted because COUNTIF ignores NULL. Add explicit requiredness checks for active/past_due plus paired timestamp and range checks.
2. No automated dbt singular test enforces subscription lifecycle semantics. Generic tests allow reversed trial/paid/end chronology, canceled rows without `ended_at`, and non-canceled rows with `ended_at`. Add a zero-row business-rule test for the approved source-contract rules. The existing duration checks merely recompute the same expression, so they cannot establish that the underlying sequence makes business sense.
3. Scripts in `sql/validation/` are manual checks, not dbt tests. Include the supplemental alignment query in the package: equal row counts alone cannot detect a missing subscription replaced by another ID. Preserve a clear manual execution/evidence requirement. The CI workflow parses dbt but does not run warehouse tests.

Cross-subscription overlap and reconciliation to latest lifecycle events remain additional source-contract coverage to plan explicitly. Event modeling is not implemented in this change; do not claim this fact validates event history.

## Proposed Git review scope

Include the existing fact SQL, `_core_models.yml`, `subscription_fact_validation.sql`, `subscription_fact_alignment.sql`, this review, and any subsequently approved lifecycle test/fixes. Inspect before staging; do not use a blanket add.

Keep the country/career analyses, their reports, and career validation out of this model package. Existing staged content was preserved, including the older fact-file whitespace version. No commit or PR has been created.

## Validation fixes and fresh evidence — 2026-10-17

- Corrected manual paid-period validation to reject missing required timestamps for active/past_due subscriptions, one-sided timestamp pairs, and reversed/equal period endpoints.
- Added `dbt/tests/fct_subscriptions_business_rules.sql`. It rejects invalid trial/paid/end ordering, missing paid milestones for active/past_due states, invalid billing periods, canceled subscriptions without end timestamps, end timestamps on non-canceled states, paid milestones on trialing subscriptions, and cancellation requests outside the subscription lifetime.
- Required milestone NULL values remain covered by the existing generic tests. The singular test complements those tests rather than replacing them.
- dbt parse passed. Fresh live dbt test run: PASS=41, WARN=0, ERROR=0, SKIP=0 across both dimensions and the subscription fact (40 generic tests plus one new singular test).
- Reran all 12 independent manual controls: zero violations, including the corrected paid-period check.
- Reran source/key alignment: 46,810 fact rows, zero NULL subscription IDs, duplicate dimension keys, unmatched subscription IDs, or source customer/status mismatches.
- Eleven temporary boundary fixtures exercised the actual lifecycle predicate using SQLite NULL/Boolean behavior: valid active/trial/canceled examples passed; missing period endpoints, reversed periods/trials, paid-before-trial, canceled-without-end, and active-with-end examples were rejected. Actual model tests separately passed in BigQuery. Fixtures are predicate checks, not a replacement for warehouse execution.
- No fact SQL changes, warehouse rebuilds, staging changes, or commits performed. Refresh the existing staged snapshot after reviewing the final working tree; its old EOF whitespace issue remains until then.

## Next Git review

Include `dbt/tests/fct_subscriptions_business_rules.sql` with the model package listed above. Review working-tree changes, deliberately stage the selected paths, then inspect the staged diff and formatting. Keep exploratory country/career analysis files separate. Event-history reconciliation and cross-subscription overlap coverage remain explicitly outside this patch; this change does not claim to implement every source-contract rule.
