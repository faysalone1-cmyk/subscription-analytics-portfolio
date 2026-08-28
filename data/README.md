# Synthetic Source Data

The SkillSpring source data is generated locally from the approved contract in `docs/source-data-contract.md`. Generated CSV files and their manifest are written to `data/generated/` and are ignored by Git. Explicit BigQuery schemas in `data/schemas/` are version controlled.

From the repository root, create a small validation dataset:

```bash
python3 scripts/generate_synthetic_data.py --customers 500 --output-dir data/generated/smoke
```

Create the full approved dataset:

```bash
python3 scripts/generate_synthetic_data.py --customers 50000 --output-dir data/generated/full
```

The generator uses a fixed default seed of `20260827`. Its manifest records row counts and SHA-256 checksums so reproducibility can be verified without committing the generated data.

Validate a completed generation independently:

```bash
python3 scripts/validate_generated_data.py --data-dir data/generated/full
```

After configuring the local Google Cloud environment documented in the repository README, load the validated files with explicit schemas:

```bash
bash scripts/load_bigquery_raw.sh data/generated/full
```

The loader creates tables by default and does not silently replace an existing raw table. An intentional regeneration can opt into exact-table replacement with `SKILLSPRING_REPLACE_RAW=true` after the existing targets have been reviewed.
