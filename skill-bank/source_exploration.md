# Skill Template: Source Exploration

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific data sources, profile storage location, and query tools.

## When to Use

Use this skill for tasks that characterise a data source and produce a persistent source profile. This is foundational work — understanding source structure, join keys, JSON payloads, data quality, and quirks — so that future analytics and engineering tasks can consult the profile instead of re-exploring from scratch.

Each task produces ONE profile: either a raw source profile or a staging model profile (not both).

## Outputs

1. **Profile file** in the knowledge/sources directory — the persistent knowledge artefact
2. **Updated INDEX.md** — add or update the entry in the sources index

## Profile Types

### Raw source profile (`{source}__{table}.md`)

Documents the data as it exists in the source system, before any transformation. Use this when profiling a table that hasn't been staged yet, or to document shared characteristics that multiple staging models inherit.

### Staging model profile (`stg_{source}__{entity}.md`)

Documents the agent's interface to the data — the columns, types, join keys, and quirks of the staged view. Use this when a staging model already exists and agents need to understand how to use it.

## Exploration Process

### For raw source profiles

1. **Query metadata**: table schema, column names, types, nullable flags
2. **Sample data**: 10-20 rows to see real values, especially for JSON/complex columns
3. **Characterise volume**: row count, date range, daily volume estimate
4. **Document JSON structures**: for JSON columns, extract distinct keys, document nesting, show example payloads
5. **Identify event types or categories**: if the table contains multiple logical entities, document the filter criteria for each
6. **Note partitioning/clustering**: query information schema if available
7. **List staging models**: identify which `stg_*` models derive from this source and what filter each applies
8. **Record quirks**: anything unexpected — unusual NULL patterns, format inconsistencies, overloaded columns

### For staging model profiles

1. **Read the staging SQL**: understand the filter, renames, and transforms applied to the raw source
2. **Read the schema definition**: capture existing column documentation
3. **Query cardinality**: `count(distinct col)` for key columns (PKs, FKs, categoricals)
4. **Verify join keys**: run a sample join to related staging models, check match rates and confirm key formats align
5. **Document nullability patterns**: which columns are null and under what conditions
6. **Record quirks**: anything that would trip up an agent writing a query against this model

## Profile Formats

### Raw source profile template

```markdown
# Source: {source_name}.{table_name}

## Overview
{One paragraph: what system, how data arrives, what it represents}

## Access
- Database: `{database}`
- Schema: `{schema}`
- Table: `{table}`
- Replication: {method and latency}

## Staging Models
{List each staging model that derives from this source, with the filter criteria it applies}

## Key Columns
| Column | Type | Description |
|--------|------|-------------|
| ... | ... | ... |

## Data Characteristics
- Row count: {approximate}
- Date range: {earliest} to {latest or "present"}
- Daily volume: {approximate}
- Partitioned by: {column and granularity, or "none"}

## Quirks & Known Issues
- {Bullet list of gotchas}

## Discoveries
```

### Staging model profile template

```markdown
# Staging Model: {model_name}

## Overview
{One paragraph: what this model represents, which raw source it derives from}

## Source
- Raw table: `{source}.{table}` — see [{profile_name}.md]({profile_name}.md)
- Filter: `{filter criteria applied in staging SQL}`

## Schema
| Column | Type | Nullable | Description | Example |
|--------|------|----------|-------------|---------|
| ... | ... | ... | ... | ... |

## Join Keys
| This Column | Joins To | Relationship | Notes |
|-------------|----------|--------------|-------|
| ... | ... | ... | ... |

## Cardinality
- {key column}: ~{N} unique values
- ...

## Quirks & Known Issues
- {Bullet list of gotchas specific to this staged view}

## Discoveries
```

## Updating Existing Profiles

When a profile already exists and you are updating it:

1. Read the existing profile and its `## Discoveries` section
2. Integrate confirmed discoveries into the appropriate section (Schema, Join Keys, Quirks, etc.)
3. Remove integrated items from Discoveries
4. Add any new findings from your exploration to the appropriate sections
5. Update INDEX.md description if the scope of the profile has changed

## Sizing

One raw source OR one staging model per task. If a source has 3 staging models, that's 4 tasks total (1 raw + 3 staging). The plan agent should order raw source profiles before their staging model profiles, since staging profiles reference the raw profile.

## Checks

- Profile file exists and follows the template format
- INDEX.md has been updated with the new entry
- Cardinality numbers are based on actual queries, not estimates
- Join keys have been verified with a sample query
- JSON structures are documented from real data samples, not inferred from code
