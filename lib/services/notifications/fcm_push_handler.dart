import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voyage/app/app_router.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/services/notifications/local_notification_service.dart';
import 'package:voyage/services/notifications/push_payload.dart';
import 'package:voyage/features/ptt/data/ptt_prefs.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

Future<PttMode> _loadCurrentPttMode() async {
  try {
    final SharedPreferences prefs =
        await SharedPreferences.getInstance();
    final pttPrefs = PttPrefs(prefs);
    return pttPrefs.loadMode();
  } catch (_) {
    // SharedPreferences 초기화 실패 등은 매너모드로 폴백.
    return PttMode.manner;
  }
}

Future<ChatNotificationStyle>
    _resolveForegroundNotificationStyle() async {
  final mode = await _loadCurrentPttMode();

  // MVP 정책:
  // - 매너모드: 항상 조용한 알림 (silent)
  // - 무전모드: 포그라운드에서도 너무 요란하지 않게 silent
  if (mode == PttMode.walkie) {
    return ChatNotificationStyle.silent;
  }
  return ChatNotificationStyle.silent;
}

Future<ChatNotificationStyle>
    _resolveBackgroundNotificationStyle() async {
  final mode = await _loadCurrentPttMode();

  // MVP 정책:
  // - 매너모드: 조용한 알림 (silent)
  // - 무전모드: 백그라운드/종료 시 소리 나는 알림 (loud)
  if (mode == PttMode.walkie) {
    return ChatNotificationStyle.loud;
  }
  return ChatNotificationStyle.silent;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  PttLogger.logConsoleOnly(
    '[Push][FCM]',
    'background isolate raw message received',
    meta: <String, Object?>{
      'hasNotification': message.notification != null,
      'dataKeys': message.data.length,
    },
  );

  // NOTE: Background isolate에서는 Firebase를 다시 초기화해야 한다.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // 이미 초기화된 경우 등은 무시.
  }

  final PushPayload payload =
      PushPayload.fromRemoteMessage(message);
  if (!payload.isValid) {
    return;
  }

  PttLogger.log(
    '[Push][FCM]',
    'background message',
    meta: <String, Object?>{
      'type': payload.type,
      'chatIdHash': payload.chatId.hashCode,
      'hasNotification': message.notification != null,
    },
  );

  await LocalNotificationService.initialize();
  final style =
      await _resolveBackgroundNotificationStyle();
  await LocalNotificationService.showChatNotification(
    payload,
    style: style,
  );
}

class FcmPushHandler {
  FcmPushHandler._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    if (!Platform.isAndroid) {
      // 현재 단계에서는 Android 위주로만 처리한다.
      return;
    }

    final FirebaseMessaging messaging =
        FirebaseMessaging.instance;

    final NotificationSettings settings =
        await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    PttLogger.logConsoleOnly(
      '[Push][FCM]',
      'permission',
      meta: <String, Object?>{
        'authorizationStatus':
            settings.authorizationStatus.name,
      },
    );

    // 앱 실행 시점에 디버그 로그로 FCM 토큰을 한 번 남겨둔다.
    try {
      final String? token = await messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] token=$token');
      } else {
        debugPrint('[FCM] token is null');
      }
    } catch (e, st) {
      debugPrint('[FCM] getToken error: $e');
      debugPrint(st.toString());
    }

    FirebaseMessaging.onMessage.listen(_handleOnMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOnMessageOpenedApp,
    );

    final RemoteMessage? initialMessage =
        await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNavigation(
        PushPayload.fromRemoteMessage(initialMessage),
      );
    }
  }

  static Future<void> _handleOnMessage(
    RemoteMessage message,
  ) async {
    PttLogger.logConsoleOnly(
      '[Push][FCM]',
      'foreground raw message received',
      meta: <String, Object?>{
        'hasNotification': message.notification != null,
        'dataKeys': message.data.length,
      },
    );

    final PushPayload payload =
        PushPayload.fromRemoteMessage(message);
    if (!payload.isValid) {
      return;
    }
    PttLogger.log(
      '[Push][FCM]',
      'foreground message',
      meta: <String, Object?>{
        'type': payload.type,
        'chatIdHash': payload.chatId.hashCode,
        'hasNotification': message.notification != null,
      },
    );
    final style =
        await _resolveForegroundNotificationStyle();
    await LocalNotificationService.showChatNotification(
      payload,
      style: style,
    );
  }

  static void _handleOnMessageOpenedApp(
    RemoteMessage message,
  ) {
    PttLogger.logConsoleOnly(
      '[Push][FCM]',
      'message opened from system UI',
      meta: <String, Object?>{
        'hasNotification': message.notification != null,
        'dataKeys': message.data.length,
      },
    );

    final PushPayload payload =
        PushPayload.fromRemoteMessage(message);
    _handleNavigation(payload);
  }

  static void _handleNavigation(PushPayload payload) {
    if (!payload.isValid) {
      return;
    }
    final router = tryGetAppRouter();
    if (router == null) {
      return;
    }
    router.go('/chat/${payload.chatId}');
  }
}
