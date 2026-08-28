# Environment Readiness

Checked: 2026-08-27

Status: dbt-connected — local repository, dbt BigQuery toolchain, Google Cloud CLI, authentication, active sandbox project, EU datasets, and a live dbt connection are verified. GitHub remote workflow remains pending.

## Evidence

| Capability | Observed evidence | Status |
|---|---|---|
| Operating system | macOS 14.0 on x86_64 | Ready |
| Git | Apple Git 2.39.3 | Ready |
| Local repository | Git repository initialized on `main` in `subscription-analytics-portfolio/` | Ready |
| Python | Python 3.13.1 and pip 26.2.1 | Ready |
| dbt Core and BigQuery adapter | Project-local dbt Core 1.11.14 and BigQuery adapter 1.11.3; dependency integrity check passed | Ready |
| Google Cloud CLI | Project-local Google Cloud SDK 582.0.0 | Ready |
| BigQuery CLI | Project-local BigQuery CLI 2.1.37 | Ready |
| GitHub CLI | `gh` command not found | Pending; required for the planned command-line pull-request workflow |
| Homebrew, uv, and pipx | Commands not found | Not blockers; the project can use a local Python virtual environment and official installers |
| Google Cloud authentication | User authorization completed in ignored local Cloud configuration; account identity is not stored in repository files | Ready |
| Google account | Faisal confirmed an existing Google account and completed the OAuth consent flow personally | Ready |
| BigQuery project | `skillspring-analytics`, lifecycle state `ACTIVE`, selected as the local Cloud project | Ready |
| BigQuery API | `bigquery.googleapis.com` returned in the enabled-service check | Ready |
| Billing | Read-only Cloud Billing check returned `False` | Disabled; sandbox route confirmed |
| BigQuery query | EU-location `SELECT 1 AS connection_test` succeeded with a 1 MB maximum-bytes-billed guard | Ready |
| BigQuery datasets | EU datasets `skillspring_raw` and `skillspring_analytics` created and returned by BigQuery metadata checks | Ready |
| dbt project | Version-controlled `dbt/dbt_project.yml` validated by dbt Core | Ready |
| dbt local profile | Ignored `.tools/dbt/profiles.yml` validated; targets project `skillspring-analytics`, dataset `skillspring_analytics`, and EU location | Ready |
| dbt authentication | Application Default Credentials saved only in ignored local Cloud configuration | Ready |
| dbt-to-BigQuery connection | `dbt debug` reported `Connection test: OK connection ok` and `All checks passed` | Ready |
| GitHub authentication and remote | Not tested because the CLI is absent and no remote exists | Pending |

## Compatibility decisions

- Use a project-local `.venv` rather than installing dbt into the system Python environment.
- Pin dbt Core 1.11.14, the BigQuery adapter 1.11.3, and cryptography 46.0.4 in `requirements-dbt.txt` so this Intel-Mac/Python 3.13 environment is reproducible.
- Python 3.13 is supported by the selected dbt release line.
- Use the official macOS x86_64 Google Cloud CLI package; installed SDK 582.0.0 includes BigQuery CLI 2.1.37.
- The downloaded Google Cloud CLI archive matched Google’s published SHA-256 checksum `cf366d92cda5e0e10d9ed78ac56bf3e0e9b1aec805028be67631760135c696fb` before extraction.
- Keep the SDK and `CLOUDSDK_CONFIG` under ignored `.tools/` so shell configuration and authentication artifacts are not committed.
- Never commit `profiles.yml`, service-account files, access tokens, or other credentials.
- Keep raw source tables in `skillspring_raw`; dbt writes cleaned and modeled relations to `skillspring_analytics` so source records remain unchanged.

## Installation findings

- dbt 1.12 was not accepted for this environment because its experimental-parser package attempted an additional GitHub binary download that failed certificate validation.
- The first dbt 1.11 attempt selected cryptography 50, which lacked a compatible prebuilt Intel-Mac wheel and attempted a local OpenSSL build.
- Pinning cryptography 46.0.4 selected its verified universal macOS wheel. The final dbt installation succeeded and `pip check` reported no broken requirements.
- The cache-access and restricted latest-version lookup warnings did not affect the installed project environment or its dependency-integrity result.
- The first `bq` launch attempted to write to the default user configuration directory. Redirecting `CLOUDSDK_CONFIG` to ignored `.tools/gcloud-config` resolved this without changing the global shell profile.
- A later `bq` launch fell back to Apple Python 3.9 when its tool path was restricted. Explicitly setting `CLOUDSDK_PYTHON` to the verified Python 3.13 interpreter resolved the issue.
- The first `dbt debug` validated the project and adapter but could not open a warehouse connection because Application Default Credentials were absent. A separate one-time Google application authorization was completed in ignored local configuration; the repeated test then passed every check.

## BigQuery access decision

- Faisal began with a Google account and no billing-enabled BigQuery environment; the no-billing sandbox project is now active and authenticated.
- Selected route: BigQuery Sandbox, which does not require a credit card or billing account.
- Sandbox capacity is sufficient for this portfolio: 10 GB active storage and 1 TB query processing per month.
- Sandbox limitation to manage: tables, views, and partitions expire after 60 days. This is compatible with the seven-week schedule, but final artifacts must be exported and reproducible.
- Sandbox does not support DML, streaming, or BigQuery Data Transfer Service. Initial dbt models will use full table/view builds; any incremental `merge` demonstration requires a later billing-enabled upgrade.

## Completion checks

- [x] Git availability verified.
- [x] Local repository initialized on `main`.
- [x] Python availability verified.
- [x] Project-local dbt and BigQuery adapter installed and version verified.
- [x] Google Cloud CLI and BigQuery CLI installed and version verified.
- [x] Google Cloud authentication and selected project verified.
- [x] BigQuery API and disabled-billing status verified.
- [x] BigQuery query executed successfully with a maximum-bytes guard.
- [x] EU raw and analytics datasets created.
- [x] Shared dbt project configuration and ignored local profile validated.
- [x] Live dbt-to-BigQuery connection passed `dbt debug`.
- [ ] GitHub authentication and repository remote verified.

## Next safe action

Define the physical columns, keys, generation rules, and validation expectations for the approved synthetic source entities. Then generate and load the raw tables before declaring dbt sources and building the first staging models. GitHub CLI, authentication, and remote setup remain a separate Week 1 task.
