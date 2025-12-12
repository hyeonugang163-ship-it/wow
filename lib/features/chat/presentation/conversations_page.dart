import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/features/chat/application/conversation_state.dart';

class ConversationsPage extends ConsumerWidget {
  const ConversationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('대화'),
      ),
      body: conversations.isEmpty
          ? const Center(
              child: Text('아직 대화가 없습니다'),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conv = conversations[index];
                final updatedLabel = conv.updatedAt
                    .toLocal()
                    .toString()
                    .split('.')
                    .first;

                return ListTile(
                  title: Text(conv.title),
                  subtitle: Text(conv.subtitle),
                  trailing: Text(
                    updatedLabel,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    context.push('/chat/${conv.chatId}');
                  },
                );
              },
            ),
    );
  }
}
