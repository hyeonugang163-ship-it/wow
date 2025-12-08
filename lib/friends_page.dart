import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/friend_state.dart';

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
                        value: isBlocked ? false : isAllowed,
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
                                      value: localBlocked
                                          ? false
                                          : localPttAllow,
                                      onChanged: localBlocked
                                          ? null
                                          : (value) {
                                              ref
                                                  .read(friendPttAllowProvider
                                                      .notifier)
                                                  .setAllowed(
                                                      friend.id, value);
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
                                      onTap: () {
                                        reportFriendAbuse(
                                          friendId: friend.id,
                                          reason: 'manual_report',
                                        );
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '"${friend.name}"님을 신고했습니다.',
                                            ),
                                            duration:
                                                const Duration(seconds: 2),
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
                        content: Text('"${friend.name}"님이 현재 무전 대상입니다.'),
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
