# Career-focused customer analysis

Originally executed on 2026-10-17 and revalidated against full BigQuery data on 2026-11-10. Synthetic reporting cutoff: 2026-06-30.

Metric: customers with at least one currently active subscription divided by all customers in the segment, including customers without a subscription. This is active customer penetration, not conversion, retention, churn, or application usage. Subscriptions are aggregated by customer before joining.

## Learning Goal

| Segment | Customers | Active customers | Active rate |
|---|---:|---:|---:|
| career | 17,695 | 6,327 | 35.76% |
| language | 13,924 | 4,981 | 35.77% |
| academic | 10,016 | 3,499 | 34.93% |
| personal | 8,365 | 2,894 | 34.6% |

## Career Country

| Segment | Customers | Active customers | Active rate |
|---|---:|---:|---:|
| DE | 3,838 | 1,385 | 36.09% |
| FR | 2,514 | 901 | 35.84% |
| FI | 2,308 | 806 | 34.92% |
| IT | 2,148 | 775 | 36.08% |
| ES | 2,108 | 768 | 36.43% |
| SE | 1,775 | 626 | 35.27% |
| NL | 1,766 | 618 | 34.99% |
| IE | 1,238 | 448 | 36.19% |

## Career Channel

| Segment | Customers | Active customers | Active rate |
|---|---:|---:|---:|
| organic_search | 4,182 | 1,591 | 38.04% |
| paid_search | 3,899 | 1,321 | 33.88% |
| paid_social | 3,180 | 1,027 | 32.3% |
| referral | 2,470 | 1,006 | 40.73% |
| direct | 2,176 | 776 | 35.66% |
| affiliate | 1,788 | 606 | 33.89% |

## Findings and anomaly assessment

- Career represents 17,695 of 50,000 customers (35.39%); 6,327 are active (35.76%), versus 35.40% overall. Learning-goal rates are close (34.60%–35.77%); no conspicuous descriptive outlier at this level.
- Within career, referral is 40.73% active and paid social is 32.30%, a gap of 8.43 percentage points. Flag for investigation, not a confirmed anomaly or causal effect. Organic search is also relatively high at 38.04%.
- Career country rates span 34.92% (FI) to 36.43% (ES), a relatively narrow 1.51-point range. Counts primarily reflect segment size; Germany's largest count alone is not evidence of superior performance.
- Generator inspection shows learning goals sampled with configured weights of 35/28/20/17. The observed career share is consistent with that design. These are synthetic patterns, not discoveries about actual customers.
- Check signup cohort and country mix before interpreting channel differences. Active status depends on subscription age and lifecycle. No cohort adjustment, formal anomaly threshold, or significance test was applied; no causal claim is supported.

## Verification

All goal groups sum to 50,000 customers and 17,701 active customers, matching independent warehouse totals. Career country and channel groups each reconcile to 17,695 customers and 6,327 active customers. No duplicate/NULL customer keys, invalid goals, unmatched subscription customers, or missing career country/channel values were found. Active customers and active subscriptions both equal 17,701 in this dataset; the query does not assume they must always be equal.

The reformatted published SQL and its validation query were rerun on 2026-11-10. They reproduced all segment counts and rates, with 50,000 customer rows and zero duplicate or NULL customer keys, invalid learning goals, unmatched subscription customers, or missing career country/channel values.

SQL: `sql/analysis/career_customer_analysis.sql`. Controls: `sql/validation/career_customer_analysis_validation.sql`.
