import 'dart:math';

import 'package:voyage/backend/api_result.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/ptt_debug_log.dart';

abstract class ChatApi {
  Future<ApiResult<List<ChatMessage>>> fetchMessages(
    String chatId, {
    DateTime? since,
  });

  Future<ApiResult<ChatMessage>> sendTextMessage(
    String chatId,
    String text,
  );

  Future<ApiResult<ChatMessage>> sendVoiceMessage(
    String chatId,
    String localPath,
    int durationMillis,
  );
}

class FakeChatApi implements ChatApi {
  FakeChatApi() {
    final now = DateTime.now();
    _messagesByChat['u1'] = <ChatMessage>[
      ChatMessage(
        id: now.millisecondsSinceEpoch.toString(),
        chatId: 'u1',
        text: '안녕! 이것은 더미 메시지야.',
        fromMe: false,
        createdAt: now,
      ),
      ChatMessage(
        id: (now.millisecondsSinceEpoch + 1).toString(),
        chatId: 'u1',
        text: '테스트 채팅방에 온 걸 환영해.',
        fromMe: true,
        createdAt: now,
      ),
    ];
  }

  final Map<String, List<ChatMessage>> _messagesByChat =
      <String, List<ChatMessage>>{};

  int _idCounter = 0;

  String _nextMessageId() {
    _idCounter += 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'm_${timestamp}_$_idCounter';
  }

  @override
  Future<ApiResult<List<ChatMessage>>> fetchMessages(
    String chatId, {
    DateTime? since,
  }) async {
    final List<ChatMessage> existing =
        _messagesByChat[chatId] ?? <ChatMessage>[];
    final List<ChatMessage> filtered;
    if (since == null) {
      filtered = List<ChatMessage>.from(existing);
    } else {
      filtered = existing
          .where((m) => m.createdAt.isAfter(since))
          .toList(growable: false);
    }

    PttLogger.log(
      '[Backend][ChatApi][Fake]',
      'fetchMessages',
      meta: <String, Object?>{
        'chatIdHash': chatId.hashCode,
        'since': since?.toIso8601String() ?? 'null',
        'returnedCount': filtered.length,
      },
    );

    return ApiResult<List<ChatMessage>>.success(filtered);
  }

  @override
  Future<ApiResult<ChatMessage>> sendTextMessage(
    String chatId,
    String text,
  ) async {
    final now = DateTime.now();
    final message = ChatMessage(
      id: _nextMessageId(),
      chatId: chatId,
      text: text,
      fromMe: true,
      createdAt: now,
    );
    final list =
        _messagesByChat.putIfAbsent(chatId, () => <ChatMessage>[]);
    list.add(message);

    PttLogger.log(
      '[Backend][ChatApi][Fake]',
      'sendTextMessage',
      meta: <String, Object?>{
        'chatIdHash': chatId.hashCode,
        'textLength': text.length,
      },
    );

    return ApiResult<ChatMessage>.success(message);
  }

  @override
  Future<ApiResult<ChatMessage>> sendVoiceMessage(
    String chatId,
    String localPath,
    int durationMillis,
  ) async {
    final now = DateTime.now();
    final message = ChatMessage.voice(
      id: _nextMessageId(),
      chatId: chatId,
      audioPath: localPath,
      fromMe: true,
      createdAt: now,
      durationMillis: max(durationMillis, 0),
    );
    final list =
        _messagesByChat.putIfAbsent(chatId, () => <ChatMessage>[]);
    list.add(message);

    PttLogger.log(
      '[Backend][ChatApi][Fake]',
      'sendVoiceMessage',
      meta: <String, Object?>{
        'chatIdHash': chatId.hashCode,
        'localPathHash': localPath.hashCode,
        'durationMillis': durationMillis,
      },
    );

    return ApiResult<ChatMessage>.success(message);
  }
}

class RealChatApi implements ChatApi {
  RealChatApi();

  @override
  Future<ApiResult<List<ChatMessage>>> fetchMessages(
    String chatId, {
    DateTime? since,
  }) {
    return Future<ApiResult<List<ChatMessage>>>.value(
      ApiResult<List<ChatMessage>>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.fetchMessages is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<ChatMessage>> sendTextMessage(
    String chatId,
    String text,
  ) {
    return Future<ApiResult<ChatMessage>>.value(
      ApiResult<ChatMessage>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.sendTextMessage is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<ChatMessage>> sendVoiceMessage(
    String chatId,
    String localPath,
    int durationMillis,
  ) {
    return Future<ApiResult<ChatMessage>>.value(
      ApiResult<ChatMessage>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.sendVoiceMessage is not implemented',
        ),
      ),
    );
  }
}
