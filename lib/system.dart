import 'dart:typed_data';

import 'package:flutter/services.dart';

class AudioMeta {
  final Uint8List? art;
  final String? title;
  final String? artist;
  final String? album;
  const AudioMeta({this.art, this.title, this.artist, this.album});
}

/// Talks to the native side (MainActivity.kt) for screen brightness, media
/// volume, the background-playback service and audio metadata / album art.
class Sys {
  static const MethodChannel _ch = MethodChannel('zayaan/system');
  static final Map<String, AudioMeta> _meta = {};

  static Future<double> getVolume() async {
    try {
      return (await _ch.invokeMethod<double>('getVolume')) ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setVolume(double v) async {
    try {
      await _ch.invokeMethod<void>('setVolume', {'value': v});
    } catch (_) {}
  }

  static Future<double> getBrightness() async {
    try {
      return (await _ch.invokeMethod<double>('getBrightness')) ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> setBrightness(double v) async {
    try {
      await _ch.invokeMethod<void>('setBrightness', {'value': v});
    } catch (_) {}
  }

  static Future<void> resetBrightness() async {
    try {
      await _ch.invokeMethod<void>('resetBrightness');
    } catch (_) {}
  }

  static Future<void> startService(String title) async {
    try {
      await _ch.invokeMethod<void>('startService', {'title': title});
    } catch (_) {}
  }

  static Future<void> stopService() async {
    try {
      await _ch.invokeMethod<void>('stopService');
    } catch (_) {}
  }

  static Future<void> notifPerm() async {
    try {
      await _ch.invokeMethod<void>('notifPerm');
    } catch (_) {}
  }

  /// Reads embedded album art, title, artist and album from an audio file.
  static Future<AudioMeta> audioMeta(String key, String path) async {
    final cached = _meta[key];
    if (cached != null) return cached;
    var m = const AudioMeta();
    try {
      final r = await _ch.invokeMapMethod<String, dynamic>(
        'audioMeta',
        {'path': path},
      );
      if (r != null) {
        m = AudioMeta(
          art: r['art'] as Uint8List?,
          title: r['title'] as String?,
          artist: r['artist'] as String?,
          album: r['album'] as String?,
        );
      }
    } catch (_) {}
    if (_meta.length > 60) _meta.remove(_meta.keys.first);
    _meta[key] = m;
    return m;
  }
}
