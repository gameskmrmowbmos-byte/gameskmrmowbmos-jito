# Matka Management Software

A full-stack manual record-management project with three main parts:

- `backend`: Node.js, Express, and MongoDB API.
- `flutter_app`: Flutter client for desktop, web, Android, and iOS.
- `admin`: React/Vite admin panel for browser-based management.

This project is structured for demo and educational use. It is for manually
entered records, markets, users, receipts, printed receipts, share PNG exports,
reports-style data, and application settings.

## Safety Notice

This repository must not be used to run an illegal gambling business. It does
not include deposits, withdrawals, payment gateways, wallets, automatic payouts,
or public betting integrations. Check local law before any real deployment or
shared demonstration.

## Main Features

- Admin and operator login with JWT access and refresh sessions.
- Role-based access and market assignment.
- Manual New Entry screen with receipt preview.
- Receipt saving, search, detail view, and print status.
- Share PNG page with A4 landscape export, 2 rows and 5 receipt boxes per page.
- Printed receipts page and customer parchi printing support.
- Market management, market schedule support, and number/game configuration.
- User management, audit logs, subscription/recharge-related admin screens.
- Demo seed scripts and setup documentation.

## Technology Stack

| Area | Technology |
| --- | --- |
| Mobile/Desktop/Web app | Flutter, Dart, Material 3 |
| Flutter state/routing | Riverpod, GoRouter |
| Flutter HTTP/storage | Dio, Flutter Secure Storage, Shared Preferences |
| Backend API | Node.js 20+, Express |
| Database | MongoDB, Mongoose |
| Admin panel | React, Vite, React Router, TanStack Query |
| Backend security | JWT, bcryptjs, Helmet, CORS, rate limits, validation |
| Logging | Winston, Morgan |

## Root Folder Structure

```text
matkamanagement/
|-- admin/
|   |-- src/
|   |   |-- App.jsx
|   |   |-- main.jsx
|   |   |-- api/
|   |   |-- context/
|   |   |-- layouts/
|   |   |-- pages/
|   |   `-- styles.css
|   |-- package.json
|   |-- eslint.config.js
|   |-- index.html
|   |-- vite.config.js
|   `-- vercel.json
|   |-- .env.example
|-- backend/
|   |-- src/
|   |-- scripts/
|   |-- tests/
|   |-- public/
|   |-- package.json
|   |-- .env.example
|   |-- doctor.config.json
|   `-- README.md
|-- flutter_app/
|   |-- lib/
|   |-- test/
|   |-- android/
|   |-- ios/
|   |-- web/
|   |-- windows/
|   |-- linux/
|   |-- macos/
|   |-- assets/
|   |-- pubspec.yaml
|   `-- README.md
|-- project_documentation/
|-- scratch/
|-- .gitignore
|-- README copy.md
`-- README.md
```

`backend/public/` contains the compiled Flutter web application served by the
API in deployments. Files such as `flutter.js`, `flutter_bootstrap.js`, and
`main.dart.js` are generated artifacts, not application source. React Doctor
excludes this directory through `backend/doctor.config.json`; do not hand-edit
the generated bundle to address scanner warnings. Rebuild the Flutter web app
when those files need to change.

## Important Root Files

| File or folder | Purpose |
| --- | --- |
| `README.md` | Main project guide and folder map. |
| `README copy.md` | Older root README copy kept in the repository. |
| `.gitignore` | Excludes dependencies, builds, logs, environment files, and generated files. |
| `project_documentation/` | Detailed setup, architecture, API, database, security, deployment, and testing guides. |
| `scratch/` | Temporary/local working folder. Do not rely on it for production code. |
| `backend/doctor.config.json` | React Doctor configuration that excludes generated and dependency files from scans. |

## Backend Folder Guide

```text
backend/
|-- src/
|   |-- app.js
|   |-- server.js
|   |-- config/                 # database.js, env.js
|   |-- constants/
|   |-- controllers/            # auth, receipts, markets, users, reports
|   |-- middleware/              # auth, roles, errors, sanitization
|   |-- models/                  # MongoDB/Mongoose documents
|   |-- routes/                  # Express route modules
|   |-- services/                # business rules and integrations
|   |-- utils/
|   `-- validators/
|-- scripts/                     # seed and migration commands
|-- tests/                       # Node test runner and API tests
|-- public/                      # compiled Flutter web output
|-- package.json
|-- .env.example
|-- doctor.config.json
`-- README.md
```

### Backend Important Files

| File | Purpose |
| --- | --- |
| `backend/src/server.js` | Starts the HTTP server. |
| `backend/src/app.js` | Creates the Express app and attaches middleware/routes. |
| `backend/src/config/env.js` | Reads and validates environment configuration. |
| `backend/src/config/database.js` | Connects to MongoDB. |
| `backend/src/controllers/auth.controller.js` | Login, logout, refresh, password flows. |
| `backend/src/controllers/receipt.controller.js` | Receipt creation, lookup, details, status, print-related receipt actions. |
| `backend/src/controllers/shareRecords.controller.js` | Data used by Flutter Share PNG page. |
| `backend/src/controllers/gameConfig.controller.js` | Number/game configuration endpoints. |
| `backend/src/controllers/market.controller.js` | Market CRUD and schedule-related actions. |
| `backend/src/controllers/user.controller.js` | User and operator management. |
| `backend/src/controllers/audit.controller.js` | Audit log access. |
| `backend/src/models/Receipt.js` | Receipt document schema, including `isOtc`. |
| `backend/src/models/ReceiptItem.js` | Receipt item schema, including bet type, amount, jackpot data, and components. |
| `backend/src/models/User.js` | User/admin/operator schema. |
| `backend/src/models/Market.js` | Market schema. |
| `backend/src/models/GameConfig.js` | Game configuration schema. |
| `backend/src/routes/*.routes.js` | Express route definitions. |
| `backend/src/middleware/auth.middleware.js` | JWT authentication middleware. |
| `backend/src/middleware/role.middleware.js` | Role/access checks. |
| `backend/src/middleware/error.middleware.js` | Central error response handling. |
| `backend/src/services/gameConfig.service.js` | Game validation and calculation rules. |
| `backend/src/services/token.service.js` | Access and refresh token handling. |
| `backend/src/utils/apiError.js` | API error helper. |
| `backend/src/utils/response.js` | Standard success response helper. |

The remaining backend modules follow the same ownership boundaries: route files
declare HTTP endpoints, controllers translate requests, services hold reusable
business rules, models define MongoDB documents, middleware handles cross-cutting
request concerns, and validators protect input contracts.

### Backend Scripts

| Script | Command | Purpose |
| --- | --- | --- |
| `seedAdmin.js` | `npm run seed:admin` | Creates/updates the admin user from `.env`. |
| `seedDemo.js` | `npm run seed:demo` | Adds demo users, markets, receipts, and settings. |
| `seedGameConfig.js` | `npm run seed:game-config` | Seeds game configuration. |
| `seedPannaNumbers.js` | `npm run seed:panna-numbers` | Seeds panna number data. |
| `seedPannaMotorNumbers.js` | `npm run seed:panna-motors` | Seeds motor/panna number data. |
| `addStandardMarkets.js` | Manual node script | Adds standard market records. |
| `migrateAccessFields.js` | `npm run migrate:access` | Migrates user access fields. |
| `checkSyntax.js` | `npm run check` | Syntax/check helper for backend files. |

## Flutter App Folder Guide

```text
flutter_app/
|-- lib/
|   |-- main.dart
|   |-- core/
|   |-- features/
|   |-- layout/
|   `-- shared/
|-- test/
|-- assets/
|-- android/
|-- ios/
|   |-- core/                    # api, config, language, routing, theme, storage
|   |-- features/                # auth, entries, new_entry, reports, sharing
|   |-- layout/                  # application shell and responsive layout
|   `-- shared/                  # reusable widgets and shared helpers
|-- test/                        # Flutter widget, unit, and integration tests
|-- assets/                      # icons and images declared in pubspec.yaml
|-- android/ | ios/ | web/       # platform runners and web bootstrap
|-- windows/ | linux/ | macos/   # desktop runners
| --- | --- |
| `flutter_app/lib/main.dart` | Flutter app entry point. |
| `flutter_app/lib/core/routing/app_router.dart` | GoRouter route definitions. |
| `flutter_app/lib/core/api/api_client.dart` | Main API client wrapper. |
| `flutter_app/lib/core/api/api_endpoints.dart` | API endpoint constants. |
| `flutter_app/lib/core/config/api_config.dart` | API base URL and environment config. |
| `flutter_app/lib/core/storage/secure_storage_service.dart` | Token/local storage wrapper. |
| `flutter_app/lib/core/theme/app_theme.dart` | Material theme configuration. |
| `flutter_app/lib/layout/main_layout.dart` | Main app shell/layout. |
| `flutter_app/lib/shared/widgets/app_sidebar.dart` | Sidebar and menu ordering. |
| `flutter_app/pubspec.yaml` | Flutter dependencies, SDK constraints, and assets. |

### Flutter Feature Folders

| Folder | Purpose |
| --- | --- |
| `flutter_app/lib/features/auth/` | Login, register, forgot/reset password, auth provider, auth repository. |
| `flutter_app/lib/features/new_entry/` | New Entry page, bet input, receipt preview, draft handling, game config loading. |
| `flutter_app/lib/features/entries/` | Saved entries list, receipt detail widgets, receipt repository/models. |
| `flutter_app/lib/features/share_records/` | Share PNG page, A4 page layout, receipt box widget, export/share services, chunker. |
| `flutter_app/lib/features/receipt_search/` | Receipt search page and controller. |
| `flutter_app/lib/features/printed_receipts/` | Printed receipt listing and web/customer parchi printing services. |

### Share PNG Important Files

| File | Purpose |
| --- | --- |
| `share_records_page.dart` | Share PNG screen, filters, preview, download/share actions. |
| `a4_record_page_widget.dart` | A4 landscape page layout with 2 rows and 5 receipt boxes. |
| `record_box_widget.dart` | Individual receipt box drawing used in PNG export. |
| `share_records_chunker.dart` | Splits records into receipt boxes and pages. |
| `share_records_models.dart` | API response models for Share PNG records. |
| `share_records_repository.dart` | Calls backend Share Records API. |
| `share_records_export_service.dart` | Captures PNG and builds simple PDF output. |

## Admin Panel Folder Guide

```text
admin/
|-- src/
|   |-- App.jsx
|   |-- main.jsx
|   |-- api/
|   |-- context/
|   |-- layouts/
|   |-- pages/
|   `-- styles.css
|-- package.json
|-- eslint.config.js
|-- index.html
|-- vite.config.js
`-- vercel.json
```

### Admin Important Files

| File | Purpose |
| --- | --- |
| `admin/src/main.jsx` | React entry point. |
| `admin/src/App.jsx` | Admin routes and page composition. |
| `admin/src/api/client.js` | Axios API client. |
| `admin/src/context/AuthContext.jsx` | Browser admin auth state. |
| `admin/src/layouts/Shell.jsx` | Admin shell/navigation layout. |
| `admin/src/pages/Login.jsx` | Admin login page. |
| `admin/src/pages/Dashboard.jsx` | Admin dashboard. |
| `admin/src/pages/Markets.jsx` | Market management. |
| `admin/src/pages/Users.jsx` | User/operator management. |
| `admin/src/pages/NumberConfig.jsx` | Number/game configuration. |
| `admin/src/pages/AuditLogs.jsx` | Audit log viewer. |
| `admin/src/pages/Settings.jsx` | Application settings. |
| `admin/src/pages/Recharges.jsx` | Recharge-related admin screen. |
| `admin/src/pages/Plans.jsx` | Plan/subscription-related admin screen. |

## Project Documentation Folder

| File | Purpose |
| --- | --- |
| `project_documentation/PROJECT_OVERVIEW.md` | High-level overview. |
| `project_documentation/SETUP_GUIDE.md` | Detailed local setup. |
| `project_documentation/API_DOCUMENTATION.md` | Backend API contract. |
| `project_documentation/DATABASE_SCHEMA.md` | MongoDB collections and schema notes. |
| `project_documentation/BACKEND_ARCHITECTURE.md` | Backend architecture guide. |
| `project_documentation/FLUTTER_ARCHITECTURE.md` | Flutter architecture guide. |
| `project_documentation/AUTHENTICATION_FLOW.md` | Auth and token flow. |
| `project_documentation/SECURITY_GUIDE.md` | Security guidance. |
| `project_documentation/DEPLOYMENT_GUIDE.md` | Deployment notes. |
| `project_documentation/TESTING_GUIDE.md` | Testing commands and process. |
| `project_documentation/VERIFICATION_REPORT.md` | Verification notes/report. |

## Prerequisites

- Node.js 20 or newer.
- npm.
- MongoDB 7/8 locally or MongoDB Atlas.
- Flutter stable with Dart 3.4 or newer.
- Chrome for Flutter web.
- Android Studio/Android SDK for Android.
- Visual Studio 2022 Desktop development with C++ workload for Windows builds.
- Xcode and CocoaPods on macOS for iOS builds.

## Backend Setup

```bash
cd backend
npm install
cp .env.example .env
npm run seed:admin
npm run dev
```

For Windows PowerShell, copy the env file with:

```powershell
Copy-Item .env.example .env
```

Default API health check:

```text
http://localhost:5002/api/health
```

Important backend `.env` values:

| Key | Purpose |
| --- | --- |
| `PORT` | Backend port, commonly `5002`. |
| `MONGODB_URI` | MongoDB connection string. |
| `JWT_ACCESS_SECRET` | Access token secret. Use a strong unique value. |
| `JWT_REFRESH_SECRET` | Refresh token secret. Use a different strong unique value. |
| `ADMIN_EMAIL` | Admin seed email. |
| `ADMIN_PASSWORD` | Admin seed password. |
| `DEMO_OPERATOR_PASSWORD` | Demo operator seed password. |
| `FRONTEND_URL` | Allowed web origins for CORS/cookies. |

## Flutter Setup

```bash
cd flutter_app
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5002/api
```

Other useful run commands:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5002/api
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5002/api
flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_LAN_IP:5002/api
```

Use `10.0.2.2` for Android emulator access to the computer's localhost. Use the
computer LAN IP for a physical phone.

## Admin Panel Setup

```bash
cd admin
npm install
cp .env.example .env
npm run dev
```

For Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

The admin panel dev server uses Vite. The package script runs on port `5174`.

## Verification Commands

Run these manually when needed.

Backend:

```bash
cd backend
npm run check
npm test
```

Flutter:

```bash
cd flutter_app
flutter analyze
flutter test
```

Admin:

```bash
cd admin
npm run build
npm run lint
```

React Doctor, from the backend project root (generated Flutter output is
excluded by `doctor.config.json`):

```bash
cd backend
npx --yes react-doctor@latest --scope full --no-share
```

## Demo Login Notes

Credentials are not hardcoded in the app. They come from backend `.env` values
and seed scripts.

| Account | Where it comes from |
| --- | --- |
| Admin email | `ADMIN_EMAIL` in `backend/.env` |
| Admin password | `ADMIN_PASSWORD` in `backend/.env` |
| Demo operators | Created by `npm run seed:demo` |
| Demo operator password | `DEMO_OPERATOR_PASSWORD` in `backend/.env` |

Change every seed/demo password before any shared demo or deployment.

## Common Troubleshooting

### Flutter says failed to load initial data

- Confirm the backend is running.
- Confirm `API_BASE_URL` ends with `/api`.
- For Android emulator, use `http://10.0.2.2:5002/api`.
- For a real phone, use the computer LAN IP and allow the backend port through
  the firewall.
- Log in again if the access token is expired or storage was cleared.

### Web CORS or cookie issue

- Add the exact Flutter/Admin origin to `FRONTEND_URL`.
- Use comma-separated origins if more than one frontend is running.
- Restart the backend after changing `.env`.

### MongoDB connection issue

- Start MongoDB locally or verify the Atlas connection string.
- Check database username, password, IP allowlist, and URL encoding.

### Share PNG does not update after code changes

- Hot restart the Flutter app.
- Refresh/reload data on the Share PNG page.
- Download the PNG again after the backend has restarted if API fields changed.

## Production Checklist

- Use HTTPS for backend and frontends.
- Use managed MongoDB with backups and restricted access.
- Generate unique strong JWT secrets.
- Do not commit `.env`, logs, generated exports, or database backups.
- Set `NODE_ENV=production`.
- Restrict `FRONTEND_URL` to deployed origins.
- Configure SMTP for password reset email if needed.
- Build signed mobile/desktop releases.
- Run backend, Flutter, and admin verification commands.
- Review local legal requirements before any public use.
