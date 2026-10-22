import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/post.dart';
import 'api.dart';

/// Saves the photos into the phone's gallery (Pictures/PhotoShare). Returns how many were saved.
Future<int> saveToGallery(Api api, List<Post> posts, {void Function(int done)? onProgress}) async {
  if (!await Gal.hasAccess(toAlbum: true) && !await Gal.requestAccess(toAlbum: true)) {
    throw ApiException('Allow photo access to save pictures to your phone.');
  }
  var done = 0;
  for (final p in posts) {
    final bytes = await api.download(p.photoUrl);
    await Gal.putImageBytes(Uint8List.fromList(bytes), album: 'PhotoShare', name: 'photoshare-${p.id.substring(0, 8)}');
    onProgress?.call(++done);
  }
  return done;
}

final _linkCache = <String, String>{}; // photo ids -> slideshow link already made this session

/// Makes a public slideshow link for the photos (own photos only) and opens the phone's share sheet with a short
/// invitation to try PhotoShare.
Future<void> shareAsSlideshow(Api api, List<Post> posts) async {
  if (posts.any((p) => !p.mine)) throw ApiException('You can only share your own photos.');
  final key = posts.map((p) => p.id).join(',');
  final url = _linkCache[key] ??= await api.createShare(posts);
  final what = posts.length > 1 ? '${posts.length} photos' : 'A photo';
  await SharePlus.instance.share(ShareParams(
    title: 'PhotoShare',
    text: '$what for you on PhotoShare, a simple, private way to share photos with friends and family. Give it a try! $url',
  ));
}
