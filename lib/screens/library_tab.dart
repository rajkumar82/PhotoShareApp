import 'package:flutter/material.dart';

import '../models/post.dart';
import '../state/library_store.dart';
import '../theme.dart';
import '../widgets/photo_image.dart';
import 'viewer_screen.dart';

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
String monthLabel(String month) => '${_monthNames[int.parse(month.substring(5)) - 1]} ${month.substring(0, 4)}';

/// The library tab: backed-up photos by month, newest first. Months load as they scroll into view.
class LibraryTab extends StatelessWidget {
  const LibraryTab({super.key, required this.library, required this.selected, required this.onToggle, required this.onOpenBackup});
  final LibraryStore library;
  final Set<String> selected;
  final void Function(Post) onToggle;
  final VoidCallback onOpenBackup;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (!library.loadedMonths || library.months.isEmpty) {
      return RefreshIndicator(
        onRefresh: library.refresh,
        child: ListView(padding: const EdgeInsets.all(40), children: [
          if (!library.loadedMonths && library.error == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              library.error ?? 'Your library is empty. Back up your camera folders and every photo will be kept here, privately.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Center(child: FilledButton.icon(onPressed: onOpenBackup, icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Back up photos'))),
          ],
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: library.refresh,
      child: ListView.builder(
        itemCount: library.months.length + 1,
        itemBuilder: (context, i) {
          if (i == library.months.length) return const SizedBox(height: 120);
          final m = library.months[i];
          return _Month(library: library, month: m.month, count: m.count, selected: selected, onToggle: onToggle);
        },
      ),
    );
  }
}

class _Month extends StatefulWidget {
  const _Month({required this.library, required this.month, required this.count, required this.selected, required this.onToggle});
  final LibraryStore library;
  final String month;
  final int count;
  final Set<String> selected;
  final void Function(Post) onToggle;

  @override
  State<_Month> createState() => _MonthState();
}

class _MonthState extends State<_Month> {
  @override
  void initState() {
    super.initState();
    widget.library.loadMonth(widget.month);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final posts = widget.library.photosOf(widget.month);
    final headers = widget.library.api.headers;
    final selecting = widget.selected.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        child: Text('${monthLabel(widget.month)}  ·  ${widget.count}', style: TextStyle(fontWeight: FontWeight.w700, color: c.text)),
      ),
      if (posts == null)
        const SizedBox(height: 90, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 2, crossAxisSpacing: 2),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            final isSel = widget.selected.contains(post.id);
            return GestureDetector(
              onTap: () {
                if (selecting) {
                  widget.onToggle(post);
                } else {
                  final all = widget.library.loaded;
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ViewerScreen(posts: all, index: all.indexWhere((p) => p.id == post.id), api: widget.library.api)));
                }
              },
              onLongPress: () => widget.onToggle(post),
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: isSel ? c.line : c.placeholder),
                AnimatedScale(
                  scale: isSel ? .84 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: ClipRRect(borderRadius: BorderRadius.circular(isSel ? 6 : 0), child: PhotoImage(url: post.thumbUrl, headers: headers)),
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
                        color: isSel ? AppColors.violet : Colors.black26,
                        border: Border.all(color: isSel ? AppColors.violet : Colors.white, width: 2),
                      ),
                      child: isSel ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                    ),
                  ),
                if (post.published)
                  const Positioned(right: 5, bottom: 5, child: Icon(Icons.public, size: 16, color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
              ]),
            );
          },
        ),
    ]);
  }
}
