import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:voyage/ptt_debug_log.dart';

const MethodChannel _channel = MethodChannel('mjtalk.ptt.service');

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

Future<void> startPttService() async {
  if (!_isAndroid) return;

  try {
    await _channel.invokeMethod('startPttService');
  } on PlatformException catch (e) {
    PttLogger.log(
      '[PTT][AndroidPttService]',
      'startPttService error',
      meta: <String, Object?>{
        'error': e.toString(),
      },
    );
  }
}

Future<void> stopPttService() async {
  if (!_isAndroid) return;

  try {
    await _channel.invokeMethod('stopPttService');
  } on PlatformException catch (e) {
    PttLogger.log(
      '[PTT][AndroidPttService]',
      'stopPttService error',
      meta: <String, Object?>{
        'error': e.toString(),
      },
    );
  }
}
