# Matka Management Software

A production-structured, full-stack **demo and educational record-management
application**. One Flutter codebase supports Android, iOS, Windows, and web. A
Node.js/Express API stores data in MongoDB.

> **Legal and safety limitation:** This software is only for manually entered
> records, user administration, schedules, demo results, activity reports, and
> accounting-style demo points. It contains no deposits, withdrawals, payment
> gateways, wallets, automatic winnings, payouts, public betting APIs, gambling
> advertising, or tools intended to operate an illegal gambling business.

## Included modules

- Secure admin/operator authentication with access and rotating refresh tokens
- Forgot/reset/change password flows and optional SMTP delivery
- Role- and assigned-market authorization
- Responsive dashboard
- Market schedules and activation controls
- Manual entries with category-specific validation and editing cutoff rules
- Entry search, filters, details, status, admin deletion, and CSV export
- Draft and locked published demo results
- Activity, market, operator, and category reports
- Operator accounts and market assignments
- Application settings
- Audit logs and login history
- Demo seed data

## Technology

| Layer | Technology |
|---|---|
| Client | Flutter stable, Dart, Material 3 |
| Client state/navigation | Riverpod, GoRouter |
| HTTP/storage | Dio, Flutter Secure Storage, secure web refresh cookie |
| API | Node.js 20+, Express |
| Database | MongoDB, Mongoose |
| Security | JWT, bcryptjs, Helmet, CORS, validation, rate limits |
| Logging | Winston, Morgan |

## Folder structure

```text
matka_management/
├── backend/
│   ├── scripts/
│   ├── src/
│   └── tests/
├── flutter_app/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── windows/
│   ├── lib/
│   └── test/
├── project_documentation/
├── README.md
└── .gitignore
```

## Prerequisites

- Node.js 20 or newer and npm
- MongoDB 7/8 locally or a MongoDB Atlas connection
- Flutter stable with Dart 3.4 or newer
- Platform tooling:
  - Android Studio/Android SDK for Android
  - Xcode and CocoaPods on macOS for iOS
  - Visual Studio 2022 with Desktop development with C++ for Windows
  - Chrome for web

## 1. Backend setup

```bash
cd backend
npm install
cp .env.example .env
```

Edit `.env`. Generate different random values of at least 32 characters for
`JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET`. Change both example passwords.

For local MongoDB:

```env
MONGODB_URI=mongodb://127.0.0.1:27017/matka_management
PORT=5002
```

Create the admin and start the API:

```bash
npm run seed:admin
npm run dev
```

Optional demo records:

```bash
npm run seed:demo
```

Health check: `http://localhost:5002/api/health`

## 2. Flutter setup

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

### Windows

```bash
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5002/api
```

### Web

Add the exact Flutter web origin to `FRONTEND_URL` in the backend `.env`. It
accepts a comma-separated list.

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5002/api
```

### Android emulator

```bash
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5002/api
```

### Real Android device

Connect the phone and computer to the same network. Allow port `5002` through
the computer firewall and use the computer's LAN IPv4 address:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:5002/api
```

### iOS simulator

Run on macOS:

```bash
cd ios
pod install
cd ..
flutter run -d ios --dart-define=API_BASE_URL=http://localhost:5002/api
```

For a physical iPhone, use the computer's LAN IP and configure an Apple
development team in Xcode.

## Demo login instructions

The application never hardcodes credentials.

- Admin email: value of `ADMIN_EMAIL`
- Admin password: value of `ADMIN_PASSWORD`
- Demo operators after `npm run seed:demo`:
  - `operator1@example.com`
  - `operator2@example.com`
- Both demo operator passwords: value of `DEMO_OPERATOR_PASSWORD`

Change all seed passwords before any shared or deployed demonstration.

## Authentication design

- Access tokens expire after 15 minutes by default.
- Refresh tokens rotate and only a SHA-256 hash is stored in MongoDB.
- Native apps keep tokens in platform secure storage.
- Web keeps the access token in memory and refreshes with an HTTP-only cookie.
- Deactivating a user or changing a password invalidates refresh sessions.
- Five incorrect account passwords trigger a temporary account lock. The API
  also rate-limits login and reset requests by client IP.

## Common troubleshooting

### `Cannot connect to the API`

Confirm the backend is running, the URL ends in `/api`, and the correct host is
used. Android emulators cannot use the computer's `localhost`; use `10.0.2.2`.
A real phone requires the LAN IP.

### Web CORS error

Set `FRONTEND_URL` to the complete origin printed by `flutter run`, restart the
backend, and do not add a trailing path.

### MongoDB connection error

Start the local MongoDB service or verify the Atlas URI, IP allowlist, database
user, and URL-encoded password.

### iOS Pod error

Run `flutter clean`, `flutter pub get`, `cd ios && pod repo update && pod
install`. iOS builds require macOS.

### Windows build tools missing

Run `flutter doctor -v` and install Visual Studio 2022's **Desktop development
with C++** workload.

## Production checklist

- Use managed MongoDB with backups, TLS, least-privilege credentials, and IP
  restrictions.
- Generate separate, high-entropy JWT secrets and store them in a secret
  manager.
- Use HTTPS for the API and client.
- Set `NODE_ENV=production`.
- Restrict `FRONTEND_URL` to real deployed origins.
- Configure SMTP and test password reset delivery.
- Build signed Android/iOS releases and code-sign Windows packages.
- Run backend and Flutter checks from `TESTING_GUIDE.md`.
- Keep demo/legal limitations visible and verify local legal requirements.
- Add centralized logs, alerts, uptime checks, and a retention policy.
- Never deploy `.env`, demo passwords, logs, exports, or database backups into
  a public repository.

Detailed guides are in [`project_documentation`](project_documentation/).

