import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
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
  RealChatApi({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  String? get _currentUid => _firebaseAuth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _messagesCollection(
    String chatId,
  ) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages');
  }

  /// Firestore message document schema (v1.1):
  /// - text: String? (텍스트 메시지 내용)
  /// - audioPath: String? (음성 메시지 로컬/원격 경로)
  /// - durationMillis: int? (음성 메시지 길이 ms)
  /// - fromUid: String? (FirebaseAuth uid)
  /// - createdAt: Timestamp (FieldValue.serverTimestamp)
  ChatMessage _fromDocument({
    required String chatId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? <String, dynamic>{};
    final String? text = data['text'] as String?;
    final String? audioPath = data['audioPath'] as String?;
    final int? durationMillis = data['durationMillis'] as int?;
    final String? fromUid = data['fromUid'] as String?;
    final Timestamp? createdAtTs =
        data['createdAt'] as Timestamp?;
    final DateTime createdAt =
        createdAtTs?.toDate() ?? DateTime.now();

    final ChatMessageType type =
        audioPath != null && audioPath.isNotEmpty
            ? ChatMessageType.voice
            : ChatMessageType.text;

    final String? currentUid = _currentUid;
    final bool isFromMe =
        fromUid != null && currentUid != null && fromUid == currentUid;

    return ChatMessage(
      id: doc.id,
      chatId: chatId,
      text: text,
      fromMe: isFromMe,
      createdAt: createdAt,
      type: type,
      audioPath: audioPath,
      durationMillis: durationMillis,
      fromUid: fromUid,
    );
  }

  @override
  Future<ApiResult<List<ChatMessage>>> fetchMessages(
    String chatId, {
    DateTime? since,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _messagesCollection(chatId).orderBy(
        'createdAt',
        descending: false,
      );
      if (since != null) {
        query = query.where(
          'createdAt',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }
      final snapshot = await query.get();
      final messages = snapshot.docs
          .map(
            (doc) => _fromDocument(
              chatId: chatId,
              doc: doc,
            ),
          )
          .toList(growable: false);

      PttLogger.log(
        '[Backend][ChatApi][Real]',
        'fetchMessages',
        meta: <String, Object?>{
          'chatIdHash': chatId.hashCode,
          'count': messages.length,
        },
      );

      return ApiResult<List<ChatMessage>>.success(messages);
    } catch (e, st) {
      debugPrint(
        '[Backend][ChatApi][Real] fetchMessages error: $e',
      );
      debugPrint(st.toString());
      return ApiResult<List<ChatMessage>>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.fetchMessages error',
        ),
      );
    }
  }

  @override
  Future<ApiResult<ChatMessage>> sendTextMessage(
    String chatId,
    String text,
  ) async {
    try {
      final String? fromUid = _currentUid;
      final now = DateTime.now();
      final collection = _messagesCollection(chatId);
      final docRef = collection.doc();
      await docRef.set(<String, Object?>{
        'text': text,
        'audioPath': null,
        'durationMillis': null,
        'fromUid': fromUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final message = ChatMessage(
        id: docRef.id,
        chatId: chatId,
        text: text,
        fromMe: true,
        createdAt: now,
        fromUid: fromUid,
      );

      PttLogger.log(
        '[Backend][ChatApi][Real]',
        'sendTextMessage',
        meta: <String, Object?>{
          'chatIdHash': chatId.hashCode,
          'textLength': text.length,
        },
      );

      return ApiResult<ChatMessage>.success(message);
    } catch (e, st) {
      debugPrint(
        '[Backend][ChatApi][Real] sendTextMessage error: $e',
      );
      debugPrint(st.toString());
      return ApiResult<ChatMessage>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.sendTextMessage error',
        ),
      );
    }
  }

  @override
  Future<ApiResult<ChatMessage>> sendVoiceMessage(
    String chatId,
    String localPath,
    int durationMillis,
  ) async {
    try {
      final String? fromUid = _currentUid;
      final now = DateTime.now();
      final collection = _messagesCollection(chatId);
      final docRef = collection.doc();
      await docRef.set(<String, Object?>{
        'text': null,
        'audioPath': localPath,
        'durationMillis': durationMillis,
        'fromUid': fromUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final message = ChatMessage(
        id: docRef.id,
        chatId: chatId,
        text: null,
        fromMe: true,
        createdAt: now,
        type: ChatMessageType.voice,
        audioPath: localPath,
        durationMillis: max(durationMillis, 0),
        fromUid: fromUid,
      );

      PttLogger.log(
        '[Backend][ChatApi][Real]',
        'sendVoiceMessage',
        meta: <String, Object?>{
          'chatIdHash': chatId.hashCode,
          'localPathHash': localPath.hashCode,
          'durationMillis': durationMillis,
        },
      );

      return ApiResult<ChatMessage>.success(message);
    } catch (e, st) {
      debugPrint(
        '[Backend][ChatApi][Real] sendVoiceMessage error: $e',
      );
      debugPrint(st.toString());
      return ApiResult<ChatMessage>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealChatApi.sendVoiceMessage error',
        ),
      );
    }
  }
}
