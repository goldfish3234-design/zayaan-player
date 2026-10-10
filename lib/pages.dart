import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'library.dart';
import 'theme.dart';
import 'widgets.dart';

// ───────────────────────── Splash / intro ─────────────────────────

class SplashPage extends StatelessWidget {
  final VoidCallback onStart;
  const SplashPage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF1F2E),
              Color(0xFFFF2D6F),
              Color(0xFF3B1450),
              Color(0xFF0B0F2A),
            ],
            stops: [0.0, 0.35, 0.68, 0.85],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    child: const Center(
                      child: ZMark(size: 170, plate: false),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dot(),
                  const SizedBox(width: 6),
                  _dot(),
                  const SizedBox(width: 6),
                  Container(
                    width: 26,
                    height: 8,
                    decoration: BoxDecoration(
                      color: C.pink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'PLAYER THAT\nPLAY ALL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Best video & music player in the modern era.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: onStart,
                child: Container(
                  width: 170,
                  height: 64,
                  decoration: BoxDecoration(
                    color: C.card,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: const Icon(
                    Icons.north_east_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() => Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      );
}

// ───────────────────────── Shell + bottom nav ─────────────────────────

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    library.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _tab,
            children: const [
              HomeTab(),
              FavTab(),
              VideosTab(),
              ProfileTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _NavBar(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _NavBar({required this.index, required this.onTap});

  static const _off = [
    Icons.home_outlined,
    Icons.favorite_border_rounded,
    Icons.play_arrow_outlined,
    Icons.person_outline_rounded,
  ];
  static const _on = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.play_arrow_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.card,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < 4; i++)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: i == index ? C.brand : null,
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: C.pink.withValues(alpha: 0.45),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      i == index ? _on[i] : _off[i],
                      color: i == index ? Colors.white : Colors.white70,
                      size: 28,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Small shared pieces ─────────────────────────

class _TabTitle extends StatelessWidget {
  final String title;
  const _TabTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
          ),
          const ZMark(size: 34),
        ],
      ),
    );
  }
}

class _PermCard extends StatelessWidget {
  const _PermCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.pink.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Allow access to your media',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'ZAYAAN needs permission to show the videos and music on your phone.',
            style: TextStyle(color: C.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton(
                onPressed: library.scan,
                style: FilledButton.styleFrom(backgroundColor: C.pink),
                child: const Text('Allow'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: PhotoManager.openSetting,
                child: const Text('Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  final String title;
  final Widget child;
  const _PageFrame({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Home ─────────────────────────

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _pickFile(BuildContext context) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (res == null || !context.mounted) return;
    final items = <MediaItem>[
      for (final f in res.files)
        if (f.path != null)
          MediaItem(
            id: f.path!,
            title: f.name,
            folder: 'Picked file',
            seconds: 0,
            isAudio: false,
            path: f.path,
          ),
    ];
    if (items.isEmpty) return;
    openPlayer(context, items, 0);
  }

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.card2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder_open_rounded, color: C.yellow),
              title: const Text('Open a file from storage'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _pickFile(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh_rounded, color: C.blue),
              title: const Text('Rescan library'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                library.scan();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required int count,
    required VoidCallback onTap,
  }) {
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: C.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 30),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count Files',
                style: const TextStyle(color: C.muted, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _folders(BuildContext context) {
    const colors = [
      C.orange,
      C.yellow,
      C.blue,
      C.green,
      Color(0xFFB0B6D6),
      C.pink,
    ];
    final list = library.folders;
    Widget body;
    if (library.loading && list.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(28),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (list.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No video folders found',
            style: TextStyle(color: C.muted),
          ),
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < list.length && i < 8; i++) ...[
            InkWell(
              onTap: () => _open(context, FolderPage(folder: list[i])),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded,
                        size: 40, color: colors[i % colors.length]),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            list[i].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17),
                          ),
                          Text(
                            '${list[i].count} Files',
                            style:
                                const TextStyle(color: C.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.more_horiz_rounded, color: C.muted),
                  ],
                ),
              ),
            ),
            if (i < list.length - 1 && i < 7)
              const Divider(height: 1, indent: 18, endIndent: 18, color: C.line),
          ],
        ],
      );
    }
    return Material(
      color: C.card,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) {
        final recents = library.recentItems.length;
        final favs = library.favItems.length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(
              children: [
                const ZMark(size: 38),
                const SizedBox(width: 10),
                const Text(
                  'ZAYAAN',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 28),
                  onPressed: () => _open(context, const SearchPage()),
                ),
                IconButton(
                  icon: const Icon(Icons.grid_view_rounded, size: 26),
                  onPressed: () => _menu(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (library.denied || library.failed) const _PermCard(),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    context,
                    icon: Icons.history_rounded,
                    color: C.pink,
                    title: 'Recent',
                    count: recents,
                    onTap: () => _open(
                      context,
                      MediaListPage(
                        title: 'Recent',
                        source: () => library.recentItems,
                        empty: 'Nothing played yet',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(
                    context,
                    icon: Icons.favorite_rounded,
                    color: C.yellow,
                    title: 'Favorite',
                    count: favs,
                    onTap: () => _open(
                      context,
                      MediaListPage(
                        title: 'Favorite',
                        source: () => library.favItems,
                        empty: 'No favorites yet',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statTile(
                    context,
                    icon: Icons.music_note_rounded,
                    color: C.blue,
                    title: 'Audio',
                    count: library.audios.length,
                    onTap: () => _open(
                      context,
                      MediaListPage(
                        title: 'Audio',
                        source: () => library.audios,
                        empty: 'No music found on this phone',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statTile(
                    context,
                    icon: Icons.video_library_rounded,
                    color: C.orange,
                    title: 'Video',
                    count: library.videos.length,
                    onTap: () => _open(
                      context,
                      MediaListPage(
                        title: 'Videos',
                        source: () => library.videos,
                        empty: 'No videos found on this phone',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            const Text(
              'Frequently Used',
              style: TextStyle(color: C.muted, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _folders(context),
          ],
        );
      },
    );
  }
}

// ───────────────────────── Other tabs ─────────────────────────

class FavTab extends StatelessWidget {
  const FavTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => Column(
        children: [
          const _TabTitle('Favorite'),
          Expanded(
            child: MediaCard(
              items: library.favItems,
              loading: library.loading,
              empty:
                  'No favorites yet.\nTap the ⋮ menu on a video and choose Add to favorite.',
            ),
          ),
        ],
      ),
    );
  }
}

class VideosTab extends StatelessWidget {
  const VideosTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => Column(
        children: [
          const _TabTitle('Videos'),
          if (library.denied || library.failed) const _PermCard(),
          Expanded(
            child: MediaCard(
              items: library.videos,
              loading: library.loading,
              empty: 'No videos found on this phone',
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Widget _stat(String label, int n) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.line),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: library,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        children: [
          const Center(child: ZMark(size: 110)),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'ZAYAAN',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Center(
            child: Text(
              'Player that plays all',
              style: TextStyle(color: C.muted),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              _stat('Videos', library.videos.length),
              const SizedBox(width: 10),
              _stat('Audio', library.audios.length),
              const SizedBox(width: 10),
              _stat('Favorites', library.favItems.length),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            decoration: BoxDecoration(
              gradient: C.brand,
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              leading: const Icon(Icons.refresh_rounded, color: Colors.white),
              title: const Text(
                'Rescan library',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onTap: library.scan,
            ),
          ),
          const SizedBox(height: 10),
          Material(
            color: C.card,
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: const Icon(Icons.settings_rounded, color: C.muted),
              title: const Text('App permissions'),
              onTap: PhotoManager.openSetting,
            ),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text('Version 1.1.0', style: TextStyle(color: C.muted)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Pushed pages ─────────────────────────

class MediaListPage extends StatelessWidget {
  final String title;
  final List<MediaItem> Function() source;
  final String empty;
  const MediaListPage({
    super.key,
    required this.title,
    required this.source,
    required this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: title,
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) => MediaCard(
          items: source(),
          loading: library.loading,
          empty: empty,
        ),
      ),
    );
  }
}

class FolderPage extends StatefulWidget {
  final MediaFolder folder;
  const FolderPage({super.key, required this.folder});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  List<MediaItem>? _items;

  @override
  void initState() {
    super.initState();
    library.folderItems(widget.folder).then((v) {
      if (mounted) setState(() => _items = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: widget.folder.name,
      child: ListenableBuilder(
        listenable: library,
        builder: (context, _) => MediaCard(
          items: _items ?? const [],
          loading: _items == null,
          empty: 'This folder is empty',
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBg(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        onChanged: (v) =>
                            setState(() => _q = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: 'Search videos & music',
                          filled: true,
                          fillColor: C.card,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: library,
                  builder: (context, _) {
                    final res = _q.isEmpty
                        ? <MediaItem>[]
                        : library.all
                            .where((m) => m.title.toLowerCase().contains(_q))
                            .toList();
                    return MediaCard(
                      items: res,
                      empty: _q.isEmpty ? 'Type to search' : 'Nothing found',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
