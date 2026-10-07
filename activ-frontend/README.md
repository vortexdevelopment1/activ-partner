# activ_app

A new Flutter project.

## Backend Configuration

Use `.env.example` as the template for your local `.env` file. Set `API_URL`
to the deployed backend and `LOCAL_API_URL` to the local backend, including
`/api/v1`. Set at least one URL; leave the other blank to use only one backend.
With both set, the app tries local first and falls back to the deployed backend.
Android emulators also try `10.0.2.2` for a configured localhost URL. For physical
devices, set the local URL to your computer's LAN address.

Flutter reads the file at compile time when you pass:

```sh
flutter run --dart-define-from-file=.env
flutter build apk --dart-define-from-file=.env
flutter build web --dart-define-from-file=.env
flutter test --dart-define-from-file=.env
```

Run these commands from `activ-frontend`. Restart or rebuild after changing
`.env`; hot reload does not update compile-time values. For Render-only builds,
leave `LOCAL_API_URL` blank.

Environment values are public in the compiled app. Keep passwords and private
keys in the backend environment only. Local `.env` files are ignored by Git.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
