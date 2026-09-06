# JWT Login Demo

This is a **local demonstration** of the login/token/logout flow. Use `demo@example.com` and `password123` to sign in.

The demo generates an unsigned, JWT-shaped token only so the app can demonstrate decoding an `exp` claim and persisting a session. It is not authentication security.

## Create missing platform files and run

After any other `flutter run` has stopped, open a terminal in this folder and run:

```powershell
flutter create --platforms=windows,web .
flutter pub get
flutter run -d chrome
```

For a real app, post credentials only to your HTTPS API. Have the API verify the password and return a signed, short-lived JWT. Prefer secure platform storage for tokens on mobile/desktop, and never put a signing key in the Flutter app.
