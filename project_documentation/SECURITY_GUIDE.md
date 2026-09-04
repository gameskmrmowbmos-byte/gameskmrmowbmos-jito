# Security guide

## Implemented controls

- bcrypt cost 12 password hashing
- Strong password validators
- Short access tokens with issuer and type claims
- Rotating refresh tokens; only SHA-256 hash stored
- Timing-safe refresh-hash comparison
- HTTP-only Secure cross-site web refresh cookie in production
- Native platform secure storage
- Account active check on every protected request
- Role, record ownership, and assigned-market checks
- IP rate limits for API, login, and reset endpoints
- Temporary lock after repeated bad account passwords
- Helmet headers and explicit credentialed CORS origins
- Small body limits, request-key sanitation, Mongoose filter sanitation
- Express Validator normalization and category-specific formats
- Central error handler and production stack suppression
- Audit logs with IP and user agent
- Refresh invalidation on deactivation/password change/reset
- No hardcoded secrets or real `.env`

## Secret handling

Keep MongoDB credentials, JWT secrets, SMTP credentials, signing keys, and
passwords in the deployment secret manager. Rotate secrets after any suspected
exposure. Rotating JWT secrets invalidates existing sessions.

## Web deployment

HTTPS is mandatory. Configure only exact trusted origins. Do not use wildcard
CORS with credentials. Keep the access token in memory. Never move the refresh
token from the HTTP-only cookie to localStorage.

## Native deployment

Use Android Keystore-backed and iOS Keychain-backed secure storage. Sign release
artifacts, protect signing keys, disable debug builds for distribution, and set
an HTTPS production API URL.

## MongoDB

Use TLS, a dedicated least-privilege user, network restrictions, encryption at
rest, backups, and monitoring. Avoid public `0.0.0.0/0` Atlas access.

## Logging/privacy

Do not log passwords, raw JWTs, reset tokens, MongoDB URIs, SMTP credentials, or
full request bodies. Decide how long customer references, login history, IP
addresses, user agents, and audit snapshots should be retained.

## Further hardening

- Add MFA for administrators.
- Add a breached-password check.
- Use an external email queue with delivery monitoring.
- Add a web CSRF token if future cookie-authenticated mutation endpoints are
  introduced.
- Add security headers at the reverse proxy.
- Run dependency updates, SAST, DAST, and penetration testing before launch.
- Consider soft deletion and protected audit-log storage for regulated use.

