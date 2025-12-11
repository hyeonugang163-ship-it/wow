// NOTE: 설계도 v1.1 기준 1:1 채팅 화면으로, Manner 음성 버블 UX(재생/에러/길이/단일 재생)를 구현한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/chat_voice_player.dart';
import 'package:voyage/conversation_state.dart';
import 'package:voyage/core/theme/app_colors.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';
import 'package:voyage/ptt_debug_log.dart';

final _chatControllers = <String, TextEditingController>{};

class PttChatRouteArgs {
  const PttChatRouteArgs({
    required this.friendId,
    required this.friendName,
    required this.isWalkieAllowed,
  });

  final String friendId;
  final String friendName;

  /// 설계도 기준 "서로 무전 허용 동의된 친구" 여부.
  /// 현재 단계에서는 로컬 무전 허용/차단 상태를 바탕으로 계산된 값이며,
  /// 추후 서버 상호동의 정보와 연동될 수 있다.
  final bool isWalkieAllowed;
}

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
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({
    super.key,
    required this.chatId,
    this.pttArgs,
  });

  final String chatId;
  final PttChatRouteArgs? pttArgs;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final Set<String> _autoPlayedMessageIds =
      <String>{};

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(chatMessagesProvider.notifier);
    notifier.loadInitialMessages(widget.chatId);
    notifier.startWatching(widget.chatId);

    // 자동 재생 – Walkie 모드에서만 동작.
    ref.listen<List<ChatMessage>>(
      chatMessagesProvider,
      (previous, next) async {
        if (!mounted) {
          return;
        }

        // 첫 스냅샷에서는 자동 재생하지 않고 기준점으로만 사용한다.
        if (previous == null) {
          return;
        }

        final mode = ref.read(pttModeProvider);
        if (mode != PttMode.walkie) {
          return;
        }

        final String chatId = widget.chatId;
        final List<ChatMessage> prevForChat =
            previous
                .where((m) => m.chatId == chatId)
                .toList(growable: false);
        final List<ChatMessage> nextForChat =
            next
                .where((m) => m.chatId == chatId)
                .toList(growable: false);

        if (nextForChat.isEmpty) {
          return;
        }

        final Set<String> prevIds =
            prevForChat.map((m) => m.id).toSet();
        final List<ChatMessage> newMessages =
            nextForChat
                .where((m) => !prevIds.contains(m.id))
                .toList(growable: false);
        if (newMessages.isEmpty) {
          return;
        }

        final List<ChatMessage> candidates =
            newMessages.where((m) {
          final bool isVoice =
              m.type == ChatMessageType.voice &&
                  (m.audioPath ?? '').isNotEmpty;
          final bool fromOther = !m.fromMe;
          final bool notPlayed =
              !_autoPlayedMessageIds.contains(m.id);
          return isVoice && fromOther && notPlayed;
        }).toList(growable: false);

        if (candidates.isEmpty) {
          return;
        }

        final ChatMessage toPlay = candidates.last;
        final String path = toPlay.audioPath ?? '';
        if (path.isEmpty) {
          return;
        }

        _autoPlayedMessageIds.add(toPlay.id);
        PttLogger.log(
          '[PTT-AutoPlay]',
          'walkie auto-play',
          meta: <String, Object?>{
            'chatId': chatId,
            'messageId': toPlay.id,
          },
        );

        final player = ref.read(chatVoicePlayerProvider);
        try {
          await player.togglePlay(
            path: path,
            messageId: toPlay.id,
          );
        } catch (e) {
          debugPrint(
            '[PTT-AutoPlay] auto-play error: $e',
          );
        }
      },
    );
  }

  @override
  void dispose() {
    ref.read(chatMessagesProvider.notifier).stopWatching();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatId = widget.chatId;
    final PttChatRouteArgs? args = widget.pttArgs;

    // 상태 변경 시 재빌드를 위해 watch.
    ref.watch(chatMessagesProvider);
    final currentPlayingMessageId =
        ref.watch(currentPlayingVoiceMessageIdProvider);
    final errorMessageIds =
        ref.watch(voicePlaybackErrorMessageIdsProvider);
    final notifier = ref.read(chatMessagesProvider.notifier);
    final List<ChatMessage> messages =
        notifier.messagesForChat(chatId).reversed.toList();
    notifier.markAllAsSeen(chatId);

    final mode = ref.watch(pttModeProvider);
    final friends = ref.watch(friendListProvider);
    String? friendName;
    final matches =
        friends.where((friend) => friend.id == chatId);
    if (matches.isNotEmpty) {
      friendName = matches.first.name;
    }

    final effectiveFriendName =
        args?.friendName ?? friendName ?? chatId;
    final isWalkieAllowed = args?.isWalkieAllowed ?? false;

    String modeSubtitle;
    if (mode == PttMode.walkie) {
      if (isWalkieAllowed) {
        modeSubtitle =
            '무전모드 · 이 친구는 즉시 재생 허용';
      } else {
        modeSubtitle =
            '무전모드 · 아직 이 친구와는 무전 허용이 안 됨 (녹음본으로 수신)';
      }
    } else {
      modeSubtitle = '매너모드 · 모든 친구와 녹음본으로만 수신';
    }

    final controller = _chatControllers.putIfAbsent(
      chatId,
      () => TextEditingController(),
    );

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              effectiveFriendName,
              style:
                  Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              modeSubtitle,
              style:
                  Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 12,
              ),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.fromMe;
                final alignment = isMe
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                final baseColor =
                    AppColors.chatBubbleOther;

                if (message.type == ChatMessageType.voice) {
                  final hasAudioPath =
                      message.audioPath != null &&
                          message.audioPath!.isNotEmpty;
                  final isPlaying =
                      message.id ==
                          currentPlayingMessageId;
                  final hasPlaybackError =
                      errorMessageIds
                          .contains(message.id);
                  final isError =
                      hasPlaybackError || !hasAudioPath;

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

                  final colorScheme =
                      Theme.of(context).colorScheme;
                  final bubbleColor = isError
                      ? colorScheme.errorContainer
                      : isMe
                          ? AppColors.chatBubbleMe
                          : baseColor;

                  IconData iconData;
                  Color? iconColor;
                  if (isError) {
                    iconData = Icons.error_outline;
                    iconColor = colorScheme.error;
                  } else if (isPlaying) {
                    iconData = Icons.pause;
                    iconColor = colorScheme.onPrimary;
                  } else {
                    iconData = Icons.play_arrow;
                    iconColor = colorScheme.onPrimary;
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
                          borderRadius:
                              BorderRadius.circular(20),
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
                  final textColor =
                      AppColors.textPrimary;
                  String? statusText;
                  if (isMe) {
                    // 1:1 채팅 가정: chatId를 상대 uid로 사용.
                    final String otherUid = chatId;
                    final bool isSeenByOther =
                        message.isSeenBy(otherUid);
                    statusText =
                        isSeenByOther ? '읽음' : '전송됨';
                  } else {
                    statusText = null;
                  }

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
                        color: isMe
                            ? AppColors.chatBubbleMe
                            : baseColor,
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            message.text ?? '',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: textColor,
                                ),
                          ),
                          if (statusText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              statusText,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: textColor
                                        .withOpacity(0.6),
                                  ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }
              },
            ),
          ),
          const Divider(height: 1),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: const InputDecoration(
                        hintText: '메시지를 입력하세요',
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
