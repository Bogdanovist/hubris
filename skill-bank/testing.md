# Skill Template: Testing

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's specific framework, conventions, and patterns.

## When to Use

Use this skill when the primary task is creating, modifying, or improving tests.

## Framework Detection

Identify the repo's test framework from config.yaml under `checks.test`. Match existing test file patterns exactly.

## File Organization

Tests mirror the source directory structure. One test file per source file.

## Naming Conventions

Test names describe the scenario, not the implementation:
- `test_login_rejects_expired_token` (good)
- `test_login` (bad)

## Unit Test Structure

Follow Arrange-Act-Assert. One logical assertion per test.

## What to Test

- Happy path: Normal input produces expected output
- Edge cases: Empty inputs, boundary values, zero, negative numbers
- Error handling: Invalid input raises appropriate errors
- Return types/shapes: Correct structure, required fields, proper types

Every new public function needs at minimum one happy-path and one edge-case test.

## What Not to Test

- Private/internal functions (test through public callers)
- Third-party library behaviour
- Language built-ins
- Configuration files (unless they drive runtime behaviour)

## Mocking

Mock external dependencies at the boundary. Never mock the unit under test.

**Do mock**: HTTP clients, database connections, file I/O, time/date, env vars.
**Do not mock**: The function being tested, simple data transforms, pure utilities.

## Test Data

- Use factories or fixtures for reusable test data
- Keep test data minimal — only fields relevant to the test
- Never depend on external data sources
- Use descriptive names: `expired_token`, not `token1`

## dbt Tests

When the repo uses dbt, data model tests are defined in `schema.yml` files alongside the models, not in pytest:

```yaml
models:
  - name: stg_source__entity
    columns:
      - name: primary_key
        data_tests:
          - unique
          - not_null
```

These run via `dbt test`, not pytest. See the SQL/dbt skill for full conventions.

## Common Pitfalls

- **Clean-environment validation is mandatory.** Accumulated dev environments mask missing dependencies. Validation scripts should create a fresh environment on every run (delete existing, create new, install from scratch).
- **Test both dev validation AND production entry points.** Dev scripts that bypass the production runner can mask broken code paths. Both must be validated.

## Anti-Patterns

- Order-dependent tests
- Testing implementation, not behaviour
- Network-dependent unit tests
- Shared mutable state between tests
- Overly broad assertions (`assert result is not None`)
- Commented-out tests (delete them)
