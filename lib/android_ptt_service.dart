import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('mjtalk.ptt.service');

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> startPttService() async {
  if (!_isAndroid) return;

  try {
    await _channel.invokeMethod('startPttService');
  } on PlatformException catch (e) {
    debugPrint(
      '[PTT][AndroidPttService] startPttService error: $e',
    );
  }
}

Future<void> stopPttService() async {
  if (!_isAndroid) return;

  try {
    await _channel.invokeMethod('stopPttService');
  } on PlatformException catch (e) {
    debugPrint(
      '[PTT][AndroidPttService] stopPttService error: $e',
    );
  }
}

