# SkillSpring Analytics Architecture

Status: Week 3 dimensional lineage validated and merged through 2026-11-05

## Purpose

This document explains how SkillSpring's approved synthetic source contract becomes tested analytical data. It distinguishes the current working architecture from the governed metrics, Python analysis, experiment, and dashboard planned for later weeks.

## Current and planned flow

```mermaid
flowchart LR
    subgraph localCode["Version-controlled project"]
        contract["Approved contract and schemas"]
        generator["Python data generator"]
        validator["Python data validator"]
        loader["BigQuery raw-data loader"]
        sources["dbt source declarations"]
        models["Fifteen dbt models across three layers"]
        checks["Generic tests, singular tests, and validation SQL"]
        evidence["Validation evidence"]
    end

    subgraph localData["Ignored local output"]
        csvFiles["Nine synthetic CSV files"]
    end

    subgraph warehouse["BigQuery project: skillspring-analytics, EU"]
        rawData["skillspring_raw: nine physical tables"]
        stagingViews["skillspring_analytics: eight staging views"]
        invoiceOutcomes["Invoice-grain payment outcomes"]
        recoveryMart["Daily payment-recovery mart"]
        dimensions["Customer and plan-version dimensions"]
        facts["Subscription, lifecycle-event, and product-event facts"]
    end

    subgraph planned["Planned later weeks"]
        dimensional["Governed metric marts and dictionary"]
        pythonAnalysis["Python analysis and experiment"]
        dashboard["Dashboard and case study"]
    end

    contract -->|"Controls generation"| generator
    generator -->|"Writes"| csvFiles
    csvFiles -->|"Checks rows and relationships"| validator
    csvFiles -->|"Loads with explicit schemas"| loader
    contract -->|"Supplies schemas"| loader
    loader -->|"Creates raw tables"| rawData
    rawData -->|"Referenced by"| sources
    sources -->|"Feeds"| models
    models -->|"Creates views"| stagingViews
    stagingViews -->|"Aggregated safely"| invoiceOutcomes
    invoiceOutcomes -->|"Grouped by invoice date"| recoveryMart
    stagingViews -->|"Publishes conformed entities"| dimensions
    stagingViews -->|"Publishes analytical events"| facts
    dimensions -->|"Enriches"| facts
    rawData -->|"Validated by"| checks
    stagingViews -->|"Validated by"| checks
    invoiceOutcomes -->|"Validated by"| checks
    recoveryMart -->|"Reconciled by"| checks
    checks -->|"Documents results"| evidence
    recoveryMart -.->|"Future input"| dimensional
    facts -.->|"Future input"| dimensional
    dimensional -.-> pythonAnalysis
    pythonAnalysis -.-> dashboard
```

Solid connections represent current working lineage. Dotted connections represent planned work and must not be interpreted as completed models or outputs.

## Layer responsibilities

| Component | Location | Responsibility | Persistence |
|---|---|---|---|
| Source contract and schemas | Repository | Define grains, keys, controlled values, relationships, and generation rules | Version controlled |
| Generated CSV files | Ignored local `data/generated/` directory | Reproducible warehouse-loading inputs | Local and disposable |
| Raw layer | BigQuery `skillspring_raw` | Preserve source-shaped synthetic records across nine entities | Nine physical tables |
| dbt source declarations | Repository | Register raw-table addresses, descriptions, and lineage without copying data | Version controlled metadata |
| Staging layer | BigQuery `skillspring_analytics` | Apply light, reusable, grain-preserving transformations | Eight logical views |
| Intermediate layer | BigQuery `skillspring_analytics` | Aggregate attempts and refunds safely to one row per invoice and classify outcomes | One logical view |
| Mart layer | BigQuery `skillspring_analytics` | Publish conformed dimensions, analytical facts, and daily invoice-cohort payment recovery | Five tables and one logical view |
| Tests and validation | Repository plus BigQuery execution | Detect grain, relationship, accepted-value, and transformation failures | Version-controlled tests and evidence |

## Current dbt lineage

| Raw source | Staging view | Preserved grain | Added logic |
|---|---|---|---|
| `skillspring_raw.customers` | `skillspring_analytics.stg_customers` | One row per customer | Signup date and governed reporting region |
| `skillspring_raw.plans` | `skillspring_analytics.stg_plans` | One row per plan version | Exact euro price and current-version flag |
| `skillspring_raw.subscriptions` | `skillspring_analytics.stg_subscriptions` | One row per subscription | Historical paid-conversion and current-cancellation flags |
| `skillspring_raw.invoices` | `skillspring_analytics.stg_invoices` | One row per invoice | Exact euro amount and paid-status flag |
| `skillspring_raw.payment_attempts` | `skillspring_analytics.stg_payment_attempts` | One row per payment attempt | Exact euro amount plus retry and success flags |
| `skillspring_raw.refunds` | `skillspring_analytics.stg_refunds` | One row per refund transaction | Exact euro amount with governed payment-attempt lineage and refund reasons |
| `skillspring_raw.subscription_events` | `skillspring_analytics.stg_subscription_events` | One row per lifecycle event | Calendar fields and preserved transition context |
| `skillspring_raw.product_events` | `skillspring_analytics.stg_product_events` | One row per product event | Calendar fields and governed event context |

| Upstream models | Downstream model | Resulting grain | Added logic |
|---|---|---|---|
| `stg_invoices`, `stg_payment_attempts`, `stg_refunds` | `int_invoice_payment_outcomes` | One row per invoice | Attempt and refund aggregation, payment outcome, refund status, and net collected amount |
| `int_invoice_payment_outcomes` | `mart_payment_recovery_daily` | One row per invoice issue date | Daily volumes, collection and recovery rates, refunds, and gross/net EUR totals |
| `stg_customers` | `dim_customers` | One row per customer | Conformed acquisition, geography, and learning-goal context |
| `stg_plans` | `dim_plan_versions` | One row per commercial plan version | Historical price and effective-date context |
| `stg_subscriptions` | `fct_subscriptions` | One row per subscription instance | Trial, conversion, cancellation, and current-state milestones |
| `stg_subscription_events`, `fct_subscriptions` | `fct_subscription_events` | One row per lifecycle event | Customer enrichment and ordered lifecycle transitions |
| `stg_product_events` | `fct_product_events` | One row per product event | Analysis-ready event, session, platform, and content context |

## Modeling boundary

Each current staging model reads one raw source and preserves that source's grain. For example, `stg_payment_attempts` reads `payment_attempts`; it retains `invoice_id` from the attempt row but does not join the invoices table.

Payment attempts are aggregated by invoice and refunds are linked to their successful attempts before either summary joins invoices. This boundary keeps cleaning logic separate from business combinations and prevents one-row-per-invoice amounts from multiplying across payment-attempt or refund rows. `mart_payment_recovery_daily` then aggregates the safe invoice-grain result by invoice issue date. The dimensional layer publishes reusable customer and plan context while facts preserve their declared subscription, lifecycle-event, and product-event grains.

## Reproducibility and security

- The contract, generator, explicit BigQuery schemas, loader, dbt models, tests, and validation SQL are version controlled.
- Generated CSV files are excluded from Git because they are large and reproducible from the fixed seed and tracked generator.
- Local virtual environments, Google credentials, dbt profiles, and cloud tooling are excluded from Git.
- BigQuery datasets use the EU location and contain only fictional synthetic activity.
- Raw data is treated as immutable; governed transformations are created in the separate analytics dataset.

## Validation evidence

- The full generator produced 2,512,863 rows across nine entities using seed `20260827`.
- Local validation passed 11 independent groups with zero errors.
- Warehouse raw validation passed 27 checks.
- The latest full dbt build created 15 models and passed 177 data tests (`PASS=192 WARN=0 ERROR=0 SKIP=0`).
- Independent staging checks confirmed preserved plan, invoice, and refund grains; exact euro conversions; consistent statuses and timestamps; valid invoice periods; positive amounts; successful refund parents; and no over-refunded payments.
- The invoice-grain model retained 128,633 rows and 128,633 distinct invoice IDs, with zero attempt, status, outcome, refund, or net-amount mismatches.
- The daily mart retained all 128,633 invoices across 532 unique invoice dates, with zero daily formula, rate, financial, or cross-layer reconciliation differences.
- The selected payment lineage most recently passed all 44 build operations, followed by ten independent warehouse controls with zero violations.
- Product-event validation passed 13 targeted operations and seven independent warehouse controls with zero violations.

Detailed evidence is available in the raw-load, staging, dimensional-model, fact-review, and payment-recovery review documents in this directory.
