# dbt-to-BigQuery Connection Validation

Validated: 2026-08-27

## Purpose

Prove that the project can use dbt Core and its BigQuery adapter to authenticate, reach the correct cloud project, and target the correct analytics dataset before any business models are built.

## Data-layer boundary

| Dataset | Role | Write owner |
|---|---|---|
| `skillspring_raw` | Immutable synthetic source tables | Data-generation and loading workflow |
| `skillspring_analytics` | Cleaned staging, intermediate, and business-mart relations | dbt |

Both datasets are in BigQuery's EU multi-region. Keeping them separate protects the source records and makes the transformation lineage explicit.

## Configuration boundary

- `dbt/dbt_project.yml` is shared and version controlled. It defines the project and model structure.
- `.tools/dbt/profiles.yml` is local and ignored. It selects BigQuery project `skillspring-analytics`, analytics dataset `skillspring_analytics`, EU location, and OAuth authentication.
- Application Default Credentials are local and ignored. No account identity, access token, authorization code, or credential file is committed.

## Validation evidence

1. The initial `dbt debug` passed project, profile, Git, and BigQuery-adapter checks but failed the live connection because Application Default Credentials did not yet exist.
2. Faisal completed Google's one-time application authorization.
3. The repeated `dbt debug` reported `Connection test: OK connection ok` and `All checks passed` using dbt Core 1.11.14 and BigQuery adapter 1.11.3.

## Result

The full connection chain is verified:

`dbt SQL and configuration -> dbt-bigquery adapter -> local Google authorization -> skillspring-analytics.skillspring_analytics`

This clears the dependency for declaring raw sources and building the first staging models. It does not yet prove that source tables exist or that business transformations are correct; those require separate evidence.
