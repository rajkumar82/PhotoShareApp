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
  });

  final String id, ownerId, ownerName, caption, photoUrl, thumbUrl, extension;
  final String? ownerPhoto;
  final DateTime postedAt;
  final int commentCount;
  final bool mine;

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
}
