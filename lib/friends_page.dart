// NOTE: 설계도 v1.1 기준 Friends 화면으로,
// 무전 허용/차단/신고(Abuse) 액션을 제공한다.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/abuse.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_ui_event.dart';

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListProvider);
    final pttAllowMap = ref.watch(friendPttAllowProvider);
    final blockMap = ref.watch(friendBlockProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
      ),
      body: friends.isEmpty
          ? const Center(
              child: Text('아직 친구가 없습니다'),
            )
          : ListView.builder(
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final isAllowed = pttAllowMap[friend.id] ?? false;
                final isBlocked = blockMap[friend.id] ?? false;

                return ListTile(
                  title: Text(friend.name),
                  subtitle:
                      friend.status != null ? Text(friend.status!) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: isAllowed,
                        onChanged: (value) {
                          if (isBlocked) {
                            // Blocked friends cannot be toggled for PTT allow.
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '"${friend.name}"은(는) 차단되어 있어 무전 허용을 변경할 수 없습니다.',
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          ref
                              .read(friendPttAllowProvider.notifier)
                              .setAllowed(friend.id, value);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? '"${friend.name}"에게 무전을 허용했습니다.'
                                    : '"${friend.name}"에 대한 무전 허용을 해제했습니다.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          isBlocked ? Icons.block : Icons.block_outlined,
                          color:
                              isBlocked ? Colors.redAccent : null,
                        ),
                        tooltip:
                            isBlocked ? '차단 해제' : '차단',
                        onPressed: () {
                          final next = !isBlocked;
                          ref
                              .read(friendBlockProvider.notifier)
                              .setBlocked(friend.id, next);
                          if (next) {
                            // 차단 시에는 무전 허용도 함께 해제.
                            ref
                                .read(
                                  friendPttAllowProvider.notifier,
                                )
                                .setAllowed(friend.id, false);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                next
                                    ? '"${friend.name}"님을 차단했습니다.'
                                    : '"${friend.name}"님 차단을 해제했습니다.',
                              ),
                              duration:
                                  const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: '친구 설정',
                        onPressed: () {
                          showModalBottomSheet<void>(
                            context: context,
                            builder: (context) {
                              final localPttAllow = ref.watch(
                                  friendPttAllowProvider)[friend.id] ??
                                  false;
                              final localBlocked =
                                  ref.watch(friendBlockProvider)[friend.id] ??
                                      false;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                              ref
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
                                        ref
                                            .read(
                                                friendBlockProvider.notifier)
                                            .setBlocked(friend.id, value);
                                        if (value) {
                                          // Optionally also turn off PTT allow.
                                          ref
                                              .read(friendPttAllowProvider
                                                  .notifier)
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
                                              title:
                                                  const Text('신고 사유 선택'),
                                              children: [
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(context).pop(
                                                      AbuseReason.spam,
                                                    );
                                                  },
                                                  child: const Text('스팸'),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(context).pop(
                                                      AbuseReason.harassment,
                                                    );
                                                  },
                                                  child: const Text('괴롭힘 / 폭언'),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(context).pop(
                                                      AbuseReason
                                                          .inappropriate,
                                                    );
                                                  },
                                                  child: const Text('부적절한 내용'),
                                                ),
                                                SimpleDialogOption(
                                                  onPressed: () {
                                                    Navigator.of(context).pop(
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

                                        await ref
                                            .read(
                                              abuseReportsProvider.notifier,
                                            )
                                            .addReport(
                                              friendId: friend.id,
                                              reason: reason,
                                            );

                                        navigator.pop();
                                        ref
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
                      ),
                    ],
                  ),
                  onTap: () {
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
