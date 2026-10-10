import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'library.dart';
import 'theme.dart';

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

  @override
  void dispose() {
    _hideTimer?.cancel();
    _c?.removeListener(_onTick);
    _c?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

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
          ],
        ),
      ),
    );
  }
}
