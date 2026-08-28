#!/usr/bin/env bash

set -euo pipefail

project_id="${GOOGLE_CLOUD_PROJECT:-skillspring-analytics}"
dataset_id="${SKILLSPRING_RAW_DATASET:-skillspring_raw}"
location="${SKILLSPRING_BQ_LOCATION:-EU}"
data_dir="${1:-data/generated/full}"

tables=(
  customers
  plans
  subscriptions
  subscription_events
  invoices
  payment_attempts
  refunds
  product_events
  experiment_assignments
)

for table in "${tables[@]}"; do
  csv_path="${data_dir}/${table}.csv"
  schema_path="data/schemas/${table}.json"
  if [[ ! -f "${csv_path}" ]]; then
    echo "Missing generated file: ${csv_path}" >&2
    exit 1
  fi
  if [[ ! -f "${schema_path}" ]]; then
    echo "Missing schema file: ${schema_path}" >&2
    exit 1
  fi

  if [[ "${SKILLSPRING_REPLACE_RAW:-false}" == "true" ]]; then
    bq --project_id="${project_id}" --location="${location}" load \
      --replace \
      --source_format=CSV \
      --skip_leading_rows=1 \
      --field_delimiter="," \
      --encoding=UTF-8 \
      --max_bad_records=0 \
      "${project_id}:${dataset_id}.${table}" \
      "${csv_path}" \
      "${schema_path}"
  else
    bq --project_id="${project_id}" --location="${location}" load \
      --source_format=CSV \
      --skip_leading_rows=1 \
      --field_delimiter="," \
      --encoding=UTF-8 \
      --max_bad_records=0 \
      "${project_id}:${dataset_id}.${table}" \
      "${csv_path}" \
      "${schema_path}"
  fi
done

echo "Loaded ${#tables[@]} raw tables into ${project_id}:${dataset_id} in ${location}."
