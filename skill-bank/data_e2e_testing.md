# Skill Template: Data End-to-End Testing

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific data sources, query clients, and pipeline structure.

## When to Use

Use this skill when validating that a data processing pipeline works correctly against real data. Common scenarios:

- ETL pipeline produces correct output after code changes
- A model chain yields expected results from real source tables
- A new pipeline is ready for its first full validation
- A bug fix needs confirmation against production-like data

This is NOT for unit testing (use the `testing` skill — mocked, fast, CI-friendly) or analytics investigation (use the `analytics` skill — answering questions, not validating code). End-to-end tests bridge the gap: they run real data through real code to confirm the system works as a whole.

## Principles

1. **Real data, real sources.** Query from databases directly. No mocks, no synthetic fixtures. The point is to validate against the mess of real-world data.
2. **Sample to keep costs and runtime low.** Full table scans are unnecessary. A well-chosen sample of hundreds to low thousands of rows is enough.
3. **Representative samples, not arbitrary limits.** `LIMIT 100` grabs whatever the query engine returns first — usually the most common, least interesting rows. Build samples that stress-test processing by covering the variety in the data.
4. **Fewer, broader scripts.** Each script should validate an end-to-end flow, not a single function. Prefer 2-4 scripts that cover a pipeline's full path over 15 scripts testing individual steps.

## File Location

End-to-end tests live separately from unit tests:

```
tests/e2e/
├── test_e2e_pipeline_a.py
├── test_e2e_pipeline_b.py
└── ...
```

Name files `test_e2e_{pipeline_or_flow}.py`. These scripts are not run by default test commands — they are run explicitly when needed.

## Building Representative Samples

The hardest part of e2e testing is choosing a good sample. A bad sample gives false confidence. Think about what varies in the data and make sure the sample covers it.

### Strategy: Stratified Sampling

Pick rows that cover the meaningful categories in the data. If a pipeline processes messages, the sample should include every status, multiple types, and a spread of timestamps — not just the 100 most recent rows.

```sql
WITH ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY status, category
            ORDER BY FARM_FINGERPRINT(CAST(id AS STRING))
        ) AS rn
    FROM source_table
    WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 90 DAY)
)
SELECT * EXCEPT(rn)
FROM ranked
WHERE rn <= 20
```

### What Makes a Good Sample

- **Covers every value of categorical columns** that affect processing logic (status, type, category). Use `PARTITION BY` to ensure each group is represented.
- **Includes edge cases**: rows where optional fields are NULL, timestamps at boundaries, string fields with special characters.
- **Spans time**: not just the latest rows. Include data from different periods if the pipeline handles time-dependent logic.
- **Uses deterministic ordering**: hash-based ordering produces a stable, pseudo-random selection — better than `ORDER BY RAND()` (changes every run) or `ORDER BY created_at` (biased).
- **Stays small**: hundreds to low thousands of rows total. If a pipeline has 5 categories x 3 statuses, 20 rows per partition gives 300 rows — plenty.

### What Makes a Bad Sample

- `LIMIT 100` — biased toward whatever the engine returns first
- `WHERE id IN (1, 2, 3, 4, 5)` — hardcoded IDs that may not exist next month
- `ORDER BY created_at DESC LIMIT 50` — only tests the newest, most common data
- The entire table — expensive, slow, defeats the purpose of sampling

## Script Structure

Each e2e test script follows this pattern:

```python
"""End-to-end test for the {pipeline_name} pipeline.

Validates: extraction → transformation → load.
Run with: python tests/e2e/test_e2e_{pipeline_name}.py
"""
import logging
import sys

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def get_sample(client) -> list[dict]:
    """Query a representative sample from the source data."""
    query = """..."""
    df = client.query(query).to_dataframe()
    logger.info("Sample: %d rows covering %d categories", len(df), df["category"].nunique())
    return df


def run_pipeline(sample_df):
    """Run the pipeline over the sample data."""
    # Call the actual pipeline functions with real data
    ...


def validate_output(client, expected_count: int):
    """Check the pipeline output against expectations."""
    failures = []

    # Row count
    result = client.query("SELECT COUNT(*) AS n FROM output_table").to_dataframe()
    actual = result["n"].iloc[0]
    if actual != expected_count:
        failures.append(f"Row count: expected {expected_count}, got {actual}")

    # Schema check
    actual_columns = get_output_columns(client)
    required = {"id", "category", "status", "created_at"}
    missing = required - actual_columns
    if missing:
        failures.append(f"Missing columns: {missing}")

    # Null check on required fields
    for col in ["id", "category"]:
        null_count = count_nulls(client, col)
        if null_count > 0:
            failures.append(f"Unexpected nulls in {col}: {null_count}")

    return failures


def main():
    client = create_client()

    logger.info("=== Querying sample ===")
    sample_df = get_sample(client)

    logger.info("=== Running pipeline ===")
    run_pipeline(sample_df)

    logger.info("=== Validating output ===")
    failures = validate_output(client, expected_count=len(sample_df))

    if failures:
        logger.error("FAILED — %d issues:", len(failures))
        for f in failures:
            logger.error("  - %s", f)
        sys.exit(1)
    else:
        logger.info("PASSED — all checks OK")


if __name__ == "__main__":
    main()
```

### Key Points

- **`if __name__ == "__main__"`**: scripts are run directly, not via pytest discovery.
- **Logging, not print**: structured output that shows what the test is doing at each step.
- **Clear pass/fail**: exit code 0 on success, 1 on failure. Failures are logged with specifics.
- **Composable sections**: `get_sample`, `run_pipeline`, `validate_output` keep the script readable.

## What to Validate

| Check | Why |
|-------|-----|
| Row counts match expectations | Rows aren't silently dropped or duplicated |
| Output schema has required columns | Transforms didn't break column structure |
| Required fields have no unexpected NULLs | Joins and transformations preserved data |
| Value ranges are plausible | No corrupted casts or overflows |
| Referential integrity between outputs | Related tables stay consistent |
| Idempotency: re-running produces same result | Pipeline is safe to retry |

Do not validate things that unit tests already cover (e.g. individual function return values, error handling branches).

## Cleanup

If the test creates temporary tables or writes to test-specific outputs, clean up after:

```python
def cleanup(client, table_ids: list[str]):
    """Delete temporary tables created during testing."""
    for table_id in table_ids:
        client.delete_table(table_id, not_found_ok=True)
        logger.info("Cleaned up %s", table_id)
```

Prefer writing to a test-specific dataset or table suffix (e.g. `output_table_e2e_test`) rather than writing to production tables.

## What NOT to Do

- **Do not use `LIMIT N` for sampling.** It produces biased, unrepresentative data. Use stratified sampling.
- **Do not mock data sources.** That defeats the purpose. If you need mocks, write a unit test instead.
- **Do not write one script per function.** E2e tests validate flows, not units. A script should cover extract -> transform -> load, not just "test extract returns a DataFrame".
- **Do not hardcode specific row IDs.** Data changes over time. Use queries that select by characteristics (status, type, date range), not by primary key.
- **Do not write to production output tables.** Use a test-specific suffix or dataset to avoid polluting real data.
- **Do not skip cleanup.** Temporary tables left behind accumulate cost and confusion.
