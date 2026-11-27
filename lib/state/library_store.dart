import 'package:flutter/foundation.dart';

import '../models/post.dart';
import '../services/api.dart';

/// The library: every backed-up photo, by month (newest first). Months load one at a time as they scroll into view.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this.api, {required this.ownerName, this.ownerPhoto});
  final Api api;
  final String ownerName;
  final String? ownerPhoto;

  List<({String month, int count})> months = [];
  final Map<String, List<Post>> _photos = {};
  final Set<String> _loading = {};
  bool loadedMonths = false;
  String? error;

  List<Post>? photosOf(String month) => _photos[month];

  /// Every photo loaded so far, so a selection can be turned back into photos.
  List<Post> get loaded => [for (final m in months) ...?_photos[m.month]];

  Future<void> load() async {
    error = null;
    try {
      months = await api.libraryMonths();
      _photos.removeWhere((m, _) => !months.any((x) => x.month == m));
      loadedMonths = true;
    } on ApiException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  Future<void> loadMonth(String month, {bool force = false}) async {
    if (_loading.contains(month) || (!force && _photos.containsKey(month))) return;
    _loading.add(month);
    try {
      _photos[month] = await api.libraryMonth(month, ownerName: ownerName, ownerPhoto: ownerPhoto);
    } on ApiException {
      // the month stays empty until pulled to refresh
    } finally {
      _loading.remove(month);
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final keep = _photos.keys.toList();
    await load();
    for (final m in keep) {
      if (months.any((x) => x.month == m)) await loadMonth(m, force: true);
    }
  }

  /// Puts photos on the feed or takes them off; returns how many changed.
  Future<int> publish(List<Post> posts, {required bool on}) async {
    var n = 0;
    for (final p in posts) {
      try {
        await api.publish(p.id, on: on);
        n++;
      } on ApiException {
        // counted by the caller
      }
    }
    await refresh();
    return n;
  }
}
