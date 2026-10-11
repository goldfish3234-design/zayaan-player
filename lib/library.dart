import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MediaItem {
  final String id;
  final String title;
  final String folder;
  final int seconds;
  final bool isAudio;
  final int width;
  final int height;
  final AssetEntity? asset;
  final String? path;

  const MediaItem({
    required this.id,
    required this.title,
    required this.folder,
    required this.seconds,
    required this.isAudio,
    this.width = 0,
    this.height = 0,
    this.asset,
    this.path,
  });

  factory MediaItem.fromAsset(AssetEntity a) {
    final rel = (a.relativePath ?? '')
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    return MediaItem(
      id: a.id,
      title: a.title ?? 'Unknown',
      folder: rel.isEmpty ? 'Storage' : rel.last,
      seconds: a.duration,
      isAudio: a.type == AssetType.audio,
      width: a.width,
      height: a.height,
      asset: a,
    );
  }

  String get ext {
    final i = title.lastIndexOf('.');
    if (i < 0 || i == title.length - 1) return isAudio ? 'AUDIO' : 'VIDEO';
    return title.substring(i + 1).toUpperCase();
  }

  /// "4K", "2K", "FHD", "HD" or "SD" for videos (null for audio / unknown).
  String? get quality {
    if (isAudio) return null;
    final m = width > height ? width : height;
    if (m <= 0) return null;
    if (m >= 3800) return '4K';
    if (m >= 2500) return '2K';
    if (m >= 1900) return 'FHD';
    if (m >= 1260) return 'HD';
    return 'SD';
  }
}

class MediaFolder {
  final AssetPathEntity path;
  final String name;
  final int count;
  const MediaFolder(this.path, this.name, this.count);
}

String fmtDur(int seconds) {
  String two(int n) => n.toString().padLeft(2, '0');
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

class Library extends ChangeNotifier {
  bool loading = true;
  bool denied = false;
  bool failed = false;
  bool bgPlay = true;
  List<MediaItem> videos = [];
  List<MediaItem> audios = [];
  List<MediaFolder> folders = [];
  Set<String> favs = {};
  List<String> recents = [];
  // id -> [positionMs, durationMs, lastPlayedAtMs]
  Map<String, List<int>> _pos = {};
  SharedPreferences? _p;
  bool _started = false;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    _p = await SharedPreferences.getInstance();
    favs = (_p!.getStringList('fav') ?? <String>[]).toSet();
    recents = _p!.getStringList('recent') ?? <String>[];
    bgPlay = _p!.getBool('bg_play') ?? true;
    final raw = _p!.getString('pos');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        _pos = m.map(
          (k, v) => MapEntry(
            k,
            (v as List).map((e) => (e as num).toInt()).toList(),
          ),
        );
      } catch (_) {
        _pos = {};
      }
    }
    await scan();
  }

  Future<void> scan() async {
    loading = true;
    denied = false;
    failed = false;
    notifyListeners();
    try {
      final ps = await PhotoManager.requestPermissionExtend(
        requestOption: PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.video | RequestType.audio,
            mediaLocation: false,
          ),
        ),
      );
      if (!(ps.isAuth || ps == PermissionState.limited)) {
        denied = true;
        loading = false;
        notifyListeners();
        return;
      }
      videos = await _loadAll(RequestType.video);
      audios = await _loadAll(RequestType.audio);

      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
      );
      final list = <MediaFolder>[];
      for (final p in paths) {
        if (p.isAll) continue;
        final n = await p.assetCountAsync;
        if (n > 0) list.add(MediaFolder(p, p.name, n));
      }
      list.sort((a, b) => b.count.compareTo(a.count));
      folders = list;
    } catch (_) {
      failed = true;
    }
    loading = false;
    notifyListeners();
  }

  Future<List<MediaItem>> _loadAll(RequestType t) async {
    final paths = await PhotoManager.getAssetPathList(type: t, onlyAll: true);
    if (paths.isEmpty) return [];
    final all = paths.first;
    final n = await all.assetCountAsync;
    if (n == 0) return [];
    final assets = await all.getAssetListRange(start: 0, end: n);
    return assets.map(MediaItem.fromAsset).toList();
  }

  Future<List<MediaItem>> folderItems(MediaFolder f) async {
    final assets = await f.path.getAssetListRange(start: 0, end: f.count);
    return assets.map(MediaItem.fromAsset).toList();
  }

  List<MediaItem> get all => [...videos, ...audios];

  List<MediaItem> get recentItems {
    final map = {for (final m in all) m.id: m};
    return [
      for (final id in recents)
        if (map[id] != null) map[id]!,
    ];
  }

  List<MediaItem> get favItems => [
        for (final m in all)
          if (favs.contains(m.id)) m,
      ];

  /// Videos that were started but not finished, latest first.
  List<MediaItem> get continueItems {
    final map = {for (final m in videos) m.id: m};
    final ids = _pos.keys.where(map.containsKey).toList()
      ..sort((a, b) => _pos[b]![2].compareTo(_pos[a]![2]));
    return [for (final id in ids.take(10)) map[id]!];
  }

  int? positionOf(String id) {
    final v = _pos[id];
    return v == null ? null : v[0];
  }

  double progressOf(String id) {
    final v = _pos[id];
    if (v == null || v[1] <= 0) return 0;
    return (v[0] / v[1]).clamp(0.0, 1.0).toDouble();
  }

  void savePosition(MediaItem m, int posMs, int durMs) {
    if (m.isAudio || durMs <= 0) return;
    if (posMs < 5000 || posMs > durMs * 0.95) {
      _pos.remove(m.id);
    } else {
      _pos[m.id] = [posMs, durMs, DateTime.now().millisecondsSinceEpoch];
    }
    _p?.setString('pos', jsonEncode(_pos));
  }

  void touch() => notifyListeners();

  void setBgPlay(bool v) {
    bgPlay = v;
    _p?.setBool('bg_play', v);
    notifyListeners();
  }

  bool isFav(String id) => favs.contains(id);

  void toggleFav(String id) {
    if (!favs.remove(id)) favs.add(id);
    _p?.setStringList('fav', favs.toList());
    notifyListeners();
  }

  void markPlayed(MediaItem m) {
    recents.remove(m.id);
    recents.insert(0, m.id);
    if (recents.length > 30) recents = recents.sublist(0, 30);
    _p?.setStringList('recent', recents);
    notifyListeners();
  }
}

final library = Library();
