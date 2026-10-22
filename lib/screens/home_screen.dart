import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/post.dart';
import '../services/actions.dart';
import '../services/api.dart';
import '../state/feed_store.dart';
import '../state/session.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/photo_image.dart';
import 'viewer_screen.dart';

/// "Me" (my photos) and "Circle" (people I follow) as grids grouped by date. Long-press a photo to start selecting,
/// then tap more; the bar on top downloads them to the phone or shares them as a slideshow link.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)..addListener(_onTab);
  final _picker = ImagePicker();
  final _selected = <String>{};
  bool _busy = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging && _selected.isNotEmpty) setState(_selected.clear);
  }

  void _toggle(Post p) => setState(() => _selected.contains(p.id) ? _selected.remove(p.id) : _selected.add(p.id));

  List<Post> _selectedPosts(FeedStore feed) => [for (final p in feed.posts) if (_selected.contains(p.id)) p];

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
    } catch (e) {
      _say('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(FeedStore feed) async {
    final posts = _selectedPosts(feed);
    setState(_selected.clear);
    await _run(() async {
      final n = await saveToGallery(feed.api, posts, onProgress: (done) => _say('Saving $done of ${posts.length}…'));
      _say(n == 1 ? 'Saved to your gallery.' : 'Saved $n photos to the PhotoShare album.');
    });
  }

  Future<void> _share(FeedStore feed) async {
    final posts = _selectedPosts(feed);
    if (posts.any((p) => !p.mine)) return _say('You can only share your own photos.');
    await _run(() => shareAsSlideshow(feed.api, posts));
    if (mounted) setState(_selected.clear);
  }

  Future<void> _pick(FeedStore feed, {required bool camera}) async {
    final List<XFile> picked;
    if (camera) {
      final one = await _picker.pickImage(source: ImageSource.camera);
      picked = one == null ? [] : [one];
    } else {
      picked = await _picker.pickMultiImage();
    }
    if (picked.isEmpty) return;
    final ok = await feed.upload([for (final f in picked) File(f.path)]);
    if (!mounted) return;
    _tabs.animateTo(0);
    _say(ok == picked.length ? (ok > 1 ? 'Posted $ok photos.' : 'Posted!') : ok > 0 ? 'Posted $ok of ${picked.length} photos.' : 'Could not post. Please try again.');
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedStore>();
    final session = context.read<Session>();
    final selecting = _selected.isNotEmpty;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: selecting ? _selectionBar(feed) : _mainBar(session),
        body: Column(
          children: [
            if (_busy || feed.uploadStatus != null) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _PhotoGrid(feed: feed, posts: feed.mine, selected: _selected, onToggle: _toggle, empty: 'Nothing here yet. Tap the camera button to share your first photo.'),
                  _PhotoGrid(feed: feed, posts: feed.circle, selected: _selected, onToggle: _toggle, empty: 'Nothing from your circle yet. Follow people on the PhotoShare website and their photos will show up here.'),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: selecting
            ? null
            : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                FloatingActionButton.small(
                  heroTag: 'gallery',
                  tooltip: 'Upload photos from your phone',
                  onPressed: feed.uploadStatus == null ? () => _pick(feed, camera: false) : null,
                  child: const Icon(Icons.photo_library_outlined),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'camera',
                  tooltip: 'Take a photo',
                  onPressed: feed.uploadStatus == null ? () => _pick(feed, camera: true) : null,
                  child: const Icon(Icons.photo_camera_outlined),
                ),
              ]),
      ),
    );
  }

  PreferredSizeWidget _selectionBar(FeedStore feed) => AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.barGrad)),
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel selection', onPressed: () => setState(_selected.clear)),
        title: Text('${_selected.length} selected'),
        actions: [
          IconButton(icon: const Icon(Icons.download_outlined), tooltip: 'Save to your phone', onPressed: () => _download(feed)),
          IconButton(icon: const Icon(Icons.share_outlined), tooltip: 'Share as a slideshow', onPressed: () => _share(feed)),
        ],
      );

  PreferredSizeWidget _mainBar(Session session) => AppBar(
        title: const Text('Photoshare', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'out') session.signOut();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Row(children: [
                  Avatar(name: session.me?.name ?? '', photo: session.me?.photo, size: 36),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(session.me?.name ?? 'Signed in', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (session.me?.email != null) Text(session.me!.email!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'out', child: ListTile(leading: Icon(Icons.logout), title: Text('Sign out'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Me'), Tab(text: 'Circle')]),
      );
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.feed, required this.posts, required this.selected, required this.onToggle, required this.empty});
  final FeedStore feed;
  final List<Post> posts;
  final Set<String> selected;
  final void Function(Post) onToggle;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final headers = feed.api.headers;
    final selecting = selected.isNotEmpty;
    return RefreshIndicator(
      onRefresh: feed.load,
      child: posts.isEmpty
          ? ListView(padding: const EdgeInsets.all(40), children: [
              if (feed.loading && feed.posts.isEmpty)
                const Center(child: CircularProgressIndicator())
              else
                Text(feed.error ?? empty, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 15)),
            ])
          : CustomScrollView(slivers: [
              for (final (label, group) in groupPosts(posts)) ...[
                SliverToBoxAdapter(
                  child: Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: c.text))),
                ),
                SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
                  itemCount: group.length,
                  itemBuilder: (context, i) {
                    final post = group[i];
                    final isSel = selected.contains(post.id);
                    return GestureDetector(
                      onTap: () {
                        if (selecting) {
                          onToggle(post);
                        } else {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(posts: posts, index: posts.indexOf(post), api: feed.api)));
                        }
                      },
                      onLongPress: () => onToggle(post),
                      child: _Cell(post: post, headers: headers, selected: isSel, selecting: selecting),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ]),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.post, required this.headers, required this.selected, required this.selecting});
  final Post post;
  final Map<String, String> headers;
  final bool selected, selecting;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: selected ? c.line : c.placeholder),
      AnimatedScale(
        scale: selected ? .84 : 1,
        duration: const Duration(milliseconds: 150),
        child: ClipRRect(borderRadius: BorderRadius.circular(selected ? 6 : 0), child: PhotoImage(url: post.thumbUrl, headers: headers)),
      ),
      if (selecting)
        Positioned(
          left: 6,
          top: 6,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.violet : Colors.black26,
              border: Border.all(color: selected ? AppColors.violet : Colors.white, width: 2),
            ),
            child: selected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
        ),
      if (post.commentCount > 0)
        Positioned(
          right: 5,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
            child: Text('${post.commentCount}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
    ]);
  }
}
