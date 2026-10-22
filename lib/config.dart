/// The PhotoShare server (the same one the web app uses). Override for a local server:
/// `flutter run --dart-define=BASE_URL=http://10.0.2.2:8099`
const baseUrl = String.fromEnvironment('BASE_URL', defaultValue: 'https://photoshare.nocod.dev');

/// The OAuth *Web* client id (public). The Google ID token the phone obtains is issued for it, which is
/// what the server checks (`GOOGLE_CLIENT_ID`); the Android client only has to exist in the same project.
const webClientId = '115193446543-d0dnmbi2tj156gkohkqnjbh4itk2pbpf.apps.googleusercontent.com';
