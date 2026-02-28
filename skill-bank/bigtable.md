# Skill Template: BigTable

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific BigTable instances, row key designs, and column families.

## When to Use

Use this skill for tasks that involve extracting data from Google Cloud BigTable. BigTable is a high-throughput, low-latency NoSQL database optimized for time-series and event data.

## Production Safety Warnings

**CRITICAL**: BigTable instances often serve live production systems. All extraction code must follow these safety rules:

1. **Never perform full table scans** — always use row key prefixes, filters, or explicit row ranges
2. **Always use `limit=` parameter** during development and testing
3. **Always use `CellsColumnLimitFilter(1)`** to read only the latest cell version (unless historical versions are explicitly needed)
4. **Use server-side filters** (RowFilterChain, TimestampRange) to minimize data transfer
5. **Test queries with small limits first** (e.g., `limit=5`) before scaling up
6. **Use non-admin client** (`bigtable.Client(admin=False)`) — admin clients can modify tables

Violating these rules can impact production systems serving live users.

## Correct API Patterns

### Row Key Prefix Scans

**CORRECT** — Use `RowSet.add_row_range_with_prefix()`:

```python
from google.cloud import bigtable
from google.cloud.bigtable.row_set import RowSet

client = bigtable.Client(project=project_id, admin=False)
instance = client.instance(instance_id)
table = instance.table(table_id)

# Build row set with prefix filter
row_set = RowSet()
row_set.add_row_range_with_prefix("my_prefix")

# Read rows
rows = table.read_rows(row_set=row_set, limit=10)
```

**INCORRECT** — Do NOT use `RowKeyRegexFilter` for simple prefix matching:

```python
# ANTI-PATTERN: This does NOT work reliably for prefix matching
from google.cloud.bigtable.row_filters import RowKeyRegexFilter

filter_ = RowKeyRegexFilter(b'^my_prefix')  # DO NOT USE
rows = table.read_rows(filter_=filter_)
```

**Why this fails**: `RowKeyRegexFilter` does not reliably match even simple prefix patterns. Use `RowSet.add_row_range_with_prefix()` instead.

### Safety Filters

Always apply `CellsColumnLimitFilter` to limit cell versions:

```python
from google.cloud.bigtable.row_filters import CellsColumnLimitFilter

# Only read latest cell version (most common case)
filter_ = CellsColumnLimitFilter(1)

rows = table.read_rows(row_set=row_set, filter_=filter_, limit=100)
```

### Timestamp-Based Filtering

For incremental extraction or time-range queries, use `TimestampRange` filters:

```python
from google.cloud.bigtable.row_filters import TimestampRange, RowFilterChain
from datetime import datetime, timedelta, timezone

# Extract cells modified in the last 7 days
since = datetime.now(timezone.utc) - timedelta(days=7)
since_micros = int(since.timestamp() * 1_000_000)

# TimestampRange is inclusive start, exclusive end
timestamp_filter = TimestampRange(start=since_micros)

# Combine with cell limit filter
filter_chain = RowFilterChain([
    timestamp_filter,
    CellsColumnLimitFilter(1)
])

rows = table.read_rows(row_set=row_set, filter_=filter_chain)
```

**Important**: BigTable timestamps are in **microseconds since epoch**, not seconds. Always multiply by 1,000,000 when converting from Python datetime.

### Combining Filters

Use `RowFilterChain` for AND logic. Use `RowFilterUnion` for OR logic (less common).

## Row Key Design Implications

BigTable row keys determine query efficiency:

1. **Row keys are sorted lexicographically** — scanning is efficient when row keys are grouped by query pattern
2. **Prefix scans are efficient** — use `RowSet.add_row_range_with_prefix()` when row keys have logical prefixes
3. **Row keys are NOT chronologically sorted (unless designed that way)** — if your row key starts with a UUID or random string, you cannot efficiently filter by date using row key alone. Use `TimestampRange` filters on cell timestamps instead.

## Incremental Extraction Pattern

For incremental ETL, track the max BigTable cell timestamp and use it as the `since` parameter:

```python
def extract_data(
    project_id: str,
    instance_id: str,
    table_id: str,
    since: datetime | None = None,
) -> pd.DataFrame:
    """Extract data incrementally from BigTable.

    Args:
        since: If provided, only extract cells newer than this timestamp.
               If None, perform initial load (e.g., last 90 days).
    """
    row_set = RowSet()
    row_set.add_row_range_with_prefix("my_prefix")

    if since is None:
        lookback_start = datetime.now(timezone.utc) - timedelta(days=90)
        since_micros = int(lookback_start.timestamp() * 1_000_000)
    else:
        since_micros = int(since.timestamp() * 1_000_000)

    filter_chain = RowFilterChain([
        TimestampRange(start=since_micros),
        CellsColumnLimitFilter(1)
    ])

    rows = table.read_rows(row_set=row_set, filter_=filter_chain)
    # Parse rows into DataFrame ...
```

## Parsing BigTable Rows

BigTable is **sparse** — not all rows have all columns. Always handle missing cells:

```python
def parse_row(row) -> dict:
    """Parse a BigTable row into a dict, handling sparse columns."""
    data = {}
    data['row_key'] = row.row_key.decode('utf-8')

    # Read cells from column families — use .get() to handle missing columns
    family = row.cells.get('column_family', {})

    # Extract values (cells are lists, take first element)
    data['field_a'] = family.get('field_a', [None])[0]
    data['field_b'] = family.get('field_b', [None])[0]

    # Decode bytes to strings
    for key in ['field_a', 'field_b']:
        if data[key] is not None and isinstance(data[key], bytes):
            data[key] = data[key].value.decode('utf-8')

    return data
```

## Error Handling

BigTable operations can fail due to transient network errors. Use retry logic:

```python
from tenacity import retry, stop_after_attempt, wait_exponential
from google.cloud.exceptions import GoogleCloudError

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10),
    retry=retry_if_exception_type(GoogleCloudError)
)
def extract_with_retry(table, row_set, filter_):
    """Extract rows with exponential backoff retry."""
    rows = table.read_rows(row_set=row_set, filter_=filter_)
    return list(rows)
```

## Configuration

Never hardcode BigTable connection details:

```python
import os

project_id = os.environ["BIGTABLE_PROJECT"]
instance_id = os.environ["BIGTABLE_INSTANCE"]
table_id = os.environ["BIGTABLE_TABLE"]
```

## Testing

When writing unit tests for BigTable extraction:

1. **Mock the BigTable client** — do not make real API calls in tests
2. **Test row parsing logic** — verify handling of missing columns, byte decoding, malformed row keys
3. **Test filter construction** — verify filters are built correctly for incremental vs. initial loads
4. **Verify safety constraints** — ensure `CellsColumnLimitFilter(1)` is always applied, prefix filters are used

## Common Mistakes

1. **Using `RowKeyRegexFilter` for prefix matching** — Use `RowSet.add_row_range_with_prefix()` instead
2. **Forgetting `CellsColumnLimitFilter(1)`** — Without this, you may read historical cell versions, multiplying your data volume
3. **Not testing with `limit=` first** — Always test with small limits before scaling up production queries
4. **Treating BigTable like SQL** — BigTable is a sparse, wide-column store. Not all rows have all columns. Always handle missing cells gracefully.
5. **Using seconds instead of microseconds for timestamps** — BigTable uses microsecond precision. Multiply by 1,000,000 when converting from Python datetime.
6. **Assuming row keys are chronologically sorted** — Unless your row key design explicitly starts with a timestamp, row keys are NOT in date order. Use `TimestampRange` filters on cell timestamps for date-based filtering.

## File Checklist

When creating BigTable extraction code:
1. Add module-level safety warning docstring
2. Use `RowSet.add_row_range_with_prefix()` for prefix scans
3. Always apply `CellsColumnLimitFilter(1)`
4. Add timestamp filtering for incremental extraction
5. Handle sparse columns (missing cells) gracefully
6. Use environment variables for connection config
7. Add retry logic for transient errors
8. Write unit tests with mocked BigTable client
