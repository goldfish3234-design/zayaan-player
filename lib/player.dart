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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  Future<void> _load() async {
    final old = _c;
    _c = null;
    _failed = false;
    _ended = false;
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
    await c.play();
    setState(() => _c = c);
    library.markPlayed(item);
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
      if (_i < widget.items.length - 1) {
        _go(_i + 1);
      } else {
        setState(() => _show = true);
      }
    }
  }

  void _go(int n) {
    if (n < 0 || n >= widget.items.length) return;
    _i = n;
    _load();
  }

  void _kick() {
    _hideTimer?.cancel();
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

  // ───────────── swipe: brightness / volume ─────────────

  void _dragStart(DragStartDetails d) {
    final w = MediaQuery.of(context).size.width;
    _dragLeft = d.localPosition.dx < w / 2;
    if (_dragLeft) {
      Sys.getBrightness().then((v) => _bright = v);
    } else {
      Sys.getVolume().then((v) => _vol = v);
    }
  }

  void _dragUpdate(DragUpdateDetails d) {
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

  // ───────────── subtitles ─────────────

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
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
    _hideTimer?.cancel();
    _hudTimer?.cancel();
    _c?.removeListener(_onTick);
    _c?.dispose();
    Sys.resetBrightness();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  // ───────────── UI ─────────────

  Widget _btn(IconData icon, VoidCallback? onTap, {double size = 36}) {
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
    final hasNext = _i < widget.items.length - 1;
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
                      _item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _btn(Icons.skip_previous_rounded,
                      hasPrev ? () => _go(_i - 1) : null),
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
                            v.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
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
                  _btn(Icons.skip_next_rounded,
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
                                onChanged: (x) => c.seekTo(
                                    Duration(milliseconds: x.round())),
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
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final audio = _item.isAudio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_show && !audio) {
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
                        ? const Text(
                            'This file cannot be played',
                            style: TextStyle(color: Colors.white70),
                          )
                        : const CircularProgressIndicator(color: C.pink))
                    : audio
                        ? const ZMark(size: 170)
                        : AspectRatio(
                            aspectRatio: c.value.aspectRatio,
                            child: VideoPlayer(c),
                          ),
              ),
            ),
            if (_show || _failed) _controls(c),
            if (c != null && _subIdx >= 0) _subtitle(c),
            if (_hudKind != null) _hud(),
          ],
        ),
      ),
    );
  }
}
