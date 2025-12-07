import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/friend_state.dart';

class ChatListPage extends ConsumerWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(chatMessagesProvider);
    final friends = ref.watch(friendListProvider);

    final Map<String, ChatMessage> lastByChatId = {};
    for (final m in messages) {
      final existing = lastByChatId[m.chatId];
      if (existing == null || m.createdAt.isAfter(existing.createdAt)) {
        lastByChatId[m.chatId] = m;
      }
    }

    final entries = lastByChatId.entries.toList()
      ..sort(
        (a, b) => b.value.createdAt.compareTo(a.value.createdAt),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: entries.isEmpty
          ? const Center(
              child: Text('아직 대화가 없습니다'),
            )
          : ListView.builder(
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                final chatId = entry.key;
                final lastMessage = entry.value;

                String? friendName;
                final match = friends.where((f) => f.id == chatId);
                if (match.isNotEmpty) {
                  friendName = match.first.name;
                }

                final titleText = friendName ?? chatId;
                final time = lastMessage.createdAt;
                final hh = time.hour.toString().padLeft(2, '0');
                final mm = time.minute.toString().padLeft(2, '0');
                final timeLabel = '$hh:$mm';
                final subtitleText =
                    lastMessage.type == ChatMessageType.voice
                        ? '음성 메시지'
                        : (lastMessage.text ?? '');

                return ListTile(
                  title: Text(titleText),
                  subtitle: Text(
                    subtitleText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    timeLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    context.push('/chat/$chatId');
                  },
                );
              },
            ),
    );
  }
}
