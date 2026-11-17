import 'package:flutter/services.dart';

/// Plays card audio attachments through the Android platform channel.
class CardAudio {
  static const MethodChannel _channel = MethodChannel('oncard/share');
  static void Function()? _onCompleted;
  static bool _handlerInstalled = false;

  /// Register the active study screen for native playback completion events.
  static void setOnCompleted(void Function()? callback) {
    _onCompleted = callback;
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'audioCompleted') {
        _onCompleted?.call();
      }
    });
  }

  static Future<bool> play(String path) async {
    try {
      await _channel.invokeMethod<void>('playAudio', <String, dynamic>{
        'path': path,
      });
      return true;
    } catch (_) {
      // Platform without audio support: ignore.
      return false;
    }
  }

  static Future<bool> pause() async {
    try {
      await _channel.invokeMethod<void>('pauseAudio');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> resume() async {
    try {
      await _channel.invokeMethod<void>('resumeAudio');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stopAudio');
    } catch (_) {
      // ignore
    }
  }
}
