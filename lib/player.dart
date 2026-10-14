import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'library.dart';
import 'system.dart';
import 'theme.dart';

class _Sub {
  final String name;
  final String text;
  final bool vtt;
  const _Sub(this.name, this.text, this.vtt);
}

class PlayerPage extends StatefulWidget {
  final List<MediaItem> items;
  final int index;

  const PlayerPage({super.key, required this.items, required this.index});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> with WidgetsBindingObserver {
  static bool _askedNotif = false;

  late int _i = widget.index;
  VideoPlayerController? _c;
  Timer? _hideTimer;
  Timer? _saveTimer;
  bool _show = true;
  bool _land = false;
  bool _failed = false;
  bool _ended = false;
  double _speed = 1.0;
  Offset _tapPos = Offset.zero;

  // pinch zoom (two fingers, 1x to 4x) with two-finger pan
  final Map<int, Offset> _ptrs = {};
  double _zoom = 1.0;
  double _zoomBase = 1.0;
  double _pinchStart = 0;
  Offset _pan = Offset.zero;

  // aspect ratio: 0 original, 1 fill (crop), 2 stretch
  int _fit = 0;

  // sleep timer (minutes, 0 = off)
  Timer? _sleepTimer;
  int _sleepMin = 0;

  // A-B repeat
  Duration? _loopA;
  Duration? _loopB;

  // screen lock
  bool _locked = false;
  bool _lockHint = false;
  Timer? _lockTimer;

  // audio (album art + tags)
  AudioMeta? _meta;

  // subtitles
  final List<_Sub> _subs = [];
  int _subIdx = -1;
  double _subDelay = 0.0;
  double _subSize = 20;

  // swipe gestures (brightness on the left, volume on the right)
  bool _dragLeft = false;
  double _bright = 0.5;
  double _vol = 0.5;
  String? _hudKind;
  double _hudVal = 0;
  Timer? _hudTimer;

  MediaItem get _item => widget.items[_i];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _saveTimer = Timer.periodic(const Duration(seconds: 5), (_) => _savePos());
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _savePos();
      if (!library.bgPlay) _c?.pause();
    }
  }

  void _savePos() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    library.savePosition(
      _item,
      c.value.position.inMilliseconds,
      c.value.duration.inMilliseconds,
    );
  }

  Future<void> _load() async {
    final old = _c;
    _c = null;
    _failed = false;
    _ended = false;
    _zoom = 1.0;
    _pan = Offset.zero;
    _loopA = null;
    _loopB = null;
    _meta = null;
    _subs.clear();
    _subIdx = -1;
    _subDelay = 0.0;
    if (mounted) setState(() {});
    await WidgetsBinding.instance.endOfFrame;
    old?.removeListener(_onTick);
    await old?.dispose();

    final item = _item;
    File? file;
    try {
      if (item.path != null) {
        file = File(item.path!);
      } else {
        file = await item.asset?.file;
      }
    } catch (_) {
      file = null;
    }
    if (file == null) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (item.isAudio) {
      Sys.audioMeta(item.id, file.path).then((m) {
        if (mounted && _item.id == item.id) setState(() => _meta = m);
      });
    }
    final c = VideoPlayerController.file(file);
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

    // Continue watching: jump back to where the viewer stopped.
    int? resumed;
    final saved = library.positionOf(item.id);
    if (saved != null && !item.isAudio) {
      await c.seekTo(Duration(milliseconds: saved));
      resumed = saved;
    }
    await c.play();
    setState(() => _c = c);
    library.markPlayed(item);

    if (library.bgPlay) {
      if (!_askedNotif) {
        _askedNotif = true;
        Sys.notifPerm();
      }
      Sys.startService(item.title);
    }
    if (resumed != null) _resumeToast(resumed);
    _kick();
  }

  void _resumeToast(int ms) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('Resumed from ${fmtDur(ms ~/ 1000)}'),
        action: SnackBarAction(
          label: 'Start over',
          textColor: C.pink,
          onPressed: () => _c?.seekTo(Duration.zero),
        ),
      ),
    );
  }

  void _onTick() {
    final c = _c;
    if (c == null || !mounted) return;
    final v = c.value;
    // A-B repeat: jump back to A when playback reaches B
    final a = _loopA;
    final b = _loopB;
    if (a != null && b != null && v.isPlaying && v.position >= b) {
      c.seekTo(a);
      return;
    }
    if (!_ended &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration &&
        !v.isPlaying) {
      _ended = true;
      if (_i < widget.items.length - 1) {
        _go(_i + 1);
      } else {
        setState(() => _show = true);
      }
    }
  }

  void _go(int n) {
    if (n < 0 || n >= widget.items.length) return;
    _savePos();
    _i = n;
    _load();
  }

  void _kick() {
    _hideTimer?.cancel();
    if (_locked) return;
    if (mounted) setState(() => _show = true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_item.isAudio && (_c?.value.isPlaying ?? false)) {
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

  // ──────────── pinch zoom + pan ────────────

  double _pinchDist() {
    final v = _ptrs.values.toList();
    return (v[0] - v[1]).distance;
  }

  void _onPtrDown(PointerDownEvent e) {
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length == 2) {
      _pinchStart = _pinchDist();
      _zoomBase = _zoom;
    }
  }

  void _onPtrMove(PointerMoveEvent e) {
    if (!_ptrs.containsKey(e.pointer)) return;
    _ptrs[e.pointer] = e.localPosition;
    if (_ptrs.length != 2 || _pinchStart <= 0) return;
    final z = (_zoomBase * _pinchDist() / _pinchStart).clamp(1.0, 4.0).toDouble();
    // both fingers moving together pan the zoomed video
    final size = MediaQuery.of(context).size;
    final dx = _pan.dx + e.localDelta.dx / 2;
    final dy = _pan.dy + e.localDelta.dy / 2;
    final maxX = (z - 1) * size.width / 2;
    final maxY = (z - 1) * size.height / 2;
    setState(() {
      _zoom = z;
      _pan = Offset(dx.clamp(-maxX, maxX).toDouble(), dy.clamp(-maxY, maxY).toDouble());
    });
  }

  void _onPtrUp(PointerEvent e) {
    _ptrs.remove(e.pointer);
    if (_ptrs.length < 2) _pinchStart = 0;
  }

  void _resetZoom() {
    setState(() {
      _zoom = 1.0;
      _pan = Offset.zero;
    });
  }

  // ──────────── sleep timer ────────────

  void _setSleep(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (minutes > 0) {
      _sleepTimer = Timer(Duration(minutes: minutes), () {
        _c?.pause();
        if (!mounted) return;
        setState(() => _sleepMin = 0);
        _msg('Sleep timer: playback paused');
      });
      _msg('Sleep timer set for $minutes minutes');
    } else {
      _msg('Sleep timer off');
    }
    setState(() => _sleepMin = minutes);
  }

  // ──────────── A-B repeat ────────────

  void _abTap() {
    final c = _c;
    if (c == null) return;
    final p = c.value.position;
    if (_loopA == null) {
      setState(() => _loopA = p);
      _msg('A set. Tap again to set B');
    } else if (_loopB == null) {
      if (p <= _loopA!) {
        _msg('B must be after A');
        return;
      }
      setState(() => _loopB = p);
      _msg('A-B repeat on');
    } else {
      setState(() {
        _loopA = null;
        _loopB = null;
      });
      _msg('A-B repeat off');
    }
    _kick();
  }

  // ──────────── screen lock ────────────

  void _lock() {
    _hideTimer?.cancel();
    setState(() {
      _locked = true;
      _show = false;
    });
    _flashLock();
  }

  void _unlock() {
    _lockTimer?.cancel();
    setState(() {
      _locked = false;
      _lockHint = false;
    });
    _kick();
  }

  void _flashLock() {
    _lockTimer?.cancel();
    setState(() => _lockHint = true);
    _lockTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _lockHint = false);
    });
  }

  // ──────────── swipe: brightness / volume ────────────

  void _dragStart(DragStartDetails d) {
    if (_locked || _ptrs.length > 1) return;
    final w = MediaQuery.of(context).size.width;
    _dragLeft = d.localPosition.dx < w / 2;
    if (_dragLeft) {
      Sys.getBrightness().then((v) => _bright = v);
    } else {
      Sys.getVolume().then((v) => _vol = v);
    }
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (_locked || _ptrs.length > 1) return;
    final h = MediaQuery.of(context).size.height;
    final delta = -d.delta.dy / (h * 0.7);
    if (_dragLeft) {
      _bright = (_bright + delta).clamp(0.02, 1.0).toDouble();
      Sys.setBrightness(_bright);
      _showHud('b', _bright);
    } else {
      _vol = (_vol + delta).clamp(0.0, 1.0).toDouble();
      Sys.setVolume(_vol);
      _showHud('v', _vol);
    }
  }

  void _dragEnd() {
    _hudTimer?.cancel();
    _hudTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _hudKind = null);
    });
  }

  void _showHud(String kind, double v) {
    _hudTimer?.cancel();
    setState(() {
      _hudKind = kind;
      _hudVal = v;
    });
  }

  // ──────────── subtitles ────────────

  String _decode(List<int> b) {
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) {
      final units = <int>[];
      for (var i = 2; i + 1 < b.length; i += 2) {
        units.add(b[i] | (b[i + 1] << 8));
      }
      return String.fromCharCodes(units);
    }
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) {
      final units = <int>[];
      for (var i = 2; i + 1 < b.length; i += 2) {
        units.add((b[i] << 8) | b[i + 1]);
      }
      return String.fromCharCodes(units);
    }
    var s = utf8.decode(b, allowMalformed: true);
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) s = s.substring(1);
    return s;
  }

  void _msg(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _addSub() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    final lower = f.name.toLowerCase();
    if (!(lower.endsWith('.srt') || lower.endsWith('.vtt'))) {
      _msg('Please choose a .srt or .vtt subtitle file');
      return;
    }
    List<int>? bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) {
      _msg('Could not read this file');
      return;
    }
    final text = _decode(bytes);
    final isVtt = lower.endsWith('.vtt') || text.trimLeft().startsWith('WEBVTT');
    setState(() => _subs.add(_Sub(f.name, text, isVtt)));
    await _selectSub(_subs.length - 1);
  }

  Future<void> _selectSub(int i) async {
    final c = _c;
    if (c == null) return;
    if (i < 0) {
      await c.setClosedCaptionFile(null);
      if (mounted) setState(() => _subIdx = -1);
      return;
    }
    final s = _subs[i];
    final ClosedCaptionFile file =
        s.vtt ? WebVTTCaptionFile(s.text) : SubRipCaptionFile(s.text);
    await c.setClosedCaptionFile(Future<ClosedCaptionFile>.value(file));
    c.setCaptionOffset(Duration(milliseconds: (_subDelay * 1000).round()));
    if (mounted) setState(() => _subIdx = i);
  }

  void _setDelay(double d) {
    _subDelay = d;
    _c?.setCaptionOffset(Duration(milliseconds: (_subDelay * 1000).round()));
    setState(() {});
  }

  void _subSheet() {
    _hideTimer?.cancel();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.card2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subtitles',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.subtitles_off_rounded),
                  title: const Text('Off'),
                  trailing: _subIdx == -1
                      ? const Icon(Icons.check_circle_rounded, color: C.pink)
                      : null,
                  onTap: () async {
                    await _selectSub(-1);
                    setS(() {});
                  },
                ),
                for (var i = 0; i < _subs.length; i++)
                  ListTile(
                    leading: const Icon(Icons.subtitles_rounded),
                    title: Text(
                      _subs[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _subIdx == i
                        ? const Icon(Icons.check_circle_rounded, color: C.pink)
                        : null,
                    onTap: () async {
                      await _selectSub(i);
                      setS(() {});
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.add_circle_rounded, color: C.pink),
                  title: const Text('Add subtitle file (.srt / .vtt)'),
                  subtitle: const Text(
                    'Any language. Add as many as you like and switch.',
                    style: TextStyle(color: C.muted, fontSize: 12),
                  ),
                  onTap: () async {
                    await _addSub();
                    setS(() {});
                  },
                ),
                const Divider(color: C.line),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Sync (delay)')),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () {
                          _setDelay(
                              double.parse((_subDelay - 0.5).toStringAsFixed(1)));
                          setS(() {});
                        },
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          '${_subDelay >= 0 ? '+' : ''}${_subDelay.toStringAsFixed(1)}s',
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () {
                          _setDelay(
                              double.parse((_subDelay + 0.5).toStringAsFixed(1)));
                          setS(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Text size')),
                      for (final e in const [
                        ['S', 15.0],
                        ['M', 20.0],
                        ['L', 26.0],
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            label: Text(e[0] as String),
                            selected: _subSize == (e[1] as double),
                            selectedColor: C.pink,
                            onSelected: (_) {
                              setState(() => _subSize = e[1] as double);
                              setS(() {});
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) _kick();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _lockTimer?.cancel();
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _savePos();
    _c?.removeListener(_onTick);
    _c?.dispose();
    Sys.stopService();
    Sys.resetBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    // refresh "Continue Watching" on the home screen once this page is gone
    WidgetsBinding.instance.addPostFrameCallback((_) => library.touch());
    super.dispose();
  }

  // ──────────── UI ────────────

  Widget _btn(IconData icon, VoidCallback? onTap, {double size = 36}) {
    return IconButton(
      iconSize: size,
      color: Colors.white,
      disabledColor: Colors.white24,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  String? _videoInfo(VideoPlayerController? c) {
    if (c == null || _item.isAudio || !c.value.isInitialized) return null;
    final s = c.value.size;
    if (s.width <= 0 || s.height <= 0) return null;
    final m = s.width > s.height ? s.width : s.height;
    final q = m >= 3800
        ? '4K'
        : m >= 2500
            ? '2K'
            : m >= 1900
                ? 'FHD'
                : m >= 1260
                    ? 'HD'
                    : 'SD';
    return '${s.width.toInt()}×${s.height.toInt()} · $q';
  }

  Widget _topRow(VideoPlayerController? c) {
    final info = _videoInfo(c);
    return Row(
      children: [
        IconButton(
          color: Colors.white,
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (info != null)
                Text(
                  info,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Lock screen',
          color: Colors.white,
          icon: const Icon(Icons.lock_open_rounded),
          onPressed: _lock,
        ),
        IconButton(
          tooltip: 'Subtitles',
          color: _subIdx >= 0 ? C.pink : Colors.white,
          icon: Icon(_subIdx >= 0
              ? Icons.subtitles_rounded
              : Icons.subtitles_outlined),
          onPressed: c == null ? null : _subSheet,
        ),
        PopupMenuButton<double>(
          tooltip: 'Speed',
          color: C.card2,
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
    );
  }

  // second row: sleep timer, A-B repeat, aspect ratio
  Widget _extraRow(VideoPlayerController c) {
    final abOn = _loopA != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PopupMenuButton<int>(
          tooltip: 'Sleep timer',
          color: C.card2,
          icon: Icon(
            Icons.bedtime_rounded,
            color: _sleepMin > 0 ? C.pink : Colors.white,
          ),
          onSelected: _setSleep,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('Off')),
            PopupMenuItem(value: 15, child: Text('15 minutes')),
            PopupMenuItem(value: 30, child: Text('30 minutes')),
            PopupMenuItem(value: 45, child: Text('45 minutes')),
            PopupMenuItem(value: 60, child: Text('60 minutes')),
          ],
        ),
        IconButton(
          tooltip: 'A-B repeat',
          color: abOn ? C.pink : Colors.white,
          icon: Icon(Icons.repeat_rounded),
          onPressed: _abTap,
        ),
        if (!_item.isAudio)
          PopupMenuButton<int>(
            tooltip: 'Aspect ratio',
            color: C.card2,
            icon: Icon(
              Icons.aspect_ratio_rounded,
              color: _fit != 0 ? C.pink : Colors.white,
            ),
            initialValue: _fit,
            onSelected: (v) {
              setState(() => _fit = v);
              _kick();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Original')),
              PopupMenuItem(value: 1, child: Text('Fill (crop)')),
              PopupMenuItem(value: 2, child: Text('Stretch')),
            ],
          ),
      ],
    );
  }

  Widget _playRow(VideoPlayerController? c) {
    final hasPrev = _i > 0;
    final hasNext = _i < widget.items.length - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn(Icons.skip_previous_rounded, hasPrev ? () => _go(_i - 1) : null),
        _btn(Icons.replay_10_rounded, () {
          _seekBy(-10);
          _kick();
        }),
        if (c != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (_, v, __) => GestureDetector(
              onTap: _togglePlay,
              child: Container(
                width: 68,
                height: 68,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  gradient: C.brand,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: C.pink.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 84, height: 68),
        _btn(Icons.forward_10_rounded, () {
          _seekBy(10);
          _kick();
        }),
        _btn(Icons.skip_next_rounded, hasNext ? () => _go(_i + 1) : null),
      ],
    );
  }

  Widget _sliderRow(VideoPlayerController c) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: c,
      builder: (_, v, __) {
        final total = v.duration.inMilliseconds.toDouble();
        final max = total > 0 ? total : 1.0;
        final pos =
            v.position.inMilliseconds.toDouble().clamp(0.0, max).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Text(
                fmtDur(v.position.inSeconds),
                style: const TextStyle(color: Colors.white),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: C.pink,
                    thumbColor: C.pink,
                    inactiveTrackColor: Colors.white24,
                    overlayColor: C.pink.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: pos,
                    max: max,
                    onChangeStart: (_) => _hideTimer?.cancel(),
                    onChanged: (x) =>
                        c.seekTo(Duration(milliseconds: x.round())),
                    onChangeEnd: (_) => _kick(),
                  ),
                ),
              ),
              Text(
                fmtDur(v.duration.inSeconds),
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
    );
  }

  Widget _controls(VideoPlayerController? c) {
    final audio = _item.isAudio;
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: audio
                ? const [Color(0x66000000), Color(0x00000000), Color(0x99000000)]
                : const [Color(0xCC000000), Color(0x33000000), Color(0xCC000000)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topRow(c),
              const Spacer(),
              _playRow(c),
              if (!audio) const Spacer(),
              if (c != null) _extraRow(c),
              if (c != null) _sliderRow(c),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _audioView() {
    final m = _meta;
    final art = m?.art;
    final title = (m?.title != null && m!.title!.isNotEmpty)
        ? m.title!
        : _item.title;
    final sub = [
      if (m?.artist != null && m!.artist!.isNotEmpty) m.artist!,
      if (m?.album != null && m!.album!.isNotEmpty) m.album!,
    ].join(' · ');
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: C.pink.withValues(alpha: 0.35),
                  blurRadius: 40,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: art != null
                  ? Image.memory(art, fit: BoxFit.cover, gaplessPlayback: true)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1B1250), Color(0xFF070A1F)],
                        ),
                      ),
                      child: const Center(child: ZMark(size: 170, plate: false)),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: C.muted, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _videoBox(VideoPlayerController c) {
    switch (_fit) {
      case 1:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: c.value.size.width,
              height: c.value.size.height,
              child: VideoPlayer(c),
            ),
          ),
        );
      case 2:
        return SizedBox.expand(child: VideoPlayer(c));
      default:
        return AspectRatio(
          aspectRatio: c.value.aspectRatio,
          child: VideoPlayer(c),
        );
    }
  }

  Widget _subtitle(VideoPlayerController c) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: _show ? 120 : 36,
      child: IgnorePointer(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, v, __) {
            final t = v.caption.text;
            if (t.isEmpty) return const SizedBox.shrink();
            return Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x99000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  t,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _subSize,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hud() {
    final isB = _hudKind == 'b';
    final val = _hudVal.clamp(0.0, 1.0).toDouble();
    final IconData icon = isB
        ? Icons.brightness_6_rounded
        : (val <= 0
            ? Icons.volume_off_rounded
            : (val < 0.5
                ? Icons.volume_down_rounded
                : Icons.volume_up_rounded));
    return Positioned(
      top: 0,
      bottom: 0,
      left: isB ? 28 : null,
      right: isB ? null : 28,
      child: Center(
        child: IgnorePointer(
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xB3000000),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(height: 10),
                SizedBox(
                  width: 6,
                  height: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: val,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: C.brand,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${(val * 100).round()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lockOverlay() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 24,
      child: Center(
        child: GestureDetector(
          onTap: _unlock,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xB3000000),
              shape: BoxShape.circle,
              border: Border.all(color: C.pink, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, color: C.pink, size: 30),
                SizedBox(height: 4),
                Text(
                  'Unlock',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final audio = _item.isAudio;
    return PopScope(
      canPop: !_locked,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Listener(
          onPointerDown: _onPtrDown,
          onPointerMove: _onPtrMove,
          onPointerUp: _onPtrUp,
          onPointerCancel: _onPtrUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_locked) {
                _flashLock();
                return;
              }
              if (_show && !audio) {
                setState(() => _show = false);
              } else {
                _kick();
              }
            },
            onDoubleTapDown: (d) => _tapPos = d.localPosition,
            onDoubleTap: () {
              if (_locked) return;
              // zoomed in: double-tap goes back to normal size
              if (_zoom > 1.0) {
                _resetZoom();
                return;
              }
              final w = MediaQuery.of(context).size.width;
              _seekBy(_tapPos.dx < w / 2 ? -10 : 10);
              _kick();
            },
            onVerticalDragStart: _dragStart,
            onVerticalDragUpdate: _dragUpdate,
            onVerticalDragEnd: (_) => _dragEnd(),
            onVerticalDragCancel: _dragEnd,
            child: Stack(
              children: [
                if (audio)
                  const Positioned.fill(child: GradientBg(child: SizedBox())),
                Positioned.fill(
                  child: Center(
                    child: c == null
                        ? (_failed
                            ? const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'This file cannot be played on your phone.\nThe format or codec may not be supported.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70),
                                ),
                              )
                            : const CircularProgressIndicator(color: C.pink))
                        : audio
                            ? const SizedBox.shrink()
                            : ClipRect(
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.identity()
                                    ..translate(_pan.dx, _pan.dy)
                                    ..scale(_zoom),
                                  child: _videoBox(c),
                                ),
                              ),
                  ),
                ),
                if (audio && c != null)
                  Positioned(
                    top: 90,
                    left: 16,
                    right: 16,
                    bottom: 190,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _audioView(),
                    ),
                  ),
                if ((_show || _failed) && !_locked) _controls(c),
                if (c != null && _subIdx >= 0) _subtitle(c),
                if (_hudKind != null && !_locked) _hud(),
                if (_locked && _lockHint) _lockOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
