import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../config.dart';
import '../models/post.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// Talks to the PhotoShare server with the bearer token from `POST /api/auth/token`.
/// If the server says 401 (token expired), [refresh] is asked for a new token once and the call is retried.
class Api {
  Api({this.token, this.refresh, http.Client? client}) : _http = client ?? http.Client();

  String? token;
  Future<bool> Function()? refresh;
  final http.Client _http;

  Map<String, String> get headers => {if (token != null) 'Authorization': 'Bearer $token'};

  Future<http.Response> _send(Future<http.Response> Function() make) async {
    try {
      var res = await make();
      if (res.statusCode == 401 && refresh != null && await refresh!()) res = await make();
      return res;
    } on SocketException {
      throw ApiException('No connection. Check your internet and try again.');
    } on http.ClientException {
      throw ApiException('No connection. Check your internet and try again.');
    }
  }

  dynamic _body(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return res.body.isEmpty ? null : jsonDecode(res.body);
    var message = 'Something went wrong (${res.statusCode}).';
    try {
      message = (jsonDecode(res.body) as Map)['error'] as String? ?? message;
    } catch (_) {}
    throw ApiException(message, res.statusCode);
  }

  /// Swaps a Google ID token for a long-lived PhotoShare token.
  Future<String> exchange(String idToken) async {
    final res = await _send(() => _http.post(Uri.parse('$baseUrl/api/auth/token'),
        headers: {'Content-Type': 'application/json'}, body: jsonEncode({'credential': idToken})));
    return (_body(res) as Map)['token'] as String;
  }

  /// The signed-in profile, or null if the token is no longer accepted.
  Future<Map<String, dynamic>?> me() async {
    final res = await _send(() => _http.get(Uri.parse('$baseUrl/api/me'), headers: headers));
    return (_body(res) as Map?)?.cast<String, dynamic>();
  }

  Future<List<Post>> feed() async {
    final res = await _send(() => _http.get(Uri.parse('$baseUrl/api/feed'), headers: headers));
    return (_body(res) as List).map((j) => Post.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> upload(File file) async {
    final type = lookupMimeType(file.path) ?? 'image/jpeg';
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/photos'))
        ..headers.addAll(headers)
        ..files.add(await http.MultipartFile.fromPath('photo', file.path, contentType: MediaType.parse(type)));
      return http.Response.fromStream(await _http.send(req));
    });
    _body(res);
  }

  // ---- library (backups, kept apart from the feed) ----

  Future<List<({String month, int count})>> libraryMonths() async {
    final res = await _send(() => _http.get(Uri.parse('$baseUrl/api/library/months'), headers: headers));
    return [for (final m in (_body(res) as Map)['months'] as List) (month: m['month'] as String, count: m['count'] as int)];
  }

  Future<List<Post>> libraryMonth(String month, {required String ownerName, String? ownerPhoto}) async {
    final res = await _send(() => _http.get(Uri.parse('$baseUrl/api/library?month=$month'), headers: headers));
    return [
      for (final j in (_body(res) as Map)['photos'] as List) Post.fromLibrary(j as Map<String, dynamic>, ownerName: ownerName, ownerPhoto: ownerPhoto)
    ];
  }

  /// Which of these file hashes (SHA-256, hex) the server already holds.
  Future<Set<String>> libraryStored(List<String> hashes) async {
    final res = await _send(() => _http.post(Uri.parse('$baseUrl/api/library/check'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'hashes': hashes})));
    return {for (final h in (_body(res) as Map)['stored'] as List) h as String};
  }

  /// Backs up the original file (never re-encoded); the server checks [hash] against what arrived.
  Future<void> uploadToLibrary(File file, {required String hash, required DateTime takenAt, String? name}) async {
    final fileName = name ?? file.path.split(RegExp(r'[\/]')).last;
    final type = lookupMimeType(fileName) ?? 'application/octet-stream';
    final res = await _send(() async {
      final req = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/library'))
        ..headers.addAll(headers)
        ..fields['hash'] = hash
        ..fields['takenAt'] = takenAt.toUtc().toIso8601String()
        ..files.add(await http.MultipartFile.fromPath('photo', file.path, filename: fileName, contentType: MediaType.parse(type)));
      return http.Response.fromStream(await _http.send(req));
    });
    _body(res);
  }

  /// Puts a library photo on the feed (followers see it) or takes it off again.
  Future<void> publish(String id, {required bool on}) async {
    final res = await _send(() => _http.post(Uri.parse('$baseUrl/api/library/$id/publish'),
        headers: {...headers, 'Content-Type': 'application/json'}, body: jsonEncode({'on': on})));
    _body(res);
  }

  /// Creates a public slideshow link for [posts] (own photos only) and returns its full URL.
  Future<String> createShare(List<Post> posts) async {
    final res = await _send(() => _http.post(Uri.parse('$baseUrl/api/shares'),
        headers: {...headers, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'items': [for (final p in posts) {'owner': p.ownerId, 'id': p.id}]
        })));
    return '$baseUrl${(_body(res) as Map)['path']}';
  }

  Future<List<int>> download(String url) async {
    final res = await _send(() => _http.get(Uri.parse(url), headers: headers));
    if (res.statusCode != 200) throw ApiException('Could not download the photo.', res.statusCode);
    return res.bodyBytes;
  }
}
