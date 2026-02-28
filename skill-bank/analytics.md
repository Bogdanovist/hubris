# Skill Template: Analytics / Investigation

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific data sources, query tools, and findings storage conventions.

## When to Use

Use this skill for tasks that investigate data, answer questions, or produce analytical findings — as opposed to tasks that produce production code or data assets. Common scenarios:

- Exploratory data analysis ("why did X metric change?")
- Hypothesis testing ("is there a relationship between A and B?")
- Data profiling ("what does the distribution of column C look like?")
- Root cause analysis ("which segment drove the drop in D?")
- Producing a written analysis document as the project deliverable

## Outputs

Analytics tasks produce TWO things:

1. **Findings document** — the analytical deliverable. Append a section for each completed investigation task. Never overwrite previous sections.
2. **Supporting queries/code (when appropriate)** — reproducible SQL or Python that generated the findings. These are committed alongside the findings.

Not every analytics task produces code. Some produce only a findings section (e.g. interpreting results from a previous task's query). That is fine.

## Investigation Process

1. **State the hypothesis or question** from the task's acceptance criteria.
2. **Check source profiles**: Read available data source profiles for schema, join keys, JSON structures, and known quirks that will save significant exploration time.
3. **Write a query or script** to gather evidence. Prefer SQL for data exploration. Use pandas for statistical tests or transformations that SQL cannot express easily.
4. **Run the query/script** and examine results.
5. **Interpret**: What does the data say? Does it confirm or refute the hypothesis? What new questions does it raise?
6. **Record findings** by appending to the findings document (see format below).
7. **Journal discoveries** that should influence subsequent tasks. This is critical — the plan agent uses journal entries to replan, which is how the investigation adapts based on what you find.

## Findings Format

Append to the findings document:

```markdown
### T{ID}: {task title}

**Question**: {the question or hypothesis being investigated}

**Method**: {brief description of approach — what data, what query/analysis}

**Results**:
{key numbers, tables, or observations — be specific and quantitative}

**Interpretation**: {what this means in context of the project's overall question}

**Implications for next steps**: {what should be investigated next, or what this means for the plan}
```

## Acceptance Criteria for Analytics Tasks

Analytics acceptance criteria look different from engineering tasks:

- **Good**: "Determine whether campaign spend correlates with conversion rate by segment. Findings section includes correlation coefficients and a conclusion."
- **Good**: "Identify the top 3 factors contributing to the March sales drop. Each factor supported by quantitative evidence in findings."
- **Bad**: "Analyse the data" (too vague — what question? what constitutes done?)

A task is complete when:
1. The question stated in the acceptance criteria has been answered (or explicitly determined to be unanswerable with available data, with explanation of why).
2. A findings section has been appended to the findings document.
3. Any supporting code is committed.
4. If the findings change the direction of the investigation, a journal entry has been written so the plan agent can adapt.

## When to Journal (Critical for Analytics)

Journal entries are what trigger replanning. For analytics projects, journal MORE than you would for engineering tasks:

- A hypothesis was confirmed or refuted
- The data revealed something unexpected
- A planned approach is not feasible (data quality, missing fields, etc.)
- You identified a new line of investigation not in the current plan
- Quantitative results that subsequent tasks need to reference

The plan agent cannot read the findings document during replanning — it reads the journal. So the journal must contain enough context to replan intelligently.

## Checks

Analytics tasks have lighter verification requirements than engineering tasks:
- If Python code was written: run the linter (style only, no tests required for analysis scripts)
- If SQL was written: verify it parses
- Findings document updated: verify the findings section follows the format above

## Common Pitfalls

- **Never descope a data source without exhaustive exploration.** When a discovery query returns zero results, try alternative table names, row key prefixes, event types, and query patterns before concluding data doesn't exist.
- **Data-driven temporal matching, not hardcoded windows.** Always run a distribution analysis before implementing fuzzy temporal joins. Use proximity-based deduplication (nearest event), not first-match-in-window.

## What NOT to Do

- Do not put analysis SQL in production transformation models (e.g., dbt). Analysis queries go in a separate analysis directory.
- Do not skip the findings document. Even if results are negative or inconclusive, record them.
- Do not skip journaling when findings affect the plan. This is the mechanism that makes investigation iterative.
- Do not fabricate or assume data. If you cannot run a query, mark the task BLOCKED and explain why.
