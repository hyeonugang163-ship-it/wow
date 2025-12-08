// NOTE: 설계도 v1.1 기준 1:1 채팅 화면으로, Manner 음성 버블 UX(재생/에러/길이/단일 재생)를 구현한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/chat_voice_player.dart';
import 'package:voyage/conversation_state.dart';
import 'package:voyage/friend_state.dart';

final _chatControllers = <String, TextEditingController>{};

/// Manual test – voice bubble playback UX
/// 1) Manner 모드에서 친구 A에게 음성 메시지 2개를 보낸다.
/// 2) 친구 A 채팅방에 음성 버블 2개가 표시되는지 확인한다.
/// 3) 첫 번째 버블을 탭:
///    - 아이콘이 ▶ → ⏸ 로 바뀌고,
///    - 실제 오디오가 재생되며,
///    - 로그에 [ChatVoicePlayer] play start ... 가 찍힌다.
/// 4) 다시 탭하면 재생이 멈추고, 아이콘이 ▶ 로 돌아온다.
/// 5) 두 번째 버블에서도 동일하게 동작하는지 확인한다.
/// 6) (선택) 파일을 삭제하거나 존재하지 않는 path를 가진 메시지를 만들어
///    error 상태 아이콘/텍스트가 잘 표시되는지 확인한다.
class ChatPage extends ConsumerWidget {
  const ChatPage({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 상태 변경 시 재빌드를 위해 watch.
    ref.watch(chatMessagesProvider);
    final currentPlayingMessageId =
        ref.watch(currentPlayingVoiceMessageIdProvider);
    final errorMessageIds =
        ref.watch(voicePlaybackErrorMessageIdsProvider);
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
                  final hasPlaybackError =
                      errorMessageIds.contains(message.id);
                  final isError = hasPlaybackError || !hasAudioPath;

                  String primaryLabel;
                  if (isError) {
                    primaryLabel = '재생 실패';
                  } else {
                    primaryLabel = '음성 메시지';
                  }

                  String? durationText;
                  final durationMillis = message.durationMillis;
                  if (durationMillis != null && durationMillis > 0) {
                    final totalSeconds = (durationMillis / 1000).round();
                    final minutes = totalSeconds ~/ 60;
                    final seconds = totalSeconds % 60;
                    durationText =
                        '$minutes:${seconds.toString().padLeft(2, '0')}';
                  }

                  final colorScheme = Theme.of(context).colorScheme;
                  final bubbleColor = isError
                      ? colorScheme.errorContainer
                      : isPlaying
                          ? colorScheme.primaryContainer
                          : baseColor;

                  IconData iconData;
                  Color? iconColor;
                  if (isError) {
                    iconData = Icons.error_outline;
                    iconColor = colorScheme.error;
                  } else if (isPlaying) {
                    iconData = Icons.pause;
                    iconColor = colorScheme.onPrimaryContainer;
                  } else {
                    iconData = Icons.play_arrow;
                    iconColor = colorScheme.onSecondaryContainer;
                  }

                  return Align(
                    alignment: alignment,
                    child: GestureDetector(
                      onTap: () async {
                        if (hasPlaybackError) {
                          debugPrint(
                            '[Chat] voice message tap ignored in error state '
                            '(messageId=${message.id})',
                          );
                          // TODO: allow retry from error state on tap.
                          return;
                        }
                        if (!hasAudioPath) {
                          debugPrint(
                            '[Chat] voice message tapped without path '
                            '(messageId=${message.id})',
                          );
                          return;
                        }
                        final player = ref.read(chatVoicePlayerProvider);
                        final path = message.audioPath!;
                        try {
                          await player.togglePlay(
                            path: path,
                            messageId: message.id,
                          );
                        } catch (e) {
                          debugPrint(
                            '[Chat] failed to toggle voice message '
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
                              iconData,
                              size: 20,
                              color: iconColor,
                            ),
                            const SizedBox(width: 6),
                            Text(primaryLabel),
                            if (durationText != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                durationText,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
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
