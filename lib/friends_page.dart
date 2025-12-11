// NOTE: 설계도 v1.1 기준 Friends 화면으로,
// 무전 허용/차단/신고(Abuse) 액션을 제공한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/abuse.dart';
import 'package:voyage/chat_message.dart';
import 'package:voyage/chat_state.dart';
import 'package:voyage/core/theme/app_colors.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_ui_event.dart';

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final bool isSameDay =
        now.year == time.year &&
        now.month == time.month &&
        now.day == time.day;
    if (isSameDay) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListProvider);
    // 채팅 요약 정보 업데이트를 위해 watch만 걸어 둔다.
    ref.watch(chatMessagesProvider);
    final chatNotifier =
        ref.read(chatMessagesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
      ),
      body: friends.isEmpty
          ? const Center(
              child: Text('아직 친구가 없습니다'),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final chatId = friend.id;
                final name = friend.name;
                final initial =
                    name.isNotEmpty ? name.characters.first : '?';

                final ChatMessage? lastMessage =
                    chatNotifier.lastMessageForChat(chatId);
                final int unreadCount =
                    chatNotifier.unreadCountForChat(chatId);

                String subtitleText;
                if (lastMessage != null) {
                  String preview;
                  if (lastMessage.type ==
                          ChatMessageType.voice &&
                      (lastMessage.text == null ||
                          lastMessage.text!.isEmpty)) {
                    preview = '음성 메시지';
                  } else {
                    preview =
                        lastMessage.text?.isNotEmpty == true
                            ? lastMessage.text!
                            : '메시지';
                  }
                  final timeLabel =
                      _formatTime(lastMessage.createdAt);
                  subtitleText = '$preview · $timeLabel';
                } else if (friend.status != null &&
                    friend.status!.isNotEmpty) {
                  subtitleText = friend.status!;
                } else {
                  subtitleText = '아직 메시지 없음';
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(
                      initial,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                  title: Text(
                    friend.name,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge,
                  ),
                  subtitle: Text(
                    subtitleText,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (unreadCount > 0)
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin:
                              const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors
                                      .textPrimary,
                                ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: '친구 설정',
                        onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        builder: (context) {
                          return Consumer(
                            builder: (context, bottomRef, _) {
                              final localPttAllow =
                                  bottomRef.watch(friendPttAllowProvider)[
                                          friend.id] ??
                                      false;
                              final localBlocked =
                                  bottomRef.watch(friendBlockProvider)[
                                          friend.id] ??
                                      false;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    if (friend.status != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        friend.status!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                    const SizedBox(height: 16),
                                    SwitchListTile(
                                      title: const Text('무전 허용'),
                                      value: localPttAllow,
                                      onChanged: localBlocked
                                          ? null
                                          : (value) {
                                              bottomRef
                                                  .read(
                                                    friendPttAllowProvider
                                                        .notifier,
                                                  )
                                                  .setAllowed(
                                                    friend.id,
                                                    value,
                                                  );
                                            },
                                    ),
                                    SwitchListTile(
                                      title: const Text('차단'),
                                      subtitle: const Text(
                                        '차단 시 이 친구와의 PTT 및 상호작용이 제한됩니다.',
                                      ),
                                      value: localBlocked,
                                      onChanged: (value) {
                                        bottomRef
                                            .read(
                                              friendBlockProvider.notifier,
                                            )
                                            .setBlocked(friend.id, value);
                                        if (value) {
                                          bottomRef
                                              .read(
                                                friendPttAllowProvider
                                                    .notifier,
                                              )
                                              .setAllowed(friend.id, false);
                                        }
                                      },
                                    ),
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.flag_outlined,
                                        color: Colors.redAccent,
                                      ),
                                      title: const Text('신고하기'),
                                      onTap: () async {
                                        final navigator =
                                            Navigator.of(context);
                                        final reason =
                                            await showDialog<AbuseReason>(
                                          context: context,
                                          builder: (context) {
                                            return SimpleDialog(
                                              title: const Text(
                                                '신고 사유 선택',
                                              ),
                                              children: [
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(
                                                      context,
                                                    ).pop(
                                                      AbuseReason.spam,
                                                    );
                                                  },
                                                  child: const Text('스팸'),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(
                                                      context,
                                                    ).pop(
                                                      AbuseReason
                                                          .harassment,
                                                    );
                                                  },
                                                  child: const Text(
                                                    '괴롭힘 / 폭언',
                                                  ),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(
                                                      context,
                                                    ).pop(
                                                      AbuseReason
                                                          .inappropriate,
                                                    );
                                                  },
                                                  child: const Text(
                                                    '부적절한 내용',
                                                  ),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(
                                                      context,
                                                    ).pop(
                                                      AbuseReason.other,
                                                    );
                                                  },
                                                  child: const Text('기타'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                        if (reason == null) {
                                          return;
                                        }

                                        await bottomRef
                                            .read(
                                              abuseReportsProvider.notifier,
                                            )
                                            .addReport(
                                              friendId: friend.id,
                                              reason: reason,
                                            );

                                        navigator.pop();
                                        bottomRef
                                            .read(
                                              pttUiEventProvider.notifier,
                                            )
                                            .emit(
                                              PttUiEvents.abuseReported(
                                                friendId: friend.id,
                                              ),
                                            );
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    ref
                        .read(currentPttFriendIdProvider.notifier)
                        .state = friend.id;
                    context.push('/chat/${friend.id}');
                  },
                  onLongPress: () {
                    ref
                        .read(currentPttFriendIdProvider.notifier)
                        .state = friend.id;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${friend.name}"님이 현재 무전 대상입니다.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
