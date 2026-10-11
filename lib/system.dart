import 'package:flutter/services.dart';

/// Talks to the native side (MainActivity.kt) for screen brightness and
/// media volume.
class Sys {
  static const MethodChannel _ch = MethodChannel('zayaan/system');

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
}
