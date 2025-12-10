// NOTE: 설계도 v1.1 기준 ChatMessage(text/voice + durationMillis)를 단순한 DTO로 구현한 상태다.

enum ChatMessageType {
  text,
  voice,
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.chatId,
    this.text,
    required this.fromMe,
    required this.createdAt,
    this.type = ChatMessageType.text,
    this.audioPath,
    this.durationMillis,
    this.fromUid,
  });

  final String id;
  final String chatId;

  /// 텍스트 메시지 내용.
  ///
  /// - type == ChatMessageType.text 인 경우에만 유효하다.
  /// - 음성 메시지(voice)인 경우에는 null 이다.
  final String? text;

  final bool fromMe;
  final DateTime createdAt;
  final String? fromUid;

  final ChatMessageType type;
  final String? audioPath;

  /// 음성 메시지 길이 (밀리초). 없으면 null.
  final int? durationMillis;

  // TODO: 향후 실제 음성 노트 메타데이터(파일 경로, 길이 등)를
  // 별도 필드/타입으로 분리하여 관리할 수 있다.

  factory ChatMessage.voice({
    required String id,
    required String chatId,
    required String audioPath,
    bool fromMe = true,
    DateTime? createdAt,
    int? durationMillis,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      text: null,
      fromMe: fromMe,
      createdAt: createdAt ?? DateTime.now(),
      type: ChatMessageType.voice,
      audioPath: audioPath,
      durationMillis: durationMillis,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'chatId': chatId,
      'type': type.name,
      'text': text,
      'audioPath': audioPath,
      'durationMillis': durationMillis,
      'fromMe': fromMe,
      'fromUid': fromUid,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final messageType = typeString == 'voice'
        ? ChatMessageType.voice
        : ChatMessageType.text;

    return ChatMessage(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      text: json['text'] as String?,
      fromMe: json['fromMe'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      fromUid: json['fromUid'] as String?,
      type: messageType,
      audioPath: json['audioPath'] as String?,
      durationMillis: json['durationMillis'] as int?,
    );
  }
}
