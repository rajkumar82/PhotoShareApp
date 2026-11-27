import '../config.dart';

/// One photo post as returned by `GET /api/feed`.
class Post {
  Post({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerPhoto,
    required this.caption,
    required this.postedAt,
    required this.commentCount,
    required this.mine,
    required this.photoUrl,
    required this.thumbUrl,
    required this.extension,
    this.published = false,
  });

  final String id, ownerId, ownerName, caption, photoUrl, thumbUrl, extension;
  final String? ownerPhoto;
  final DateTime postedAt;
  final int commentCount;
  final bool mine;
  final bool published; // a library photo that is also on the feed

  factory Post.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'] as Map<String, dynamic>;
    final path = j['path'] as String;
    return Post(
      id: j['id'] as String,
      ownerId: owner['userId'] as String,
      ownerName: (owner['name'] as String?) ?? 'Someone',
      ownerPhoto: owner['photo'] as String?,
      caption: (j['caption'] as String?) ?? '',
      postedAt: DateTime.parse(j['postedAt'] as String).toLocal(),
      commentCount: ((j['comments'] as List?) ?? const []).length,
      mine: j['mine'] == true,
      photoUrl: '$baseUrl${j['photoUrl']}',
      thumbUrl: '$baseUrl${j['thumbUrl']}',
      extension: path.contains('.') ? path.substring(path.lastIndexOf('.')) : '.jpg',
    );
  }

  /// A photo from `GET /api/library?month=...` (always my own; shown with the date it was taken).
  factory Post.fromLibrary(Map<String, dynamic> j, {required String ownerName, String? ownerPhoto}) {
    final url = j['photoUrl'] as String; // /users/<owner>/posts/<id><ext>
    final parts = url.split('/');
    return Post(
      id: j['id'] as String,
      ownerId: parts.length > 2 ? parts[2] : '',
      ownerName: ownerName,
      ownerPhoto: ownerPhoto,
      caption: '',
      postedAt: DateTime.parse(j['takenAt'] as String).toLocal(),
      commentCount: 0,
      mine: true,
      photoUrl: '$baseUrl$url',
      thumbUrl: '$baseUrl${j['thumbUrl']}',
      extension: url.contains('.') ? url.substring(url.lastIndexOf('.')) : '.jpg',
      published: j['published'] == true,
    );
  }
}
