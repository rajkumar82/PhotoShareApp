import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../services/api.dart';

/// The feed: my own photos plus the ones from people I follow, newest first.
class FeedStore extends ChangeNotifier {
  FeedStore(this.api);
  final Api api;

  List<Post> posts = [];
  bool loading = false;
  String? error;
  String? uploadStatus;

  List<Post> get mine => [for (final p in posts) if (p.mine) p];
  List<Post> get circle => [for (final p in posts) if (!p.mine) p];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      posts = await api.feed();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Posts each file in turn (a failure only costs that photo); returns how many went up.
  Future<int> upload(List<File> files) async {
    var ok = 0;
    for (var i = 0; i < files.length; i++) {
      uploadStatus = files.length > 1 ? 'Posting ${i + 1} of ${files.length}…' : 'Posting…';
      notifyListeners();
      try {
        await api.upload(files[i]);
        ok++;
      } on ApiException {
        // counted by the caller
      }
    }
    uploadStatus = null;
    if (ok > 0) {
      await load();
    } else {
      notifyListeners();
    }
    return ok;
  }
}
