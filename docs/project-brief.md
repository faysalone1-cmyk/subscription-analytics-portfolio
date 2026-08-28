# Subscription Analytics Portfolio Project Brief

Status: Approved — Week 1 Day 1, 2026-08-26

## Product

Product name: SkillSpring

SkillSpring is a fictional consumer learning app offering a free trial followed by monthly or annual paid subscriptions. Customers complete guided learning programs, and the product records acquisition, onboarding, learning activity, subscription changes, payment attempts, and refunds.

## Primary business decision

Decide which onboarding or payment experience should be improved first to increase trial-to-paid conversion and 90-day customer retention without increasing refunds.

## Stakeholder decisions

Approved by Faisal on 2026-08-26.

1. Head of Product: which onboarding behavior or point of friction should the product team improve first?
2. Head of Growth: which acquisition segments produce retained paying customers rather than only trial sign-ups?
3. Finance lead: which subscription or payment failure patterns put recurring revenue at risk?

## Core analytical questions

Approved by Faisal on 2026-08-26.

1. Which acquisition channels and customer segments generate the strongest trial-to-paid conversion and 90-day retention?
2. Which onboarding and early-product behaviors are most associated with becoming a paying subscriber?
3. How does monthly recurring revenue change through new, expansion, contraction, reactivation, and churned revenue?
4. How much involuntary churn is associated with failed payments, and where do refunds concentrate?
5. How do retention and customer value vary by signup cohort, plan, billing interval, region, and acquisition channel?

## Initial dataset boundary

Approved by Faisal on 2026-08-26.

- Synthetic, documented customer activity suitable for public portfolio use.
- Activity period: 2025-01-01 through 2026-06-30.
- Reporting currency: EUR.
- Ninety-day retention includes only customers with a complete 90-day observation window as of the reporting cutoff.

### Canonical raw entities

Approved by Faisal on 2026-08-26. Each stated grain defines exactly what a single row represents.

| Entity | Working grain | Purpose |
|---|---|---|
| Customers | One row per customer | Signup date, region, and acquisition attributes |
| Plans | One row per plan version | Product tier, billing interval, and price |
| Subscriptions | One row per subscription | Subscription start, trial dates, customer, and current state |
| Subscription events | One row per subscription state or plan change | Activation, upgrade, downgrade, reactivation, cancellation, and other lifecycle history |
| Invoices | One row per amount billed to a subscription | Billing period, amount due, due date, and final collection state |
| Payment attempts | One row per collection attempt against an invoice | Attempt number, timestamp, success/failure status, failure reason, and recovery attempts |
| Refunds | One row per refund | Refunded amount, date, and reason |
| Product events | One row per customer event | Onboarding and learning-product behavior |
| Experiment assignments | One row per customer per experiment | Treatment assignment used in the Week 6 experiment |

## Scope exclusions

Approved by Faisal on 2026-08-26.

- Real personally identifiable customer data.
- Production payment processing or movement of real money.
- Full revenue-recognition accounting under IFRS or GAAP. MRR and ARR will be labelled as operational subscription metrics rather than statutory revenue, and important totals will be reconciled with invoice and payment data.
- Multi-currency foreign-exchange remeasurement in the first version.
- Machine-learning prediction as a substitute for the planned descriptive, diagnostic, and experimental analysis.
- A second unrelated dataset, dashboard, or case study.

## Seven-week deliverable chain

Approved by Faisal on 2026-08-26.

1. Week 1: repository, project contract, dbt/BigQuery setup, sources, and initial staging lineage.
2. Week 2: staging, intermediate, and mart models with tests and dbt documentation.
3. Week 3: dimensional customer, subscription, payment, and product-event model with explicit grains.
4. Week 4: governed revenue, conversion, churn, cohort, and retention metrics plus reconciliation.
5. Week 5: Python investigation and independent validation of warehouse metrics.
6. Week 6: experiment design and analysis targeting a selected onboarding or payment intervention.
7. Week 7: dashboard, metric-movement investigation, case study, CV bullets, and interview stories.

## Day 1 approval checklist

- [x] Product and working name approved by Faisal on 2026-08-26.
- [x] Primary business decision approved by Faisal on 2026-08-26.
- [x] Three stakeholder decisions approved by Faisal on 2026-08-26.
- [x] Five analytical questions approved by Faisal on 2026-08-26.
- [x] Dataset duration, synthetic-data approach, reporting currency, and retention observation rule approved by Faisal on 2026-08-26.
- [x] Initial raw entities and grains approved by Faisal on 2026-08-26.
- [x] Scope exclusions approved by Faisal on 2026-08-26.
- [x] Seven-week deliverable chain approved by Faisal on 2026-08-26.
