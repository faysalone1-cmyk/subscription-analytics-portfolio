# SkillSpring Subscription Analytics

SkillSpring is a production-style analytics portfolio project for a fictional consumer learning app with free trials and monthly or annual subscriptions. The project will help Product, Growth, and Finance decide which onboarding or payment experience to improve to increase trial-to-paid conversion and 90-day retention without increasing refunds.

## Project status

Week 1 — repository and analytics-engineering foundations. The dbt project is connected to two EU BigQuery datasets. The validated `skillspring_raw` layer contains 2,512,863 deterministic synthetic rows across nine physical tables. The `skillspring_analytics` layer currently contains three tested dbt staging views.

## Evidence at a glance

| Evidence | Verified result |
|---|---:|
| Synthetic source rows | 2,512,863 |
| Raw BigQuery tables | 9 |
| Local validation groups | 11 passed |
| Warehouse raw checks | 27 passed |
| dbt staging views | 3 |
| dbt generic tests | 14 passed |
| Independent staging checks | 9 passed |

## Architecture and scope

The approved business scope, dataset boundary, entities, and seven-week delivery chain are documented in [`docs/project-brief.md`](docs/project-brief.md). The verified warehouse connection is documented in [`docs/dbt-connection-validation.md`](docs/dbt-connection-validation.md), raw generation/load evidence is in [`docs/raw-data-load-validation.md`](docs/raw-data-load-validation.md), and the first tested dbt lineage is in [`docs/dbt-staging-validation.md`](docs/dbt-staging-validation.md).

The current raw-to-staging system, component responsibilities, security boundary, and planned downstream layers are shown in [`docs/architecture.md`](docs/architecture.md).

Repository changes follow the branch, validation, review, and pull-request process documented in [`docs/git-workflow.md`](docs/git-workflow.md).

## Planned analytical flow

1. Generate documented synthetic subscription, invoice, payment, refund, and product-event data.
2. Load immutable raw tables into BigQuery.
3. Transform them with dbt through staging, intermediate, and mart layers.
4. Govern recurring-revenue, conversion, churn, cohort, and retention definitions.
5. Validate important metrics independently in Python.
6. Analyze an onboarding or payment experiment.
7. Publish a decision-focused dashboard and case study.

## Repository structure

- `docs/`: business scope, architecture, metric definitions, validation, and decision records.
- `data/`: explicit BigQuery schemas and instructions for reproducible synthetic data; generated extracts are ignored.
- `dbt/`: dbt project, source declarations, models, tests, macros, and documentation.
- `scripts/`: deterministic generation, independent validation, and raw BigQuery loading.
- `sql/validation/`: independent warehouse validation queries.
- `analysis/`: planned Week 5 Python analysis and metric validation; not yet created.
- `dashboard/`: planned Week 7 dashboard assets; not yet created.

## Reproduce the current foundation

### Prerequisites

- Python 3.10 or newer.
- A Google Cloud project with the BigQuery API available.
- Google Cloud CLI, including the `gcloud` and `bq` commands.
- EU BigQuery datasets named `skillspring_raw` and `skillspring_analytics`.

### Install dbt

Create an isolated Python environment and install the pinned dbt dependencies:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dbt.txt
dbt --version
```

The verified versions are dbt Core 1.11.14 and the BigQuery adapter 1.11.3.

### Configure BigQuery access

Authenticate locally, set your project ID, and copy the credential-free profile template into an ignored directory:

```bash
export GOOGLE_CLOUD_PROJECT="your-google-cloud-project-id"
gcloud auth application-default login
mkdir -p .tools/dbt
cp dbt/profiles.yml.example .tools/dbt/profiles.yml
```

The profile reads the project ID from `GOOGLE_CLOUD_PROJECT` and contains no account identity, token, or credential file. Validate the connection:

```bash
source .venv/bin/activate
dbt debug --project-dir dbt --profiles-dir .tools/dbt
```

### Generate, validate, load, and build

Generate the approved dataset with the fixed seed, validate it independently, load the nine raw tables, and build the current staging lineage:

```bash
python3 scripts/generate_synthetic_data.py --customers 50000 --output-dir data/generated/full
python3 scripts/validate_generated_data.py --data-dir data/generated/full
bash scripts/load_bigquery_raw.sh data/generated/full
dbt build --project-dir dbt --profiles-dir .tools/dbt --select path:models/staging
```

The generator refuses to overwrite known output unless explicitly instructed, and the loader does not silently replace an existing raw table. See [`data/README.md`](data/README.md) before intentionally regenerating or replacing data.

## Data and privacy

The project uses synthetic data and contains no real customer information or payment credentials. Git contains the reproducible definitions and validation logic—not live BigQuery objects. Secrets, local profiles, credentials, generated warehouse extracts, and local virtual environments are excluded from version control.
