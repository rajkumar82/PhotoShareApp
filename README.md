# PhotoShare app

Flutter (Android) client for the PhotoShare web app (`../PhotoShare`, https://photoshare.nocod.dev). Same server, same
accounts and photos; the phone just talks to the JSON API with a bearer token instead of the cookie.

## What it does (v1)

- **Sign in with Google** (`lib/state/session.dart`): the phone gets a Google ID token for the shared OAuth *Web* client
  (`lib/config.dart`), swaps it at `POST /api/auth/token` for a 90-day PhotoShare token, and keeps that in secure
  storage. When the server stops accepting it, a silent Google sign-in fetches a new one.
- **Me / Circle grids** grouped by date (same headings as the web app), pull to refresh, thumbnails cached on disk.
- **Fullscreen viewer**: swipe up/down, the next 3 photos are fetched ahead, download and share buttons.
- **Long-press to select** several photos; the bar on top saves them to the phone (Pictures/PhotoShare via the `gal`
  package, no zip needed on a phone) or shares them as a slideshow link (`POST /api/shares`, own photos only) through
  the share sheet with an invitation to try PhotoShare.
- **Post**: camera button, or the gallery button for several photos at once.

Not here yet: captions/comments editing, find/follow people, and the reason this app exists, auto-sync of chosen
camera folders and "free up space".

## Setup: Google sign-in on Android

Sign-in only works once an **Android OAuth client** exists in the GCP project that owns the web client
(`nocode-512210`): Console -> APIs & Services -> Credentials -> Create credentials -> OAuth client ID -> Android, with

- package name `com.rajkumar.photoshare`
- SHA-1 of the key the APK is signed with. Debug and release builds are both signed with the debug keystore for now
  (like PaperScanner): `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`

Nothing from that client goes into the code; it just has to exist. The server also needs the token endpoint
(`POST /api/auth/token`), which is deployed with the PhotoShare web app.

## Run

    flutter pub get
    flutter run                      # against https://photoshare.nocod.dev
    flutter run --dart-define=BASE_URL=http://10.0.2.2:8099   # emulator -> local server (note: needs real Google sign-in)

    flutter test
    flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk

## Launcher icon

Made from the web app's icons (`assets/icon/`): `dart run flutter_launcher_icons`.
