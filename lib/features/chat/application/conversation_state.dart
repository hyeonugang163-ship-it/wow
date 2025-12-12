import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/features/chat/domain/conversation.dart';

class ConversationListNotifier
    extends StateNotifier<List<ConversationSummary>> {
  ConversationListNotifier() : super(const []);

  void upsertFromMessage({
    required String chatId,
    required String title,
    required String subtitle,
    required DateTime updatedAt,
  }) {
    final index =
        state.indexWhere((conversation) => conversation.chatId == chatId);

    if (index >= 0) {
      final existing = state[index];
      final updated = existing.copyWith(
        title: title,
        subtitle: subtitle,
        updatedAt: updatedAt,
      );

      final List<ConversationSummary> next = [...state];
      next[index] = updated;
      next.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
      state = next;
    } else {
      final conversation = ConversationSummary(
        chatId: chatId,
        title: title,
        subtitle: subtitle,
        updatedAt: updatedAt,
      );

      final List<ConversationSummary> next = [conversation, ...state];
      next.sort(
        (a, b) => b.updatedAt.compareTo(a.updatedAt),
      );
      state = next;
    }
  }
}

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, List<ConversationSummary>>(
  (ref) => ConversationListNotifier(),
);
