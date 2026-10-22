import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/post.dart';
import '../services/actions.dart';
import '../services/api.dart';
import '../util.dart';
import '../widgets/photo_image.dart';

/// Fullscreen photos, one per screen; swipe up/down to move. The thumbnail (already cached from the grid) shows
/// straight away while the full photo downloads, and the next few photos are fetched ahead of time.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.posts, required this.index, required this.api});
  final List<Post> posts;
  final int index;
  final Api api;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  static const _ahead = 3;
  late final PageController _pages = PageController(initialPage: widget.index);
  late int _current = widget.index;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetch(_current));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _prefetch(int i) {
    for (var j = i + 1; j <= i + _ahead && j < widget.posts.length; j++) {
      precacheImage(CachedNetworkImageProvider(widget.posts[j].photoUrl, headers: widget.api.headers, cacheKey: widget.posts[j].photoUrl), context);
    }
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } on ApiException catch (e) {
      _say(e.message);
    } catch (_) {
      _say('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.posts[_current];
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: Row(children: [
          Avatar(name: post.ownerName, photo: post.ownerPhoto, size: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(post.ownerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              Text(formatTime(post.postedAt), style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Save to your phone',
            onPressed: _busy
                ? null
                : () => _run(() async {
                      await saveToGallery(widget.api, [post]);
                      _say('Saved to your gallery.');
                    }),
          ),
          if (post.mine)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Share',
              onPressed: _busy ? null : () => _run(() => shareAsSlideshow(widget.api, [post])),
            ),
        ],
      ),
      body: Stack(children: [
        PageView.builder(
          controller: _pages,
          scrollDirection: Axis.vertical,
          itemCount: widget.posts.length,
          onPageChanged: (i) {
            setState(() => _current = i);
            _prefetch(i);
          },
          itemBuilder: (_, i) => _Slide(post: widget.posts[i], headers: widget.api.headers),
        ),
        if (post.caption.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 28, 16, MediaQuery.of(context).padding.bottom + 14),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0x99000000), Color(0x00000000)])),
                child: Text(post.caption, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
              ),
            ),
          ),
      ]),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({required this.post, required this.headers});
  final Post post;
  final Map<String, String> headers;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // the grid's thumbnail is already on disk, so something sharp-ish is on screen instantly
      PhotoImage(url: post.thumbUrl, headers: headers, fit: BoxFit.contain, fadeIn: false),
      CachedNetworkImage(
        imageUrl: post.photoUrl,
        httpHeaders: headers,
        cacheKey: post.photoUrl,
        fit: BoxFit.contain,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    ]);
  }
}
