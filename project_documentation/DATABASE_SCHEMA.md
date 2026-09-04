# Database schema

MongoDB collections are created through Mongoose. All operational models use
timestamps unless stated otherwise.

## User

| Field | Type | Notes |
|---|---|---|
| fullName | String | Required, 2–100 characters |
| username | String | Unique, lowercase |
| email | String | Unique, lowercase |
| phoneNumber | String | Optional |
| passwordHash | String | bcrypt, excluded from normal queries |
| role | String | `admin` or `operator` |
| assignedMarkets | ObjectId[] | Market references |
| isActive | Boolean | Checked on every authenticated call |
| lastLogin | Date | Last successful login |
| loginHistory | Array | Success, IP, user agent, timestamp |
| failedLoginAttempts | Number | Account-level protection |
| lockUntil | Date | Temporary lock expiry |
| refreshTokenHash | String | SHA-256 hash, never raw token |
| passwordResetTokenHash | String | SHA-256 hash |
| passwordResetExpires | Date | 30-minute validity |
| passwordChangedAt | Date | Security event |

## Market

| Field | Type | Notes |
|---|---|---|
| name | String | Required |
| code | String | Unique, uppercase |
| openingTime | String | `HH:mm` |
| closingTime | String | `HH:mm` |
| resultTime | String | `HH:mm` |
| isActive | Boolean | Inactive markets reject new entries |
| description | String | Maximum 500 characters |
| createdBy | ObjectId | User reference |

## Entry

| Field | Type | Notes |
|---|---|---|
| entryDate | Date | Indexed |
| market | ObjectId | Required Market reference |
| customerReference | String | Reference name/code |
| category | String | Configured record category |
| entryNumber | String | Validated against category |
| demoPoints | Number | Positive demo value |
| notes | String | Maximum 1,000 characters |
| createdBy | ObjectId | Operator/admin reference |
| status | String | `active` or `void` |

Supported categories are `single_digit`, `jodi`, `single_panna`,
`double_panna`, `triple_panna`, `half_sangam`, and `full_sangam`.

## Result

| Field | Type | Notes |
|---|---|---|
| resultDate | Date | Unique with market |
| market | ObjectId | Market reference |
| openDigit / closeDigit | String | One digit |
| openPanna / closePanna | String | Three digits |
| jodi | String | Two digits |
| notes | String | Demo notes |
| status | String | `draft` or `published` |
| publishedBy | ObjectId | Administrator |
| publishedAt | Date | Publication time |

Published results are immutable through the API.

## AuditLog

Stores user, action, module, record ID, previous value, new value, IP address,
user agent, metadata, and timestamp. Passwords and raw tokens are never added to
audit values.

## Settings

A singleton document stores application name, logo URL, timezone, date format,
demo-points label, editing policy, cutoff minutes, pagination size, session
timeout, and the last administrator who updated it.

## Important indexes

- Unique username and email
- Unique market code
- Unique result date and market pair
- Entry date, market, operator, category, and status indexes
- Audit timestamp and module/action indexes
- Text indexes for common user, market, and entry searches

