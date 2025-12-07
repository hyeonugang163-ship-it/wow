import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/chat_voice_player.dart';
import 'package:voyage/conversation_state.dart';
import 'package:voyage/friend_state.dart';

final _chatControllers = <String, TextEditingController>{};

class ChatPage extends ConsumerWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
	    // 상태 변경 시 재빌드를 위해 watch.
	    ref.watch(chatMessagesProvider);
	    final currentPlayingMessageId =
	        ref.watch(currentPlayingVoiceMessageIdProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);
    final List<ChatMessage> messages =
        notifier.messagesForChat(chatId).reversed.toList();

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
              reverse: true,
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.fromMe;
                final alignment =
                    isMe ? Alignment.centerRight : Alignment.centerLeft;
	                final baseColor =
	                    Theme.of(context).colorScheme.secondaryContainer;

                if (message.type == ChatMessageType.voice) {
	                  final hasAudioPath = message.audioPath != null &&
	                      message.audioPath!.isNotEmpty;
	                  final isPlaying =
	                      message.id == currentPlayingMessageId;
                  final baseLabel =
                      hasAudioPath ? '음성 메시지' : '음성 메시지 (파일 없음)';
                  final durationLabel = message.durationMillis != null
                      ? ' (${(message.durationMillis! / 1000).toStringAsFixed(1)}초)'
                      : '';
	                  final voiceLabel = '$baseLabel$durationLabel';
	                  final bubbleColor = isPlaying
	                      ? Theme.of(context).colorScheme.primaryContainer
	                      : baseColor;
                  return Align(
                    alignment: alignment,
                    child: GestureDetector(
	                      onTap: () async {
	                        if (!hasAudioPath) {
	                          debugPrint(
	                            '[Chat] voice message tapped without path '
	                            '(messageId=${message.id})',
	                          );
	                          return;
	                        }
	                        final player =
	                            ref.read(chatVoicePlayerProvider);
	                        final path = message.audioPath!;
	                        try {
	                          await player.play(
	                            path: path,
	                            messageId: message.id,
	                          );
	                        } catch (e) {
	                          debugPrint(
	                            '[Chat] failed to play voice message '
	                            '(hasPath=true messageId=${message.id} error=$e)',
	                          );
	                        }
	                      },
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
	                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
	                            Icon(
	                              isPlaying
	                                  ? Icons.equalizer
	                                  : Icons.mic,
	                              size: 18,
	                            ),
                            const SizedBox(width: 4),
                            Text(voiceLabel),
                          ],
                        ),
                      ),
                    ),
                  );
	                } else {
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
	                          color: baseColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(message.text ?? ''),
                    ),
                  );
                }
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isEmpty) {
                        return;
                      }
                      ref.read(chatMessagesProvider.notifier).addMessage(
                            chatId: chatId,
                            text: text,
                          );

                      final friends = ref.read(friendListProvider);
                      String? friendName;
                      final matches =
                          friends.where((friend) => friend.id == chatId);
                      if (matches.isNotEmpty) {
                        friendName = matches.first.name;
                      }

                      final subtitle = text.length > 50
                          ? '${text.substring(0, 50)}...'
                          : text;

                      ref
                          .read(conversationListProvider.notifier)
                          .upsertFromMessage(
                            chatId: chatId,
                            title: friendName ?? chatId,
                            subtitle: subtitle,
                            updatedAt: DateTime.now(),
                          );
                      controller.clear();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
