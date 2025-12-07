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
                return ListTile(
                  title: Text(friend.name),
                  subtitle:
                      friend.status != null ? Text(friend.status!) : null,
                  trailing: Switch(
                    value: isAllowed,
                    onChanged: (value) {
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
