import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'library.dart';
import 'player.dart';
import 'system.dart';
import 'theme.dart';

void openPlayer(BuildContext context, List<MediaItem> items, int index) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlayerPage(items: items, index: index)),
  );
}

class Thumb extends StatefulWidget {
  final MediaItem item;
  final double w;
  final double h;
  const Thumb({super.key, required this.item, this.w = 88, this.h = 64});

  @override
  State<Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<Thumb> {
  Future<Uint8List?>? _f;

  @override
  void initState() {
    super.initState();
    final a = widget.item.asset;
    if (widget.item.isAudio) {
      _f = _audioArt();
    } else if (a != null) {
      _f = a.thumbnailDataWithSize(const ThumbnailSize(240, 180));
    }
  }

  Future<Uint8List?> _audioArt() async {
    final it = widget.item;
    String? p = it.path;
    if (p == null) {
      final f = await it.asset?.file;
      p = f?.path;
    }
    if (p == null) return null;
    final m = await Sys.audioMeta(it.id, p);
    return m.art;
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: widget.w,
        height: widget.h,
        child: FutureBuilder<Uint8List?>(
          future: _f,
          builder: (context, snap) {
            final d = snap.data;
            if (d != null) {
              return Image.memory(
                d,
                fit: BoxFit.cover,
                cacheWidth: 240,
                gaplessPlayback: true,
              );
            }
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2A2F6B), Color(0xFF151A3D)],
                ),
              ),
              child: Icon(
                widget.item.isAudio
                    ? Icons.music_note_rounded
                    : Icons.movie_rounded,
                color: Colors.white38,
              ),
            );
          },
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final Color dot;
  final String text;
  const Pill({super.key, required this.dot, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2050),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class MediaTile extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const MediaTile({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fav = library.isFav(item.id);
    final q = item.quality;
    final prog = library.progressOf(item.id);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Thumb(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.folder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: C.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Pill(dot: Colors.white54, text: fmtDur(item.seconds)),
                      Pill(dot: C.pink, text: item.ext),
                      if (q != null) Pill(dot: C.yellow, text: q),
                      if (fav)
                        const Icon(Icons.favorite_rounded,
                            size: 15, color: C.yellow),
                    ],
                  ),
                  if (prog > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: prog,
                        minHeight: 3,
                        color: C.pink,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: C.muted),
              color: C.card2,
              onSelected: (v) {
                if (v == 'fav') {
                  library.toggleFav(item.id);
                } else {
                  onTap();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'play', child: Text('Play')),
                PopupMenuItem(
                  value: 'fav',
                  child: Text(fav ? 'Remove favorite' : 'Add to favorite'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MediaCard extends StatelessWidget {
  final List<MediaItem> items;
  final String empty;
  final bool loading;
  const MediaCard({
    super.key,
    required this.items,
    required this.empty,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading && items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted),
          ),
        ),
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: C.line),
        itemBuilder: (context, i) => MediaTile(
          item: items[i],
          onTap: () => openPlayer(context, items, i),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Material(
        color: C.card,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: body,
      ),
    );
  }
}

/// Small card used in the horizontal "Continue Watching" / "Recently Played"
/// rows on the home screen.
class HCard extends StatelessWidget {
  final MediaItem item;
  final double progress;
  final VoidCallback onTap;
  const HCard({
    super.key,
    required this.item,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Thumb(item: item, w: 150, h: 92),
                if (progress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: C.pink,
                      backgroundColor: Colors.black45,
                    ),
                  ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      fmtDur(item.seconds),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class HSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final bool showProgress;
  const HSection({
    super.key,
    required this.title,
    required this.items,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text(title, style: const TextStyle(color: C.muted, fontSize: 16)),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => HCard(
              item: items[i],
              progress: showProgress ? library.progressOf(items[i].id) : 0,
              onTap: () => openPlayer(context, items, i),
            ),
          ),
        ),
      ],
    );
  }
}
