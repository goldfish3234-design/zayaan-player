import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZayaanApp());
}

class ZayaanApp extends StatelessWidget {
  const ZayaanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZAYAAN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0E12),
      ),
      home: const HomePage(),
    );
  }
}

String fmtDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String fmtSize(int bytes) {
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<PlatformFile> _files = [];

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (res == null) return;
    setState(() {
      for (final f in res.files) {
        if (f.path != null) _files.add(f);
      }
    });
  }

  void _play(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerPage(files: List.of(_files), index: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'ZAYAAN',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3),
        ),
        actions: [
          if (_files.isNotEmpty)
            IconButton(
              tooltip: 'Clear list',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => setState(_files.clear),
            ),
        ],
      ),
      body: _files.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle_fill_rounded, size: 96, color: cs.primary),
                  const SizedBox(height: 16),
                  const Text(
                    'No video yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the button below to open a video',
                    style: TextStyle(color: Colors.white60),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              itemCount: _files.length,
              itemBuilder: (context, i) {
                final f = _files[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  color: const Color(0xFF181820),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.movie_rounded, color: cs.primary),
                    ),
                    title: Text(
                      f.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(fmtSize(f.size)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _files.removeAt(i)),
                    ),
                    onTap: () => _play(i),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pick,
        icon: const Icon(Icons.video_library_rounded),
        label: const Text('Open video'),
      ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final List<PlatformFile> files;
  final int index;

  const PlayerPage({super.key, required this.files, required this.index});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late int _i = widget.index;
  VideoPlayerController? _c;
  Timer? _hideTimer;
  bool _show = true;
  bool _land = false;
  bool _failed = false;
  bool _ended = false;
  double _speed = 1.0;
  Offset _tapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  Future<void> _load() async {
    final old = _c;
    _c = null;
    _failed = false;
    _ended = false;
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    old?.removeListener(_onTick);
    await old?.dispose();

    final path = widget.files[_i].path;
    if (path == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final c = VideoPlayerController.file(File(path));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) {
      await c.dispose();
      return;
    }
    c.addListener(_onTick);
    await c.setPlaybackSpeed(_speed);
    await c.play();
    setState(() => _c = c);
    _kick();
  }

  void _onTick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    if (!_ended &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration &&
        !v.isPlaying) {
      _ended = true;
      if (_i < widget.files.length - 1) {
        _go(_i + 1);
      } else {
        setState(() => _show = true);
      }
    }
  }

  void _go(int n) {
    if (n < 0 || n >= widget.files.length) return;
    _i = n;
    _load();
  }

  void _kick() {
    _hideTimer?.cancel();
    if (mounted) setState(() => _show = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && (_c?.value.isPlaying ?? false)) {
        setState(() => _show = false);
      }
    });
  }

  Future<void> _seekBy(int seconds) async {
    final c = _c;
    if (c == null) return;
    final d = c.value.duration;
    var t = c.value.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    if (t > d) t = d;
    await c.seekTo(t);
  }

  void _togglePlay() {
    final c = _c;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
        _ended = false;
      }
      c.play();
    }
    _kick();
  }

  void _rotate() {
    _land = !_land;
    SystemChrome.setPreferredOrientations(
      _land
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp],
    );
    _kick();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c?.removeListener(_onTick);
    _c?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  Widget _centerBtn(IconData icon, VoidCallback? onTap, {double size = 36}) {
    return IconButton(
      iconSize: size,
      color: Colors.white,
      disabledColor: Colors.white24,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  Widget _controls(VideoPlayerController? c) {
    final hasPrev = _i > 0;
    final hasNext = _i < widget.files.length - 1;
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC000000), Color(0x33000000), Color(0xCC000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      widget.files[_i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<double>(
                    tooltip: 'Speed',
                    icon: const Icon(Icons.speed_rounded, color: Colors.white),
                    initialValue: _speed,
                    onSelected: (v) {
                      setState(() => _speed = v);
                      _c?.setPlaybackSpeed(v);
                      _kick();
                    },
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                        .map((s) => PopupMenuItem<double>(
                              value: s,
                              child: Text('${s}x'),
                            ))
                        .toList(),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _centerBtn(Icons.skip_previous_rounded,
                      hasPrev ? () => _go(_i - 1) : null),
                  _centerBtn(Icons.replay_10_rounded, () {
                    _seekBy(-10);
                    _kick();
                  }),
                  if (c != null)
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c,
                      builder: (_, v, __) => _centerBtn(
                        v.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded,
                        _togglePlay,
                        size: 68,
                      ),
                    )
                  else
                    const SizedBox(width: 68, height: 68),
                  _centerBtn(Icons.forward_10_rounded, () {
                    _seekBy(10);
                    _kick();
                  }),
                  _centerBtn(Icons.skip_next_rounded,
                      hasNext ? () => _go(_i + 1) : null),
                ],
              ),
              const Spacer(),
              if (c != null)
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, v, __) {
                    final total = v.duration.inMilliseconds.toDouble();
                    final max = total > 0 ? total : 1.0;
                    final pos = v.position.inMilliseconds
                        .toDouble()
                        .clamp(0.0, max)
                        .toDouble();
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          Text(
                            fmtDuration(v.position),
                            style: const TextStyle(color: Colors.white),
                          ),
                          Expanded(
                            child: Slider(
                              value: pos,
                              max: max,
                              onChangeStart: (_) => _hideTimer?.cancel(),
                              onChanged: (x) =>
                                  c.seekTo(Duration(milliseconds: x.round())),
                              onChangeEnd: (_) => _kick(),
                            ),
                          ),
                          Text(
                            fmtDuration(v.duration),
                            style: const TextStyle(color: Colors.white),
                          ),
                          IconButton(
                            color: Colors.white,
                            icon: Icon(_land
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded),
                            onPressed: _rotate,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_show) {
            setState(() => _show = false);
          } else {
            _kick();
          }
        },
        onDoubleTapDown: (d) => _tapPos = d.localPosition,
        onDoubleTap: () {
          final w = MediaQuery.of(context).size.width;
          _seekBy(_tapPos.dx < w / 2 ? -10 : 10);
          _kick();
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: c == null
                    ? (_failed
                        ? const Text(
                            'This video cannot be played',
                            style: TextStyle(color: Colors.white70),
                          )
                        : const CircularProgressIndicator())
                    : AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: VideoPlayer(c),
                      ),
              ),
            ),
            if (_show) _controls(c),
          ],
        ),
      ),
    );
  }
}
