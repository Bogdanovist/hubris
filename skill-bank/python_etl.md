# Skill Template: Python ETL

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific data sources, destination warehouse, and connection libraries.

## When to Use

Use this skill for tasks that involve extracting data from operational databases (e.g., Postgres, MySQL, BigTable) and loading it into a data warehouse (e.g., BigQuery, Snowflake). These are Python scripts that bridge external data sources into the warehouse where transformation tools (dbt, etc.) can process them.

## File Location

All ETL code goes in a dedicated directory (e.g., `{project}/etl/`):
- One module per data source. Do not combine sources in a single file.
- Shared utilities (retry logic, logging, warehouse loading) in their own modules.

## Extraction Pattern

Each source table gets its own extraction function:

```python
import logging
import pandas as pd

logger = logging.getLogger(__name__)


def extract_customers(connection) -> pd.DataFrame:
    """Extract customer records from the source database."""
    query = "SELECT customer_id, email, created_at, updated_at FROM customers WHERE is_deleted = false"
    df = pd.read_sql(query, connection)
    logger.info("Extracted %d customer records", len(df))
    return df
```

## Loading Pattern

Use a shared utility for warehouse writes:

```python
def load_dataframe(
    df: pd.DataFrame,
    table_id: str,
    write_disposition: str = "WRITE_TRUNCATE",
) -> None:
    """Load a DataFrame into the destination warehouse."""
    client = create_warehouse_client()
    # Configure and execute the load job
    ...
    logger.info("Loaded %d rows to %s", len(df), table_id)
```

## Error Handling

Use exponential backoff for transient errors:

```python
import time

def retry_with_backoff(fn, max_retries=3, base_delay=1.0):
    """Retry a function with exponential backoff."""
    for attempt in range(max_retries):
        try:
            return fn()
        except Exception as e:
            if attempt == max_retries - 1:
                raise
            delay = base_delay * (2 ** attempt)
            logger.warning("Attempt %d failed: %s. Retrying in %.1fs", attempt + 1, e, delay)
            time.sleep(delay)
```

## Configuration

All connection details come from environment variables. Never hardcode connection details.

```python
import os

source_host = os.environ["SOURCE_DB_HOST"]
source_user = os.environ["SOURCE_DB_USER"]
source_password = os.environ["SOURCE_DB_PASSWORD"]
```

## Logging

Use Python's `logging` module:

```python
import logging
logger = logging.getLogger(__name__)
```

At the entry point, configure structured JSON logging for production:

```python
import json
import logging

class JsonFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        })
```

## Common Pitfalls

- **PEP 735 vs optional-dependencies**: `pip install -e ".[extra]"` reads `[project.optional-dependencies]`, NOT `[dependency-groups]`. Wrong section causes silent failure.
- **`python -m module` double-loading**: the file loads as both `__main__` and the canonical module, creating separate state. Fix: read shared state from `sys.modules.get("canonical.module.name")` in `main()`.

## Testing

- Mock all database/warehouse clients with `unittest.mock`
- Test extraction functions return expected DataFrame shapes
- Test loading functions call the warehouse client correctly
- Test retry logic with simulated failures
