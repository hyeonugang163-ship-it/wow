import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_message.dart';

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super(_initialMessages);

  // TODO: 실제 서버 연동 시 제거하거나 서버 데이터로 대체.
  static final List<ChatMessage> _initialMessages = [
    ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: 'u1',
      text: '안녕! 이것은 더미 메시지야.',
      fromMe: false,
      createdAt: DateTime.now(),
    ),
    ChatMessage(
      id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
      chatId: 'u1',
      text: '테스트 채팅방에 온 걸 환영해.',
      fromMe: true,
      createdAt: DateTime.now(),
    ),
  ];

  void addMessage({
    required String chatId,
    required String text,
    bool fromMe = true,
  }) {
    final now = DateTime.now();
    final message = ChatMessage(
      id: now.millisecondsSinceEpoch.toString(),
      chatId: chatId,
      text: text,
      fromMe: fromMe,
      createdAt: now,
    );
    state = [...state, message];
  }

  void addVoiceMessage({
    required String chatId,
    required String audioPath,
    int? durationMillis,
    required bool fromMe,
  }) {
    final now = DateTime.now();
    final message = ChatMessage.voice(
      id: now.millisecondsSinceEpoch.toString(),
      chatId: chatId,
      audioPath: audioPath,
      fromMe: fromMe,
      createdAt: now,
      durationMillis: durationMillis,
    );
    state = [...state, message];

    final hasPath = audioPath.isNotEmpty;
    // 운영 단계에서는 로깅 레벨/전달 경로를 조정한다.
    // ignore: avoid_print
    print(
      '[Chat] voice message added '
      'chatId=$chatId fromMe=$fromMe hasPath=$hasPath',
    );
  }

  void updateVoiceMessageDuration({
    required String messageId,
    required int durationMillis,
  }) {
    var updated = false;
    state = state.map((message) {
      if (message.id == messageId &&
          message.type == ChatMessageType.voice) {
        updated = true;
        return ChatMessage(
          id: message.id,
          chatId: message.chatId,
          text: message.text,
          fromMe: message.fromMe,
          createdAt: message.createdAt,
          type: message.type,
          audioPath: message.audioPath,
          durationMillis: durationMillis,
        );
      }
      return message;
    }).toList();

    if (updated) {
      // 메타데이터 위주 로그 (내용/경로는 남기지 않음).
      // ignore: avoid_print
      print(
        '[Chat] voice duration updated '
        'messageId=$messageId durationMillis=$durationMillis',
      );
    }
  }

  List<ChatMessage> messagesForChat(String chatId) {
    return state.where((m) => m.chatId == chatId).toList();
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) => ChatMessagesNotifier(),
);
