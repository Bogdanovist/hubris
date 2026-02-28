# Skill Template: API Development

> **This is a skill bank template.** It is never loaded directly by agents during execution.
> To use: reconcile into a repo's `.ai/skills/` directory during project init or sprint planning.
> Adapt to the repo's framework, auth system, and API conventions.

## When to Use

Use this skill for tasks that create or modify HTTP endpoints, REST APIs, GraphQL resolvers, or RPC services.

## Route Design

Follow RESTful conventions: plural nouns, kebab-case, version prefix (`/api/v1/`), nest only one level deep. Use query parameters for filtering, sorting, and pagination.

## Request Validation

Validate all input at the API boundary. Never trust client data. Return 400 with field-level errors on validation failure.

## Error Handling

Consistent error response format across all endpoints:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request validation failed",
    "details": [{"field": "email", "message": "Invalid email format"}]
  }
}
```

Map errors to appropriate HTTP status codes (400, 401, 403, 404, 409, 422, 429, 500). Never expose stack traces or internal details.

## Authentication & Authorisation

Implement as middleware. Extract tokens from `Authorization` header. Validate on every request. Return 401 for missing/invalid credentials, 403 for insufficient permissions.

## Pagination

Every list endpoint must support pagination. Prefer cursor-based for large/changing datasets, offset-based for simpler cases. Always include pagination metadata.

## Testing

Integration tests for every endpoint covering: happy path, validation errors (400), auth errors (401/403), not-found (404), and edge cases.

## Anti-Patterns

- Inconsistent response format
- Exposing internal errors
- Missing validation
- Business logic in route handlers
- Unpaginated list endpoints
- Auth checks duplicated in each handler instead of middleware
