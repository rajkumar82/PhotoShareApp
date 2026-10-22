import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../config.dart';
import '../services/api.dart';

enum AuthState { loading, signedOut, signedIn }

class Profile {
  Profile({required this.name, this.email, this.photo});
  final String name;
  final String? email, photo;
}

/// Who is signed in. The PhotoShare token lives in secure storage; when the server stops accepting it (90 days),
/// a silent Google sign-in gets a new one without bothering the user.
class Session extends ChangeNotifier {
  Session() {
    api = Api(refresh: _refreshToken);
  }

  static const _tokenKey = 'photoshare_token';
  final _storage = const FlutterSecureStorage();
  late final Api api;
  AuthState state = AuthState.loading;
  Profile? me;
  String? error;
  bool signingIn = false;

  Future<void> init() async {
    await GoogleSignIn.instance.initialize(serverClientId: webClientId);
    api.token = await _storage.read(key: _tokenKey);
    if (api.token == null) return _set(AuthState.signedOut);
    try {
      var profile = await api.me();
      if (profile == null) {
        if (!await _refreshToken()) return _set(AuthState.signedOut);
        profile = await api.me();
      }
      me = _profile(profile);
    } on ApiException {
      // offline or the server is down: stay signed in, the feed will say what is wrong
    }
    _set(AuthState.signedIn);
  }

  Profile? _profile(Map<String, dynamic>? j) =>
      j == null ? null : Profile(name: j['name'] as String, email: j['email'] as String?, photo: j['photo'] as String?);

  Future<void> signIn() async {
    signingIn = true;
    error = null;
    notifyListeners();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw ApiException('Google did not return a sign-in token.');
      await _saveToken(await api.exchange(idToken));
      me = _profile(await api.me());
      _set(AuthState.signedIn);
    } on GoogleSignInException catch (e) {
      error = e.code == GoogleSignInExceptionCode.canceled ? null : 'Google sign-in failed (${e.code.name}). ${e.description ?? ''}'.trim();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final account = await GoogleSignIn.instance.attemptLightweightAuthentication();
      final idToken = account?.authentication.idToken;
      if (idToken == null) return false;
      await _saveToken(await api.exchange(idToken));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _saveToken(String token) async {
    api.token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _storage.delete(key: _tokenKey);
    api.token = null;
    me = null;
    _set(AuthState.signedOut);
  }

  void _set(AuthState s) {
    state = s;
    notifyListeners();
  }
}
