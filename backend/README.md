# Backend API

Production-structured Node.js, Express, MongoDB, and Mongoose API for the
demo-only Matka Management record system.

## Start locally

```bash
npm install
cp .env.example .env
npm run seed:admin
npm run dev
```

MongoDB must be reachable through `MONGODB_URI`. The API starts on port `5002`
by default. `GET /api/health` does not require authentication.

## Seed data

- `npm run seed:admin` creates or updates the admin from `ADMIN_*` variables.
- `npm run seed:demo` adds an admin, two operators, three markets, sample
  receipts with receipt items for today, and default settings.

The demo seed uses `ADMIN_PASSWORD` and `DEMO_OPERATOR_PASSWORD` from `.env`
when present. Otherwise it falls back to local-only sample passwords printed in
the seed output. Do not use sample passwords in a deployed environment.

## Verification

```bash
npm run check
npm test
```

See `../project_documentation/API_DOCUMENTATION.md` and
`../project_documentation/SECURITY_GUIDE.md` for the full contract.
