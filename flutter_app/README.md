# Flutter application

One Material 3 Flutter codebase for Android, iOS, Windows, and web. It uses
Riverpod, GoRouter, Dio, responsive layouts, secure native token storage, and
HTTP-only refresh-cookie support on web.

## Run

```bash
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5003/api
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5003/api
flutter run -d android --dart-define=API_BASE_URL=http://10.0.2.2:5003/api
```

For a real Android device, replace the URL with the computer's LAN IP:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:5003/api
```

The API host must allow the web application's origin through `FRONTEND_URL`.
See the root README and `project_documentation/SETUP_GUIDE.md`.
