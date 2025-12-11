// NOTE: 설계도 v1.1 기준 ChatMessagesNotifier(텍스트/음성 메시지 + durationMillis 업데이트)를 관리한다.

import 'dart:async';

import 'package:flutter/foundation.dart';
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
  StreamSubscription<List<ChatMessage>>? _watchSubscription;

  Future<void> _loadMessagesIfNeeded(String chatId) async {
    if (_loadedChatIds.contains(chatId)) {
      return;
    }
    _loadedChatIds.add(chatId);
    debugPrint(
      '[ChatMessagesNotifier] loadInitialMessages chatId=$chatId',
    );
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

  Future<void> loadInitialMessages(String chatId) async {
    await _loadMessagesIfNeeded(chatId);
  }

  Future<void> startWatching(String chatId) async {
    await _watchSubscription?.cancel();
    PttLogger.log(
      '[ChatMessagesNotifier]',
      'startWatching',
      meta: <String, Object?>{
        'chatId': chatId,
      },
    );
    try {
      _watchSubscription = _repository.watchMessages(chatId).listen(
        (messages) {
          final others = state
              .where((m) => m.chatId != chatId)
              .toList(growable: false);
          state = <ChatMessage>[...others, ...messages];

          final int count = messages.length;
          DateTime? firstAt;
          DateTime? lastAt;
          if (count > 0) {
            firstAt = messages.first.createdAt;
            lastAt = messages.last.createdAt;
          }
          PttLogger.log(
            '[ChatMessagesNotifier]',
            'onMessagesUpdate',
            meta: <String, Object?>{
              'chatId': chatId,
              'count': count,
              if (firstAt != null)
                'firstAt': firstAt.toIso8601String(),
              if (lastAt != null)
                'lastAt': lastAt.toIso8601String(),
            },
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            '[ChatMessagesNotifier] watchMessages error: $error',
          );
        },
      );
    } catch (e, st) {
      debugPrint(
        '[ChatMessagesNotifier] startWatching exception: $e',
      );
      debugPrint(st.toString());
    }
  }

  Future<void> stopWatching() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    PttLogger.log(
      '[ChatMessagesNotifier]',
      'stopWatching',
    );
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
      seenBy: const <String, DateTime>{},
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
    if (durationMillis == null) {
      PttLogger.log(
        '[Chat][Voice]',
        'durationMillis is null, defaulting to 0',
        meta: <String, Object?>{
          'chatId': chatId,
        },
      );
    }
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
          fromUid: message.fromUid,
          seenAt: message.seenAt,
          seenBy: message.seenBy,
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

  List<ChatMessage> getUnreadMessagesForCurrentUser(String chatId) {
    return state
        .where(
          (m) =>
              m.chatId == chatId &&
              !m.fromMe &&
              m.seenAt == null,
        )
        .toList(growable: false);
  }

  Future<void> markAllAsSeen(String chatId) async {
    final unread = getUnreadMessagesForCurrentUser(chatId);
    if (unread.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final Set<String> unreadIds =
        unread.map((m) => m.id).toSet();

    // 로컬 상태를 먼저 업데이트해 UX를 빠르게 반영한다.
    state = state.map((message) {
      if (message.chatId == chatId &&
          unreadIds.contains(message.id)) {
        return ChatMessage(
          id: message.id,
          chatId: message.chatId,
          text: message.text,
          fromMe: message.fromMe,
          createdAt: message.createdAt,
          type: message.type,
          audioPath: message.audioPath,
          durationMillis: message.durationMillis,
          fromUid: message.fromUid,
          seenAt: now,
          seenBy: message.seenBy,
        );
      }
      return message;
    }).toList(growable: false);

    try {
      await _repository.markMessagesAsSeen(
        chatId,
        unreadIds.toList(growable: false),
      );
      debugPrint(
        '[ChatMessagesNotifier] markAllAsSeen '
        'chatId=$chatId count=${unread.length}',
      );
    } catch (e, st) {
      debugPrint(
        '[ChatMessagesNotifier] markAllAsSeen error: $e',
      );
      debugPrint(st.toString());
    }
  }

  List<ChatMessage> messagesForChat(String chatId) {
    // Fire-and-forget load; UI will rebuild when state updates.
    _loadMessagesIfNeeded(chatId);
    return state.where((m) => m.chatId == chatId).toList();
  }

  ChatMessage? lastMessageForChat(String chatId) {
    ChatMessage? latest;
    for (final message in state) {
      if (message.chatId != chatId) {
        continue;
      }
      if (latest == null ||
          message.createdAt.isAfter(latest.createdAt)) {
        latest = message;
      }
    }
    return latest;
  }

  int unreadCountForChat(String chatId) {
    return getUnreadMessagesForCurrentUser(chatId).length;
  }

  @override
  void dispose() {
    _watchSubscription?.cancel();
    PttLogger.log(
      '[ChatMessagesNotifier]',
      'dispose',
    );
    super.dispose();
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) {
    final repository = ref.read(chatRepositoryProvider);
    return ChatMessagesNotifier(repository);
  },
);
