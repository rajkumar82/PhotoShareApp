import 'models/post.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Heading for a photo's date: the day for this month ("21 Oct"), the month for earlier months this year
/// ("Sep 2026"), else the year. Same rule as the web app.
String groupLabel(DateTime d, [DateTime? now]) {
  now ??= DateTime.now();
  if (d.year != now.year) return '${d.year}';
  if (d.month != now.month) return '${_months[d.month - 1]} ${d.year}';
  return '${d.day} ${_months[d.month - 1]}';
}

/// Splits newest-first posts into consecutive runs sharing a heading.
List<(String, List<Post>)> groupPosts(List<Post> posts, [DateTime? now]) {
  final groups = <(String, List<Post>)>[];
  for (final p in posts) {
    final label = groupLabel(p.postedAt, now);
    if (groups.isEmpty || groups.last.$1 != label) groups.add((label, []));
    groups.last.$2.add(p);
  }
  return groups;
}

String formatTime(DateTime d) => '${d.day} ${_months[d.month - 1]}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
