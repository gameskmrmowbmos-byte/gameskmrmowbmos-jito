# Testing guide

## Backend automated checks

```bash
cd backend
npm ci
npm run check
npm test
```

The included Node test suite checks the health/error envelopes, protected-route
authentication, CSV escaping, pagination, entry formats, and edit-time helpers.

For full database integration testing, create a separate test database and add
tests for login rotation, role/ownership rules, cutoff behavior, duplicate
results, audit values, and seed idempotency. Never point tests at production.

## Flutter checks

```bash
cd flutter_app
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

Included Flutter tests cover model deserialization/serialization and responsive
breakpoints.

## Manual acceptance matrix

| Scenario | Admin | Operator |
|---|---:|---:|
| Login/logout/session refresh | Test | Test |
| Inactive account rejected | Test | Test |
| Create/edit market | Allowed | Denied |
| See assigned markets | All | Assigned active only |
| Create entry | Allowed | Assigned active only |
| Edit after cutoff | Allowed | Denied |
| View entries | All | Own only |
| Delete entry | Allowed | Denied |
| Publish/lock result | Allowed | Denied |
| View draft result | Allowed | Denied |
| View published assigned result | Allowed | Allowed |
| Operator report | Allowed | Denied |
| Settings/audit logs | Allowed | Denied |

## Platform matrix

Test at least:

- Android emulator and one physical Android device
- iOS simulator and one physical iPhone if distributing for iOS
- Windows debug and release bundle
- Chrome desktop at mobile, tablet, and desktop widths

## Security checks

- Expired/modified/wrong-type JWT
- Reused refresh token after rotation
- Disabled user with existing access token
- Five bad passwords and rate-limit responses
- Mongo operator keys in body/query
- Duplicate username/email/market/result
- CORS from an unapproved origin
- Production 500 response without stack
- Audit records without password/token data
- CSV values containing commas, quotes, and line breaks

