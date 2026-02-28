# Skill Template: Docker

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's language, base images, and deployment targets.

## When to Use

Use this skill for tasks that create or modify Dockerfiles, docker-compose configurations, or container infrastructure.

## Dockerfile Structure

Use multi-stage builds: build stage (compile/bundle) → runtime stage (minimal base + artifacts only).

## Key Principles

- **Pin base image versions** — never use `:latest`
- **Prefer slim/alpine variants** to minimise size and attack surface
- **Layer caching order**: system packages → dependency manifests → dependency install → source copy → build
- **Run as non-root**: Create a dedicated user, switch with `USER`
- **Use COPY, not ADD** (ADD has implicit behaviours)
- **No secrets in images**: Pass via env vars or mounted secrets at runtime
- **Always include `.dockerignore`**
- **Always include `HEALTHCHECK`**

## Python with uv

For Python projects using [uv](https://docs.astral.sh/uv/) for dependency management, use this multi-stage pattern:

```dockerfile
# Build stage
FROM python:3.x-slim AS builder
WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Copy dependency files
COPY pyproject.toml .
COPY .python-version .

# Install dependencies (no dev deps)
RUN uv sync --no-dev --frozen

# Runtime stage
FROM python:3.x-slim
WORKDIR /app

# Copy venv from builder
COPY --from=builder /app/.venv /app/.venv

# Copy application code
COPY src/ src/

ENV PATH="/app/.venv/bin:$PATH"
```

Key points:
- `COPY --from=ghcr.io/astral-sh/uv:latest` avoids installing uv via pip
- `uv sync --frozen` ensures reproducible installs from lockfile
- Use `--group {name}` to install optional dependency groups
- Virtual environment is copied as a complete artifact to the runtime stage

## Docker Compose

- Service names: lowercase, hyphen-separated
- Use `depends_on` with health check conditions
- Named volumes for persistent data
- Document required env vars with `.env.example`

## Anti-Patterns

- `:latest` tags (breaks reproducibility)
- Single-stage builds for compiled languages
- Running as root
- Storing secrets in `ENV` or `ARG`
- Missing `.dockerignore`
- Dev dependencies in production image
