class ConversationSummary {
  const ConversationSummary({
    required this.chatId,
    required this.title,
    required this.subtitle,
    required this.updatedAt,
    this.hasUnread = false,
  });

  final String chatId; // 보통 Friend.id와 매칭
  final String title; // UI에 보여줄 이름
  final String subtitle; // 마지막 메시지 요약
  final DateTime updatedAt; // 마지막 메시지 시각
  final bool hasUnread;

  ConversationSummary copyWith({
    String? chatId,
    String? title,
    String? subtitle,
    DateTime? updatedAt,
    bool? hasUnread,
  }) {
    return ConversationSummary(
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      updatedAt: updatedAt ?? this.updatedAt,
      hasUnread: hasUnread ?? this.hasUnread,
    );
  }
}

