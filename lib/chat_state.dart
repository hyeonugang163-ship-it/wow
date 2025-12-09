// NOTE: 설계도 v1.1 기준 ChatMessagesNotifier(텍스트/음성 메시지 + durationMillis 업데이트)를 관리한다.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/backend/backend_providers.dart';
import 'package:voyage/backend/repositories.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/ptt_debug_log.dart';

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier(this._repository)
      : _loadedChatIds = <String>{},
        super(const <ChatMessage>[]);

  final ChatRepository _repository;
  final Set<String> _loadedChatIds;

  Future<void> _loadMessagesIfNeeded(String chatId) async {
    if (_loadedChatIds.contains(chatId)) {
      return;
    }
    _loadedChatIds.add(chatId);
    try {
      final messages = await _repository.loadMessages(chatId);
      final others =
          state.where((m) => m.chatId != chatId).toList(growable: false);
      state = <ChatMessage>[...others, ...messages];
      PttLogger.log(
        '[Chat][State]',
        'messages loaded',
        meta: <String, Object?>{
          'chatId': chatId,
          'count': messages.length,
        },
      );
    } catch (e) {
      PttLogger.log(
        '[Chat][State]',
        'failed to load messages',
        meta: <String, Object?>{
          'chatId': chatId,
          'error': e.toString(),
        },
      );
    }
  }

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

    _repository
        .sendText(chatId, text)
        .catchError((Object error, StackTrace stackTrace) {
      PttLogger.log(
        '[Chat][State]',
        'sendText failed',
        meta: <String, Object?>{
          'chatId': chatId,
          'error': error.toString(),
        },
      );
      return message;
    });
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
    PttLogger.log(
      '[Chat]',
      'voice message added',
      meta: <String, Object?>{
        'chatId': chatId,
        'fromMe': fromMe,
        'hasPath': hasPath,
      },
    );

    final int safeDurationMillis = durationMillis ?? 0;
    _repository
        .sendVoice(chatId, audioPath, safeDurationMillis)
        .catchError((Object error, StackTrace stackTrace) {
      PttLogger.log(
        '[Chat][State]',
        'sendVoice failed',
        meta: <String, Object?>{
          'chatId': chatId,
          'error': error.toString(),
        },
      );
      return message;
    });
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
      PttLogger.log(
        '[Chat]',
        'voice duration updated',
        meta: <String, Object?>{
          'messageId': messageId,
          'durationMillis': durationMillis,
        },
      );
    }
  }

  List<ChatMessage> messagesForChat(String chatId) {
    // Fire-and-forget load; UI will rebuild when state updates.
    _loadMessagesIfNeeded(chatId);
    return state.where((m) => m.chatId == chatId).toList();
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) {
    final repository = ref.read(chatRepositoryProvider);
    return ChatMessagesNotifier(repository);
  },
);
