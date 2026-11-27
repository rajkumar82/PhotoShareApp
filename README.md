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

- **Pinch / double-tap zoom** in the viewer.
- **Library tab** (v1.2): every backed-up photo by month, kept at full quality and private until you select it and tap the globe
  icon to post it to your feed (tap again to take it off).
- **Back up photos** (menu): tick camera folders, then "Back up now", or switch on automatic backup (every ~6 hours in the
  background, Wi-Fi only / charging only options). Photos are matched by SHA-256, so re-running never duplicates, and a photo is only
  remembered as done after the server confirms it. Photos only (no videos yet). Needs the library endpoints deployed on the server.

Not here yet: captions/comments editing, find/follow people, and "free up space" (deleting backed-up photos from the phone).

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

## Releases

APKs on GitHub Releases. Build one APK per processor (~18 MB each; a single fat APK is ~50 MB). The 64-bit ARM one,
which nearly every phone needs, must be named exactly `photoshare.apk` so
`https://github.com/rajkumar82/PhotoShareApp/releases/latest/download/photoshare.apk` always resolves to it:

    flutter build apk --release --split-per-abi
    cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/app/outputs/flutter-apk/photoshare.apk
    cp build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk build/app/outputs/flutter-apk/photoshare-armv7.apk
    gh release create vX.Y.Z build/app/outputs/flutter-apk/photoshare.apk build/app/outputs/flutter-apk/photoshare-armv7.apk \
      -R rajkumar82/PhotoShareApp --title "PhotoShare vX.Y.Z" --notes "..."

Tag to match `version:` in `pubspec.yaml`.

## Launcher icon

Made from the web app's icons (`assets/icon/`): `dart run flutter_launcher_icons`.
