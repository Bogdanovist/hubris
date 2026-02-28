# Skill Template: CI/CD

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's CI platform, language, and deployment targets.

## When to Use

Use this skill for tasks that create or modify CI/CD pipelines.

## Pipeline Stages

Every pipeline follows this order, each stage passing before the next:
```
lint → test → build → deploy
```

## Key Principles

- **Cache dependencies** using built-in setup action caching
- **Pin all versions** — never use `:latest` for actions or images
- **Use concurrency control** to cancel redundant runs on the same branch
- **Secrets via `${{ secrets.NAME }}`** — never hardcode credentials
- **Production deployments** require manual approval or release triggers
- **Matrix builds** for multi-version/platform testing with `fail-fast: false`

## Deployment Patterns

- **Staging**: Deploy on merge to main
- **Production**: Deploy on release tag with environment protection rules
- **Rollback**: `workflow_dispatch` accepting a version input

## Anti-Patterns

- Tests that don't fail the pipeline
- Deploying without tests (`needs:` the test job)
- Hardcoded credentials
- No caching
- Missing concurrency control
- `:latest` tags in CI
