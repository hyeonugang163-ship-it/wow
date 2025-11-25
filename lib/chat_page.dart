import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.fromMe,
    required this.createdAt,
  });

  final String id;
  final String chatId;
  final String text;
  final bool fromMe;
  final DateTime createdAt;
}

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  ChatMessagesNotifier() : super(const []);

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

  List<ChatMessage> getMessagesForChat(String chatId) {
    return state.where((m) => m.chatId == chatId).toList();
  }
}

final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) => ChatMessagesNotifier(),
);

final _chatControllers = <String, TextEditingController>{};

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMessages = ref.watch(chatMessagesProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);
    final messages = notifier.getMessagesForChat(chatId);
    final controller = _chatControllers.putIfAbsent(
      chatId,
      () => TextEditingController(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat $chatId'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.fromMe;
                final alignment =
                    isMe ? Alignment.centerRight : Alignment.centerLeft;
                final color = isMe
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceVariant;

                return Align(
                  alignment: alignment,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(message.text),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: '메시지를 입력하세요',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      return;
                    }
                    ref
                        .read(chatMessagesProvider.notifier)
                        .addMessage(chatId: chatId, text: text);
                    controller.clear();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

