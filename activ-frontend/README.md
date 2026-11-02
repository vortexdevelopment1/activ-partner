# activ_app

A new Flutter project.

## Backend Configuration

Use `.env.example` as the template for your local `.env` file. Set `API_URL`
to the deployed backend and `LOCAL_API_URL` to the local backend, including
`/api/v1`. Set at least one URL; leave the other blank to use only one backend.
With both set, the app tries local first and falls back to the deployed backend.
Android emulators also try `10.0.2.2` for a configured localhost URL. For physical
devices, set the local URL to your computer's LAN address.

Flutter loads `.env` automatically at startup:

```sh
flutter run
flutter build apk
flutter build web
flutter test
```

For Flutter Web in Chrome, use the WebAssembly/Skwasm renderer when testing or
deploying on devices/emulators that repeatedly lose the CanvasKit WebGL context:

```sh
flutter run -d chrome --wasm
flutter build web --wasm
```

The regular `flutter build web` command uses CanvasKit in Flutter 3.47.7. The
Skwasm build avoids the CanvasKit `MakeGrContext`/`Cannot dispose picture`
context-loss loop; it does not change the app's widgets or API behavior.

Run these commands from `activ-frontend`. Restart or rebuild after changing
`.env` so the bundled asset is refreshed. Build-time `--dart-define` values can
still override either URL, including setting a URL to blank. For Render-only builds,
leave `LOCAL_API_URL` blank.

Debug runs check the local API's public `/categories/active` endpoint at startup
with a two-second timeout. A valid response selects `LOCAL_API_URL`; an unavailable
local backend selects `API_URL`. Android emulators map `localhost` to `10.0.2.2`.
The selected backend stays fixed for the session; restart the app to check again.
An explicit `--dart-define=API_URL=...` pins the backend and skips this check.
Release builds continue to prefer the deployed API.

Environment values are public in the compiled app. Keep passwords and private
keys in the backend environment only. Local `.env` files are ignored by Git.

## Venue address search

Set `GOOGLE_MAPS_API_KEY` in `activ-frontend/.env`. Address autocomplete and
place details use this value; a key in the Android manifest or iOS configuration
does not populate the Dart configuration. An empty value produces
"Location search is unavailable. Please contact support."

The key's Google Cloud project must have billing and
[Places API (New)](https://developers.google.com/maps/documentation/places/web-service/get-api-key)
enabled. The PIN fallback also uses the Geocoding API when a selected place
has no postal code. Ensure the key's restrictions permit the required APIs.

Fully stop and rerun the app after editing `.env`, or rebuild and reinstall
the APK for an installed release. Hot reload does not reload the environment.
`--dart-define=GOOGLE_MAPS_API_KEY=...` overrides the `.env` value, including
when the build-time value is empty.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
