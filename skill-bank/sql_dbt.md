# Skill Template: SQL / dbt

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific warehouse (BigQuery, Snowflake, etc.), source tables, and dbt project structure.

## When to Use

Use this skill for any task that involves creating or modifying dbt models — SQL-based data transformations.

## dbt Layer Conventions

### Staging (`models/staging/`)
- **Purpose**: 1:1 mirror of source tables. Renaming, casting, and basic cleanup only.
- **Naming**: `stg_{source}__{entity}.sql` (e.g. `stg_cloudsql__customers.sql`)
- **Materialisation**: `view`
- **Rules**: No joins, no business logic, no aggregations. Just rename columns to snake_case, cast types, and add a simple `where` to filter deleted records if applicable.

### Intermediate (`models/intermediate/`)
- **Purpose**: Joins, business logic, and enrichment across staging models.
- **Naming**: `int_{description}.sql` (e.g. `int_customer_orders_joined.sql`)
- **Materialisation**: `view`
- **Rules**: Can join multiple staging models, apply business logic, compute derived columns.

### Marts (`models/marts/`)
- **Purpose**: Final analytical tables consumed by downstream (ML models, dashboards, reports).
- **Naming**: `{domain}__{entity}.sql` (e.g. `marketing__campaign_performance.sql`)
- **Materialisation**: `table`
- **Rules**: Wide, denormalised tables optimised for query patterns. Include partitioning and clustering config.

## SQL Style

```sql
with

source as (
    select
        customer_id,
        lower(email) as email,
        created_at,
        updated_at
    from {{ source('cloudsql', 'customers') }}
    where is_deleted = false
),

renamed as (
    select
        customer_id,
        email,
        created_at as created_at_utc,
        updated_at as updated_at_utc
    from source
)

select * from renamed
```

- **Lowercase** keywords: `select`, `from`, `where`, `join`, `on`, `as`, `with`
- **CTEs** over subqueries — every CTE has a descriptive name
- **Explicit column lists** — no `select *` except the final CTE reference
- **Meaningful aliases** — `customers as c` is fine; `t1`, `t2` is not
- **Trailing commas** in column lists
- **One column per line** in select statements

## BigQuery-Specific Patterns

### Partitioning and clustering (marts)
```sql
{{
    config(
        materialized='table',
        partition_by={
            "field": "event_date",
            "data_type": "date",
            "granularity": "day"
        },
        cluster_by=["customer_id", "campaign_id"]
    )
}}
```

### Incremental models
```sql
{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='merge'
    )
}}

select ...
from {{ source('events', 'raw_events') }}
{% if is_incremental() %}
where event_timestamp > (select max(event_timestamp) from {{ this }})
{% endif %}
```

## Schema Files

Every model directory must have a `schema.yml`:

```yaml
version: 2

models:
  - name: stg_cloudsql__customers
    description: "Cleaned customer data from source database"
    columns:
      - name: customer_id
        description: "Primary key"
        data_tests:
          - unique
          - not_null
      - name: email
        description: "Lowercase customer email"
```

## Source Definitions

When creating staging models for an existing source, check source profiles (if available) that document the table's structure, JSON fields, and known quirks.

Define sources in `models/staging/sources.yml`:

```yaml
version: 2

sources:
  - name: source_database
    description: "Operational database"
    tables:
      - name: customers
      - name: orders
```

## Testing

- Every primary key: `unique` + `not_null`
- Enum columns: `accepted_values`
- Foreign keys: `relationships` where applicable
- Business rules: custom data tests in `tests/`
- Run tests: `dbt test`

## Common Pitfalls

- **`dbt parse` is not validation.** Only `dbt run` catches warehouse-specific errors: type coercion functions, JSONPath syntax, UNION ALL type mismatches (`null` infers as INT64 in BigQuery). Never ship models that have only been parsed.
- **JSON-to-STRING**: use `to_json_string()` (BigQuery) or the warehouse-appropriate function, never `cast(... as string)`.
- **JSONPath with special-character keys**: use bracket notation (e.g. `properties['$key']`), not dot notation.

## File Checklist

When creating a new dbt model, always create/update:
1. The `.sql` model file
2. The `schema.yml` in the same directory (add model entry)
3. Source definitions in `sources.yml` (if referencing a new source)
