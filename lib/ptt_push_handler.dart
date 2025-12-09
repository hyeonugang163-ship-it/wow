// NOTE: 설계도 v1.1 기준 iOS A안(APNs → 탭 → 포그라운드 → 재생)을
// Flutter 쪽에서 처리하는 PTT Push 핸들러.
//
// 네이티브(AppDelegate.swift)가 "mjtalk.ptt.push" 채널로 전달한 payload를
// 받아 친구 채팅 화면으로 이동하고, 정책(FF.iosModeA_PushTapPlay)에 따라
// 자동 재생 여부를 결정한다. 실제 음성 데이터 전송은 아직 Noop일 수 있다.

import 'package:flutter/services.dart';
import 'package:voyage/app_router.dart';
import 'package:voyage/feature_flags.dart';

const MethodChannel _pttPushChannel = MethodChannel('mjtalk.ptt.push');

class PttPushHandler {
  static bool _initialized = false;

  /// Manual test – iOS A안 PTT Push handling
  ///
  /// 1) iOS에서 AppDelegate가 "handlePttPush" 메서드를 호출하도록
  ///    PTT용 APNs payload를 보낸다.
  /// 2) 이 핸들러가 friendId/pttMode/messageId를 파싱하고,
  ///    해당 friendId의 채팅 화면으로 이동(go_router)한다.
  /// 3) FF.iosModeA_PushTapPlay가 true이고 pttMode가 "walkie"인 경우,
  ///    자동 재생 후보로 로그를 남긴다
  ///    (실제 재생은 전송/스토리지 구현 이후에 연결).
  /// 4) pttMode가 "manner"이거나 정책상 자동 재생이 꺼져 있으면,
  ///    채팅 화면으로만 이동하고 사용자가 직접 재생하도록 둔다.
  static void init() {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _pttPushChannel.setMethodCallHandler((call) async {
      if (call.method != 'handlePttPush') {
        return;
      }

      final raw = call.arguments;
      if (raw is! Map) {
        return;
      }

      final Map<dynamic, dynamic> map = raw;
      final friendId = map['friendId'] as String?;
      final pttMode = map['pttMode'] as String?; // "walkie" / "manner"
      final messageId = map['messageId'] as String?;
      final source = map['source'] as String? ?? 'unknown';

      // 메타데이터 위주 로그 (콘텐츠는 다루지 않는다).
      // ignore: avoid_print
      print(
        '[PTT][Push][iOS] handlePttPush '
        'friendId=${friendId ?? '(none)'} '
        'pttMode=${pttMode ?? '(none)'} '
        'messageId=${messageId ?? '(none)'} '
        'source=$source',
      );

      if (friendId == null || friendId.isEmpty) {
        return;
      }

      // 1:1 채팅 화면으로 이동.
      // go_router의 글로벌 router를 사용해 어디서든 이동 가능.
      final router = tryGetAppRouter();
      if (router == null) {
        return;
      }
      router.go('/chat/$friendId');

      // iOS A안: APNs → 탭 → 포그라운드 → 재생.
      final isWalkie = pttMode == 'walkie';
      if (isWalkie && FF.iosModeA_PushTapPlay) {
        // TODO: 실제 음성 데이터가 준비되면 여기에서
        // PttController의 재생 API를 호출해 자동 재생을 연결한다.
        // 현재는 설계도 요구에 맞춰 메타데이터 로그만 남긴다.
        // ignore: avoid_print
        print(
          '[PTT][Push][iOS] auto-play candidate '
          'friendId=$friendId messageId=${messageId ?? '(none)'}',
        );
      }
    });
  }
}
