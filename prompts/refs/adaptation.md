# Adaptation Reference

This reference describes how the team lead adjusts sprint execution based on observed signals.

## Signal Sources

### 1. Initial Hints (from project init)

When a project is created, the user may indicate:
- Project type (feature, product build, refactor, migration)
- Estimated size (small, medium, large)
- Repo characteristics (language, framework, test coverage)

These provide starting parameters but should be overridden by observed data.

### 2. Observed Complexity (from codebase analysis)

At sprint planning, assess:
- Dependency depth in backlog items (deeply coupled vs independent)
- Codebase size and test coverage
- Number of files typically touched per task
- How many backlog items are independent (parallelisable)

### 3. Sprint Outcomes (learned over time)

After each sprint, consider:
- Did the sprint complete cleanly or were there issues?
- How much feedback did the user give? (heavy feedback → smaller milestones)
- Were there test failures or regressions?
- Did any tasks need collaborative mode?
- How long did the sprint take relative to the milestone size?

## Adaptation Parameters

Stored in `projects/{name}/state.yaml`:

```yaml
adaptation:
  parallelism: 2              # Max concurrent implementers (1-4)
  collaborative_threshold: 2  # Failed attempts before collaborative mode
  prefer_interactive: false   # Whether to recommend interactive sessions
```

### Parallelism

- Start at 2 (safe default)
- Increase to 3-4 if sprints complete cleanly with independent tasks
- Decrease to 1 if tasks are tightly coupled or sprints have integration issues
- Never exceed 4 (diminishing returns, coordination overhead)

### Collaborative Threshold

- Start at 2 (try twice before escalating)
- Lower to 1 if collaborative mode consistently resolves issues faster
- Raise to 3 if most issues resolve on second attempt

### Mode Recommendation

The team lead should recommend interactive session mode when:
- A task involves UI/design iteration
- The same task has failed in a previous sprint
- The approach is uncertain and would benefit from rapid feedback
- The user has expressed preference for interactive work on similar tasks

## Global Adaptation

Stored in `improvements/adaptation.yaml`:

```yaml
# Learned across all projects
defaults:
  parallelism: 2
  collaborative_threshold: 2

# Per-repo-type adjustments
repo_types:
  web_app:
    prefer_interactive_for_ui: true
  native:
    parallelism: 1  # Native builds are often sequential
```

The auto-retro system proposes updates to global adaptation based on cross-project patterns. User approves before changes take effect.

## How the Team Lead Uses This

At sprint planning:
1. Read `adaptation` from project state
2. Read global defaults from `improvements/adaptation.yaml` (if exists)
3. Assess the current sprint's tasks against these parameters
4. Adjust if the data suggests (document the adjustment in the sprint plan)

At sprint completion:
1. Reflect on whether the parameters were appropriate
2. Recommend adjustments in the sprint journal
3. Update project `state.yaml` if confident in the change
