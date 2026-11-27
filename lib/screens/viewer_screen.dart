import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../models/post.dart';
import '../services/actions.dart';
import '../services/api.dart';
import '../util.dart';
import '../widgets/photo_image.dart';

/// Fullscreen photos, one per screen; swipe up/down to move, pinch or double-tap to zoom (and drag to look around while zoomed,
/// then the swipe pages again at normal size). The thumbnail (already cached from the grid) shows straight away while the full
/// photo downloads, and the next few photos are fetched ahead of time.
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
  final _ready = <int>{}; // photos whose full-size version is on screen-ready, so the thumbnail behind can go

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _watch(_current);
      _prefetch(_current);
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  CachedNetworkImageProvider _full(int i) => CachedNetworkImageProvider(widget.posts[i].photoUrl, headers: widget.api.headers, cacheKey: widget.posts[i].photoUrl);

  // note when a photo's full-size version has arrived (at once if it is already cached)
  void _watch(int i) {
    if (_ready.contains(i)) return;
    final stream = _full(i).resolve(createLocalImageConfiguration(context));
    late final ImageStreamListener listener;
    listener = ImageStreamListener((_, _) {
      stream.removeListener(listener);
      if (mounted) setState(() => _ready.add(i));
    }, onError: (_, _) => stream.removeListener(listener));
    stream.addListener(listener);
  }

  void _prefetch(int i) {
    for (var j = i + 1; j <= i + _ahead && j < widget.posts.length; j++) {
      precacheImage(_full(j), context);
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
        // the grid's thumbnail is already on disk, so something sharp-ish is on screen instantly; it goes once the full photo is ready
        if (!_ready.contains(_current)) Positioned.fill(child: PhotoImage(url: post.thumbUrl, headers: widget.api.headers, fit: BoxFit.contain, fadeIn: false)),
        PhotoViewGallery.builder(
          pageController: _pages,
          scrollDirection: Axis.vertical,
          itemCount: widget.posts.length,
          backgroundDecoration: const BoxDecoration(color: Colors.transparent),
          loadingBuilder: (_, _) => const SizedBox.shrink(),
          onPageChanged: (i) {
            setState(() => _current = i);
            _watch(i);
            _prefetch(i);
          },
          builder: (_, i) => PhotoViewGalleryPageOptions(
            imageProvider: _full(i),
            initialScale: PhotoViewComputedScale.contained,
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 5,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
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
