# API documentation

Base URL: `http://localhost:5002/api`

Except for health and authentication entry points, send:

```http
Authorization: Bearer ACCESS_TOKEN
Content-Type: application/json
```

Web clients also send `X-Client-Platform: web`; native clients send `native`.

## Response envelope

```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {},
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 100,
    "totalPages": 5
  }
}
```

Validation error:

```json
{
  "success": false,
  "message": "Validation failed",
  "errors": [
    { "field": "email", "message": "Valid email is required" }
  ]
}
```

## Health

| Method | Path | Access |
|---|---|---|
| GET | `/health` | Public |

## Authentication

| Method | Path | Access | Body |
|---|---|---|---|
| POST | `/auth/login` | Public | `identifier`, `password` |
| POST | `/auth/refresh` | Public | Native `refreshToken`; web cookie |
| POST | `/auth/logout` | Public | Optional `refreshToken` |
| POST | `/auth/forgot-password` | Public | `email` |
| POST | `/auth/reset-password` | Public | `token`, strong `password` |
| POST | `/auth/change-password` | Authenticated | `currentPassword`, `password` |
| GET | `/auth/me` | Authenticated | — |

A strong password has 10–128 characters and includes uppercase, lowercase,
number, and special characters.

## Dashboard

| Method | Path | Access |
|---|---|---|
| GET | `/dashboard/summary?date=YYYY-MM-DD` | Authenticated |

Returns market counts, today's record/demo-point counts, recent entries, recent
published results, and an admin-only operator count.

## Users

All user endpoints require administrator role.

| Method | Path | Purpose |
|---|---|---|
| GET | `/users` | Paginated operator list |
| POST | `/users` | Create operator |
| GET | `/users/:id` | Details, assignments, login history |
| PUT | `/users/:id` | Update profile, assignments, optional password |
| PATCH | `/users/:id/status` | Activate/deactivate |
| POST | `/users/:id/reset-password` | Admin password reset |
| DELETE | `/users/:id` | Delete operator |

List query parameters: `page`, `limit`, `search`, and `status`.

## Markets

Reading is authenticated and scoped for operators. Mutations require admin.

| Method | Path | Purpose |
|---|---|---|
| GET | `/markets` | List accessible markets |
| POST | `/markets` | Create market |
| GET | `/markets/:id` | Market details |
| PUT | `/markets/:id` | Update market |
| PATCH | `/markets/:id/status` | Activate/deactivate |
| DELETE | `/markets/:id` | Delete only when no entry history exists |

Market times use `HH:mm`.

## Entries

| Method | Path | Access |
|---|---|---|
| GET | `/entries` | Authenticated, ownership-scoped |
| POST | `/entries` | Authenticated, assigned active market |
| GET | `/entries/export/csv` | Authenticated, same scope/filters |
| GET | `/entries/:id` | Owner or admin |
| PUT | `/entries/:id` | Owner before cutoff or admin |
| DELETE | `/entries/:id` | Admin |

Filters: `date`, `from`, `to`, `market`, `operator` (admin), `category`,
`customerReference`, `entryNumber`, `status`, `search`, `sortBy`, `sortOrder`,
`page`, and `limit`.

Example:

```json
{
  "entryDate": "2026-07-31T00:00:00.000Z",
  "market": "MONGODB_OBJECT_ID",
  "customerReference": "DEMO-CUST-001",
  "category": "single_digit",
  "entryNumber": "5",
  "demoPoints": 10,
  "notes": "Demo record",
  "status": "active"
}
```

Formats: single digit `0–9`, jodi two digits, panna three digits, half sangam
`1–3 digits-1–3 digits`, full sangam `three digits-three digits`.

## Results

| Method | Path | Access |
|---|---|---|
| GET | `/results` | Authenticated; operators see assigned published only |
| POST | `/results` | Admin; creates draft |
| GET | `/results/:id` | Scoped authenticated |
| PUT | `/results/:id` | Admin; draft only |
| PATCH | `/results/:id/publish` | Admin; locks complete draft |

No endpoint calculates winnings or payouts.

## Reports

| Method | Path | Access |
|---|---|---|
| GET | `/reports/activity` | Authenticated |
| GET | `/reports/markets` | Authenticated |
| GET | `/reports/operators` | Admin |
| GET | `/reports/categories` | Authenticated |

Reports accept `from=YYYY-MM-DD` and `to=YYYY-MM-DD`. Activity additionally
accepts `page` and `limit`.

## Settings and audit

| Method | Path | Access |
|---|---|---|
| GET | `/settings` | Admin |
| PUT | `/settings` | Admin |
| GET | `/audit-logs` | Admin |

Audit filters: `user`, `action`, `module`, `from`, `to`, `page`, and `limit`.

## Status codes

- `200`: successful read/update/logout
- `201`: created
- `400`: request validation or invalid state
- `401`: missing, invalid, or expired authentication
- `403`: role, ownership, assignment, account, or cutoff restriction
- `404`: resource or route not found
- `409`: duplicate or locked/conflicting state
- `429`: request/account rate protection
- `500`: sanitized unexpected server error

