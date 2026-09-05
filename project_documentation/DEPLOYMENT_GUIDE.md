# Deployment guide

## Backend

Deploy the `backend` folder to a Node.js 20+ service. The start command is:

```bash
npm ci --omit=dev
npm start
```

Set all environment variables in the host's encrypted configuration. Do not
upload `.env`. The service must reach MongoDB through TLS and expose HTTPS.
Configure a health probe for `/api/health`.

Recommended production topology:

```text
Flutter web / native apps
        ↓ HTTPS
Reverse proxy or managed load balancer
        ↓
Node.js API
        ↓ TLS
Managed MongoDB
```

Use one API instance only if refresh token state and traffic permit it. Multiple
instances work because sessions are stored in MongoDB, not process memory.

## Flutter web

```bash
flutter build web --release \
  --dart-define=API_BASE_URL=https://api.example.com/api
```

Deploy `build/web` to HTTPS static hosting. Configure SPA fallback so unknown
paths serve `index.html`. Add the final origin to backend `FRONTEND_URL`.

## Android

Create `flutter_app/android/key.properties` from
`flutter_app/android/key.properties.example` and point it at an existing
release keystore. Keep both the keystore and `key.properties` outside source
control. The release build fails closed when signing is not configured.
Then:

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.example.com/api
```

Upload the `.aab` through the Google Play Console.

## iOS

On macOS, configure the bundle identifier and Apple team in Xcode:

```bash
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.example.com/api
```

Distribute through App Store Connect or an approved enterprise workflow.

## Windows

```bash
flutter build windows --release \
  --dart-define=API_BASE_URL=https://api.example.com/api
```

Code-sign the executable/installer. Package the entire Release bundle, not only
the `.exe`.

## Operational controls

- Automated database backups and restore drills
- Central logs without secrets or raw tokens
- Error-rate, latency, database, SMTP, and uptime alerts
- Dependency and container scanning
- TLS renewal monitoring
- Least-privilege administrator access
- Data retention/export deletion policy
- Legal review for every deployment jurisdiction

