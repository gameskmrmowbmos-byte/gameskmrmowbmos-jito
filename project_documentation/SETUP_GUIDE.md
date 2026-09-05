# Setup guide

## MongoDB

### Local

Install MongoDB Community Server and ensure it listens on localhost. Use:

```env
MONGODB_URI=mongodb://127.0.0.1:27017/matka_management
```

### Atlas

Create a database user with only the permissions needed for this database,
allow the backend host's IP, copy the Node.js connection URI, URL-encode special
password characters, and place the URI only in `.env` or a secret manager.

## Backend

```bash
cd backend
npm install
cp .env.example .env
```

Required values:

```env
MONGODB_URI=...
JWT_ACCESS_SECRET=...
JWT_REFRESH_SECRET=...
ADMIN_NAME=...
ADMIN_EMAIL=...
ADMIN_PASSWORD=...
```

Generate secrets with a cryptographically secure password/secret generator.
Never reuse the access and refresh secrets.

Optional SMTP values enable production reset email:

```env
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=...
SMTP_PASS=...
SMTP_FROM=Matka Management Demo <no-reply@example.com>
```

Then:

```bash
npm run seed:admin
npm run dev
```

Run `npm run seed:demo` only in a demonstration database.

## Flutter

```bash
cd flutter_app
flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

Run with one of the commands in the root README.

## Web cookies and CORS

The backend web refresh cookie is HTTP-only. In production it is also Secure
and SameSite=None, so both client and API must use HTTPS. Set exact client
origins:

```env
FRONTEND_URL=https://app.example.com,https://admin.example.com
```

## First-use checklist

1. Sign in as the seeded administrator.
2. Change the administrator password if a temporary value was used.
3. Review timezone, editing cutoff, pagination, and session settings.
4. Create/confirm markets.
5. Create operators and assign only the needed markets.
6. Test one entry, draft result, publication, CSV export, and audit event.
7. Test logout, token refresh, deactivation, and password reset.

