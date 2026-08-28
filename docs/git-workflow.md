# Git and Pull Request Workflow

Status: Approved by Faisal, 2026-08-28

## Purpose

Use a consistent review workflow so analytical code, metric logic, tests, and documentation do not change the trusted `main` branch without validation and approval.

## Branch roles

- `main` contains the latest reviewed and approved project state.
- A feature branch contains one scoped piece of work under development.
- A pull request compares the feature branch with `main` and records the change, evidence, review, and decision to merge.

Creating or pushing a feature branch does not change `main`. Only merging the approved pull request brings the feature-branch commits into `main`.

## Working cycle

1. Start from an up-to-date `main` branch.
2. Create a clearly named feature branch.
3. Make one scoped improvement.
4. Run checks appropriate to the change.
5. Review the changed files and exclude secrets or generated output.
6. Stage only the intended files.
7. Create a focused local commit.
8. Push the feature branch to GitHub.
9. Open a pull request explaining the change and validation evidence.
10. Review and merge only after approval.
11. Update local `main` and remove the completed feature branch when safe.

## Branch naming

Use a short category followed by a specific outcome:

| Category | Example | Use |
|---|---|---|
| `docs/` | `docs/add-git-workflow-guide` | Documentation or case-study changes |
| `model/` | `model/add-stg-invoices` | New or changed dbt models |
| `test/` | `test/add-invoice-reconciliation` | Data-quality tests |
| `analysis/` | `analysis/payment-recovery` | Python or SQL analysis |
| `fix/` | `fix/payment-grain-duplication` | Correctness fixes |

## Commit messages

Write the commit subject as a short action and outcome:

```text
docs: add Git and pull-request workflow
model: add grain-preserving invoice staging model
test: reconcile successful attempts with paid invoices
fix: prevent invoice amount duplication across retries
```

Avoid vague messages such as `changes`, `update`, or `work done` because they do not explain what the snapshot contains.

## Validation expectations

Choose evidence that matches the risk of the change:

| Change | Minimum evidence |
|---|---|
| dbt model or source | Parse/build selected lineage and run associated tests |
| Business metric | Reconcile totals and document definition, grain, and exclusions |
| Python generation or analysis | Run the relevant script and independent checks |
| Documentation | Check claims against current files and verify links |
| Configuration | Confirm private values remain ignored and validate the consuming tool |

Before every commit or pull request:

- Review `git status` and the exact diff.
- Do not include credentials, tokens, personal data, local profiles, virtual environments, or generated warehouse extracts.
- State whether grains, joins, business definitions, row counts, or downstream models change.
- Record the commands or checks that passed.
- Keep planned work clearly separate from completed evidence.

## Pull request content

Every pull request should answer:

1. What changed?
2. Why is the change needed?
3. Which models, metrics, or documents are affected?
4. How was it validated?
5. What did not change?
6. Are there limitations, risks, or follow-up actions?

## Week 1 example

The branch `docs/add-git-workflow-guide` adds this guide and links it from the README. The change affects documentation only: it does not change raw data, BigQuery objects, dbt model SQL, tests, grains, or metric definitions.
