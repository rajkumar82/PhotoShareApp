import 'package:flutter_test/flutter_test.dart';
import 'package:photoshare/models/post.dart';
import 'package:photoshare/util.dart';

Post post(String id, DateTime at) => Post(
    id: id, ownerId: 'o', ownerName: 'Ann', ownerPhoto: null, caption: '', postedAt: at, commentCount: 0, mine: true, photoUrl: 'u', thumbUrl: 't', extension: '.jpg');

void main() {
  final now = DateTime(2026, 10, 22, 12);

  test('headings: day this month, month this year, else year', () {
    expect(groupLabel(DateTime(2026, 10, 21), now), '21 Oct');
    expect(groupLabel(DateTime(2026, 9, 3), now), 'Sep 2026');
    expect(groupLabel(DateTime(2025, 12, 31), now), '2025');
  });

  test('posts are split into consecutive groups', () {
    final groups = groupPosts([
      post('a', DateTime(2026, 10, 22, 9)),
      post('b', DateTime(2026, 10, 22, 8)),
      post('c', DateTime(2026, 10, 21)),
      post('d', DateTime(2025, 1, 1)),
    ], now);
    expect(groups.map((g) => g.$1), ['22 Oct', '21 Oct', '2025']);
    expect(groups.first.$2.map((p) => p.id), ['a', 'b']);
  });

  test('Post.fromJson reads the feed shape', () {
    final p = Post.fromJson({
      'id': 'x', 'path': 'users/u/posts/x.png', 'caption': 'hi', 'postedAt': '2026-10-22T05:00:00.000Z', 'comments': [{}, {}],
      'photoUrl': '/users/u/posts/x.png', 'thumbUrl': '/users/u/posts/x.thumb.webp', 'mine': true,
      'owner': {'userId': 'google-1', 'name': 'Ann', 'photo': null},
    });
    expect([p.ownerId, p.commentCount, p.mine, p.extension], ['google-1', 2, true, '.png']);
    expect(p.photoUrl, endsWith('/users/u/posts/x.png'));
  });
}
