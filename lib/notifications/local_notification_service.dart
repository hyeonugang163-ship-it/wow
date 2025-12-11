import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:voyage/app_router.dart';
import 'package:voyage/notifications/push_payload.dart';
import 'package:voyage/ptt_debug_log.dart';

/// 채팅/무전 알림 스타일.
///
/// - loud  : 소리 + 진동 (채널: chat_ptt_loud)
/// - silent: 무음 + 진동/배너만 (채널: chat_ptt_silent)
enum ChatNotificationStyle {
  loud,
  silent,
}

/// Thin wrapper around flutter_local_notifications for chat/PTT pushes.
class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Android 채널 정의 – 소리 있음 / 조용한 채널을 분리해 둔다.
  //
  // NOTE:
  // - 실제 DND(방해 금지 모드) 동작과 "허용된 대화/연락처" 예외 처리는
  //   OS + 사용자의 시스템 설정이 관리한다.
  // - 여기서는 별도의 DND 우회/야간무음/급한무전 로직을 넣지 않는다.
  static const String _channelIdLoud = 'chat_ptt_loud';
  static const String _channelNameLoud =
      '채팅/무전 알림 (소리 있음)';
  static const String _channelDescLoud =
      '채팅 및 PTT 메시지 알림 (소리/진동)';

  static const String _channelIdSilent = 'chat_ptt_silent';
  static const String _channelNameSilent =
      '채팅/무전 알림 (무음)';
  static const String _channelDescSilent =
      '조용한 채팅 및 PTT 알림';

  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(
      android: androidInit,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse:
          _onDidReceiveNotificationResponse,
    );

    // Android 알림 채널을 명시적으로 생성해 둔다.
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const loudChannel = AndroidNotificationChannel(
        _channelIdLoud,
        _channelNameLoud,
        description: _channelDescLoud,
        importance: Importance.high,
      );

      const silentChannel = AndroidNotificationChannel(
        _channelIdSilent,
        _channelNameSilent,
        description: _channelDescSilent,
        importance: Importance.defaultImportance,
      );

      await androidPlugin?.createNotificationChannel(
        loudChannel,
      );
      await androidPlugin?.createNotificationChannel(
        silentChannel,
      );
    }
  }

  static void _onDidReceiveNotificationResponse(
    NotificationResponse response,
  ) {
    final String? payload = response.payload;
    if (payload == null || payload.isEmpty) {
      return;
    }
    _handleNotificationPayload(payload);
  }

  static Future<void> showChatNotification(
    PushPayload payload, {
    ChatNotificationStyle style =
        ChatNotificationStyle.loud,
  }) async {
    if (!payload.isValid) {
      return;
    }
    if (!Platform.isAndroid) {
      // iOS/macOS는 별도 구현 시점까지 noop.
      return;
    }

    final NotificationDetails details =
        _buildDetails(style);

    final int notificationId =
        DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final String payloadJson = payload.toJsonString();

    PttLogger.log(
      '[Push][Notification]',
      'showChatNotification',
      meta: <String, Object?>{
        'style': style.name,
        'chatIdHash': payload.chatId.hashCode,
        'hasTitle': payload.title != null,
        'hasBody': payload.body != null,
      },
    );

    await _plugin.show(
      notificationId,
      payload.title ?? '새 메시지',
      payload.body ?? '새 메시지가 도착했습니다.',
      details,
      payload: payloadJson,
    );
  }

  static NotificationDetails _buildDetails(
    ChatNotificationStyle style,
  ) {
    if (!Platform.isAndroid) {
      // 현재 단계에서는 Android 위주로만 처리한다.
      return const NotificationDetails();
    }

    switch (style) {
      case ChatNotificationStyle.loud:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelIdLoud,
            _channelNameLoud,
            channelDescription: _channelDescLoud,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      case ChatNotificationStyle.silent:
        return const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelIdSilent,
            _channelNameSilent,
            channelDescription: _channelDescSilent,
            // 중요도는 기본 수준, 사운드는 끈 상태로 시작한다.
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            playSound: false,
            enableVibration: true,
          ),
        );
    }
  }

  static void _handleNotificationPayload(String jsonStr) {
    try {
      final PushPayload payload =
          PushPayload.fromJsonString(jsonStr);
      if (!payload.isValid) {
        return;
      }
      final router = tryGetAppRouter();
      if (router == null) {
        return;
      }
      router.go('/chat/${payload.chatId}');
    } catch (_) {
      // Parsing/navigation failures are non-fatal for notification taps.
    }
  }
}
