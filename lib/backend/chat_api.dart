import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:voyage/backend/api_result.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/ptt_debug_log.dart';

abstract class ChatApi {
  Future<ApiResult<List<ChatMessage>>> fetchMessages(
    String chatId, {
    DateTime? since,
  });

  Stream<List<ChatMessage>> watchMessages(String chatId);

  Future<void> markMessagesAsSeen({
    required String chatId,
    required List<String> messageIds,
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
        seenBy: const <String, DateTime>{},
      ),
      ChatMessage(
        id: (now.millisecondsSinceEpoch + 1).toString(),
        chatId: 'u1',
        text: '테스트 채팅방에 온 걸 환영해.',
        fromMe: true,
        createdAt: now,
        seenBy: const <String, DateTime>{},
      ),
    ];
  }

  final Map<String, List<ChatMessage>> _messagesByChat =
      <String, List<ChatMessage>>{};
  final Map<String, StreamController<List<ChatMessage>>>
      _controllers =
      <String, StreamController<List<ChatMessage>>>{};

  int _idCounter = 0;

  String _nextMessageId() {
    _idCounter += 1;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'm_${timestamp}_$_idCounter';
  }

  Stream<List<ChatMessage>> _controllerStreamForChat(
    String chatId,
  ) {
    final controller =
        _controllers.putIfAbsent(
      chatId,
      () => StreamController<List<ChatMessage>>.broadcast(),
    );
    // Seed with current messages snapshot.
    final current =
        List<ChatMessage>.from(
          _messagesByChat[chatId] ?? <ChatMessage>[],
        );
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(current);
      }
    });
    return controller.stream;
  }

  void _emitMessages(String chatId) {
    final controller = _controllers[chatId];
    if (controller == null || controller.isClosed) {
      return;
    }
    final current =
        List<ChatMessage>.from(
          _messagesByChat[chatId] ?? <ChatMessage>[],
        );
    controller.add(current);
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
      seenBy: const <String, DateTime>{},
    );
    final list =
        _messagesByChat.putIfAbsent(chatId, () => <ChatMessage>[]);
    list.add(message);

    _emitMessages(chatId);

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

    _emitMessages(chatId);

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

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    return _controllerStreamForChat(chatId);
  }

  @override
  Future<void> markMessagesAsSeen({
    required String chatId,
    required List<String> messageIds,
  }) async {
    // NOTE: Fake 환경에서는 현재 단계에서 별도 저장소 동기화가 필요하지 않으므로
    // 구현을 비워 둔다. 필요 시 _messagesByChat을 업데이트하도록 확장할 수 있다.
    return;
  }
}

class RealChatApi implements ChatApi {
  RealChatApi({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;
  final FirebaseStorage _storage;

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
  /// - seenAt: Timestamp? (legacy single-viewer seen time)
  /// - seenBy: Map<String, Timestamp>? (uid -> seen time)
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

    final Map<String, DateTime> seenBy =
        <String, DateTime>{};
    final dynamic rawSeenBy = data['seenBy'];
    if (rawSeenBy is Map<String, dynamic>) {
      rawSeenBy.forEach((String uid, dynamic value) {
        if (value is Timestamp) {
          seenBy[uid] = value.toDate();
        }
      });
    }

    final ChatMessageType type =
        audioPath != null && audioPath.isNotEmpty
            ? ChatMessageType.voice
            : ChatMessageType.text;

    final String? currentUid = _currentUid;
    final bool isFromMe =
        fromUid != null && currentUid != null && fromUid == currentUid;

    DateTime? seenAtForCurrentUser;
    if (currentUid != null) {
      seenAtForCurrentUser = seenBy[currentUid];
    }
    if (seenAtForCurrentUser == null) {
      final Timestamp? legacySeenAtTs =
          data['seenAt'] as Timestamp?;
      seenAtForCurrentUser = legacySeenAtTs?.toDate();
    }

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
      seenAt: seenAtForCurrentUser,
      seenBy: seenBy,
    );
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId) {
    final query = _messagesCollection(chatId).orderBy(
      'createdAt',
      descending: false,
    );
    return query.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        return snapshot.docs
            .map(
              (doc) => _fromDocument(
                chatId: chatId,
                doc: doc,
              ),
            )
            .toList(growable: false);
      },
    );
  }

  @override
  Future<void> markMessagesAsSeen({
    required String chatId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) {
      return;
    }
    final String? viewerUid = _currentUid;
    if (viewerUid == null) {
      debugPrint(
        '[Backend][ChatApi][Real] markMessagesAsSeen skipped: no current uid',
      );
      return;
    }
    try {
      final WriteBatch batch = _firestore.batch();
      for (final messageId in messageIds) {
        final docRef = _messagesCollection(chatId).doc(messageId);
        batch.update(docRef, <String, Object?>{
          'seenBy.$viewerUid': FieldValue.serverTimestamp(),
          // 유지보수/하위 호환을 위해 legacy seenAt도 함께 업데이트한다.
          'seenAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e, st) {
      debugPrint(
        '[Backend][ChatApi][Real] markMessagesAsSeen error: $e',
      );
      debugPrint(st.toString());
      rethrow;
    }
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
        seenBy: const <String, DateTime>{},
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
    final file = File(localPath);
    final bool exists = await file.exists();
    if (!exists) {
      debugPrint(
        '[FirestoreChatRepository] sendVoice upload error: '
        'local file not found (path hash=${localPath.hashCode})',
      );
      return ApiResult<ChatMessage>.failure(
        const ApiError(
          type: ApiErrorType.notFound,
          message: 'Local voice file not found',
        ),
      );
    }

    try {
      final String? fromUid = _currentUid;
      final now = DateTime.now();
      final collection = _messagesCollection(chatId);
      final docRef = collection.doc();
      debugPrint(
        '[FirestoreChatRepository] sendVoice upload start '
        'chatId=$chatId localPathHash=${localPath.hashCode}',
      );

      String downloadUrl;
      try {
        final String uidForPath = fromUid ?? 'anonymous';
        // Local recordings are produced as AAC-LC in an M4A (MP4) container.
        // Keep the remote object extension/content-type consistent to avoid
        // decoder mismatch during streaming playback.
        final ref = _storage
            .ref()
            .child('voice')
            .child(uidForPath)
            .child(chatId)
            .child('${docRef.id}.m4a');
        await ref.putFile(
          file,
          SettableMetadata(contentType: 'audio/mp4'),
        );
        downloadUrl = await ref.getDownloadURL();
        debugPrint(
          '[FirestoreChatRepository] sendVoice upload success '
          'chatId=$chatId downloadUrlHash=${downloadUrl.hashCode}',
        );
      } catch (e, st) {
        debugPrint(
          '[FirestoreChatRepository] sendVoice upload error: $e',
        );
        debugPrint(st.toString());
        return ApiResult<ChatMessage>.failure(
          const ApiError(
            type: ApiErrorType.unknown,
            message: 'RealChatApi.sendVoiceMessage upload error',
          ),
        );
      }

      try {
        await docRef.set(<String, Object?>{
          'text': null,
          'audioPath': downloadUrl,
          'durationMillis': durationMillis,
          'fromUid': fromUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        debugPrint(
          '[FirestoreChatRepository] sendVoice firestore write success '
          'chatId=$chatId docId=${docRef.id}',
        );
      } catch (e, st) {
        debugPrint(
          '[FirestoreChatRepository] sendVoice firestore write error: $e',
        );
        debugPrint(st.toString());
        return ApiResult<ChatMessage>.failure(
          const ApiError(
            type: ApiErrorType.unknown,
            message:
                'RealChatApi.sendVoiceMessage firestore write error',
          ),
        );
      }

      final message = ChatMessage(
        id: docRef.id,
        chatId: chatId,
        text: null,
        fromMe: true,
        createdAt: now,
        type: ChatMessageType.voice,
        audioPath: downloadUrl,
        durationMillis: max(durationMillis, 0),
        fromUid: fromUid,
        seenBy: const <String, DateTime>{},
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
