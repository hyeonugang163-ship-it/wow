import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';

/// Simple DTO representing the subset of FCM data payload
/// that the app cares about for chat/PTT notifications.
class PushPayload {
  const PushPayload({
    required this.type,
    required this.chatId,
    this.messageId,
    this.fromUid,
    this.title,
    this.body,
  });

  /// Logical type of the push, e.g. "chat_message", "voice_message".
  final String type;

  /// Target chat id. Required for navigation.
  final String chatId;

  /// Optional backend message id.
  final String? messageId;

  /// Optional sender uid.
  final String? fromUid;

  /// Notification title/body to show in system UI.
  final String? title;
  final String? body;

  factory PushPayload.fromRemoteMessage(RemoteMessage message) {
    final Map<String, dynamic> data = message.data;
    return PushPayload(
      type: (data['type'] as String?) ?? 'chat_message',
      chatId: (data['chatId'] as String?) ?? '',
      messageId: data['messageId'] as String?,
      fromUid: data['fromUid'] as String?,
      title:
          (data['title'] as String?) ?? message.notification?.title,
      body:
          (data['body'] as String?) ?? message.notification?.body,
    );
  }

  factory PushPayload.fromJsonString(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        return const PushPayload(type: 'invalid', chatId: '');
      }
      final Map<String, dynamic> map = decoded;
      return PushPayload(
        type: (map['type'] as String?) ?? 'chat_message',
        chatId: (map['chatId'] as String?) ?? '',
        messageId: map['messageId'] as String?,
        fromUid: map['fromUid'] as String?,
        title: map['title'] as String?,
        body: map['body'] as String?,
      );
    } catch (_) {
      return const PushPayload(type: 'invalid', chatId: '');
    }
  }

  String toJsonString() {
    final Map<String, dynamic> map = <String, dynamic>{
      'type': type,
      'chatId': chatId,
      if (messageId != null) 'messageId': messageId,
      if (fromUid != null) 'fromUid': fromUid,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
    };
    return jsonEncode(map);
  }

  bool get isValid => chatId.isNotEmpty;
}

