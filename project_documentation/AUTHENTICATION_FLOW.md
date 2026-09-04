# Authentication flow

## Login

1. Flutter posts identifier and password to `/api/auth/login`.
2. IP rate limiting runs before credential processing.
3. The API locates the email or username, checks active status and lock time,
   then compares the bcrypt hash.
4. A failed password increments account-level attempts. Five failures cause a
   15-minute lock.
5. A successful login issues a 15-minute access token and seven-day refresh
   token, stores only the refresh token hash, and writes login/audit history.
6. Native clients receive both tokens and store them in secure storage.
7. Web receives the access token and an HTTP-only refresh cookie. The access
   token remains in memory.

## Protected request

Flutter adds `Authorization: Bearer ACCESS_TOKEN`. The API verifies signature,
issuer, expiry, token type, user existence, active status, role, ownership, and
market assignment where relevant.

## Refresh

The client calls `/api/auth/refresh` with the native refresh token or browser
cookie. The backend compares its hash using a timing-safe comparison, rotates
the pair, replaces the stored hash, and returns a new access token.

## Logout

`/api/auth/logout` invalidates the matching stored refresh hash, clears the web
cookie, records the event, and the client clears local secure storage.

## Forgot/reset password

1. `/api/auth/forgot-password` always returns the same generic message.
2. For an active matching account, it stores a SHA-256 reset-token hash with a
   30-minute expiry.
3. If SMTP is configured, a reset URL is emailed. Development mode also returns
   the raw token for local testing.
4. `/api/auth/reset-password` accepts the raw token and a strong password.
5. A successful reset clears the token and refresh session.

## Password change or account deactivation

Both actions invalidate the user's refresh session. Future API calls also fail
because active account status is checked on every request.

