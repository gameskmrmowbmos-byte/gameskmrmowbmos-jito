# Backend architecture

## Request lifecycle

1. Helmet adds security headers.
2. CORS checks the exact configured origin.
3. Express enforces small JSON/form body limits.
4. Cookie parsing and Mongo/operator-key sanitization run.
5. Morgan sends request logs to Winston.
6. Global and endpoint-specific rate limits run.
7. Route validators normalize and validate inputs.
8. Authentication and role middleware authorize the request.
9. Controllers call models/services and return a consistent envelope.
10. Central error middleware sanitizes operational and production errors.

## Layers

| Layer | Responsibility |
|---|---|
| `config` | Environment and database setup |
| `models` | Mongoose schemas, indexes, and model methods |
| `validators` | Request-level rules and normalization |
| `middleware` | Authentication, roles, limits, sanitation, errors |
| `services` | Tokens, auth policy, reports, email, audit, edit policy |
| `controllers` | Use cases and response mapping |
| `routes` | HTTP contract and access requirements |
| `utils` | Errors, responses, pagination, CSV, logging |

## Data access rules

- Admin queries can access all records.
- Operator entry queries always include `createdBy = authenticated user`.
- Operator result queries require published status and assigned market.
- Operators see only assigned active markets.
- Market assignment and active status are rechecked on entry creation/update.
- Published results are locked by controller policy.

## Error handling

Operational errors use `ApiError`. Mongoose validation, duplicate-key, and cast
errors are normalized. Production 500 responses never include internal stack
traces. Logs retain enough request context for server operators without logging
passwords, raw JWTs, database credentials, or SMTP secrets.

## Graceful shutdown

`server.js` handles SIGINT and SIGTERM, stops accepting HTTP connections,
disconnects Mongoose, and exits. Startup exits non-zero if MongoDB is
unavailable.

