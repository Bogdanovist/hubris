# Skill Template: Documentation

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's documentation conventions and tooling.

## When to Use

Use this skill when the task is creating or updating documentation.

## Core Principle

Documentation is a deliverable with the same quality bar as code. Broken docs = broken code.

## README Structure

Project name → Quick Start → Prerequisites → Installation → Usage → Configuration → Development → Deployment → Architecture → Contributing.

## Writing Style

- Concise and task-oriented
- Code blocks for all commands (with language tags)
- Tables for reference data (config, env vars, endpoints)
- Active voice, present tense
- Every command must be copy-pasteable and correct

## API Documentation

For each endpoint: method and path, description, request schema, response schema with example, error codes.

## Architecture Documentation

Start with context (what problem, who uses it), component overview, ASCII diagrams, data flow, key decisions with rationale.

## Keeping Docs in Sync

When code changes, check: README, API schemas, config tables, install/build/deploy steps, removed feature references. If behaviour changed and docs didn't, the docs are a bug.

## Anti-Patterns

- Documentation that duplicates code (document intent, not mechanics)
- Aspirational docs (document what exists, not what might)
- Stale screenshots
- Wall of text (use headings, lists, tables, code blocks)
- Undocumented prerequisites
- Broken links
