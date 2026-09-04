# Flutter architecture

## Structure

The client uses feature-first organization:

```text
lib/
├── app/                 theme and router
├── core/                API, config, secure storage, reusable utilities
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── markets/
│   ├── entries/
│   ├── results/
│   ├── reports/
│   ├── users/
│   ├── settings/
│   ├── audit_logs/
│   └── profile/
└── shared/              shell and shared widgets
```

Feature data folders contain serializable models and repositories. Presentation
folders contain Riverpod state, screens, and widgets. Domain folders are ready
for additional pure business rules as the application grows.

## State management

- `authProvider` is the source of authentication state.
- Repository providers own API access.
- Auto-dispose future providers load dashboard, list, settings, and audit data.
- Forms retain only transient UI state and invalidate list providers after a
  successful mutation.

## Navigation and authorization

GoRouter listens to authentication state. Unauthenticated users are redirected
to login, restored sessions reach the dashboard, and operator users are
redirected away from admin-only routes. Backend authorization remains the
security boundary; route guards only improve UX.

## Responsive UI

- Under 700 px: app bar, navigation drawer, bottom navigation, card lists, and
  single-column forms.
- 700–1099 px: navigation rail and two-column forms where space permits.
- 1100 px and above: permanent sidebar, top bar, data tables, and multi-column
  dashboard cards.

Screens use constrained layouts and reusable breakpoints rather than separate
mobile and desktop copies.

## Token handling

Native builds use Flutter Secure Storage. Web keeps access tokens in memory and
uses `BrowserHttpClientAdapter(withCredentials: true)` so the HTTP-only refresh
cookie is sent without exposing it to Dart code.

## API URLs

`API_BASE_URL` is compiled through `--dart-define`. Defaults are:

- Web/Windows/iOS: `http://localhost:5002/api`
- Android emulator: `http://10.0.2.2:5002/api`

Production builds must explicitly set an HTTPS URL.

