import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_controller.dart';

class PttHomePage extends ConsumerWidget {
  const PttHomePage({super.key});

  Future<void> _handlePressStart(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);
    final pttAllowMap = ref.read(friendPttAllowProvider);

    var friendAllowed = false;
    if (currentFriendId != null) {
      friendAllowed = pttAllowMap[currentFriendId] ?? false;
    }

    // 친구가 선택되지 않은 경우에는 모드와 상관없이 막는다.
    if (currentFriendId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '무전 버튼을 쓰기 전에 Friends 화면에서 '
            '무전 대상을 먼저 선택해 주세요.',
          ),
        ),
      );
      return;
    }

    // Walkie 모드이지만 이 친구에 대한 무전 허용이 꺼져 있는 경우:
    // 실제 전송은 매너모드로 다운그레이드되므로, 그 사실을 한 번 안내한다.
    if (mode == PttMode.walkie && !friendAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '이 친구는 무전 허용이 꺼져 있어, 이번에는 매너모드로 처리됩니다.',
          ),
        ),
      );
    }

    if (mode == PttMode.walkie && friendAllowed) {
      await SystemSound.play(SystemSoundType.click);
    }

    await ref.read(pttControllerProvider.notifier).startTalk();
  }

  Future<void> _handlePressEnd(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    if (mode == PttMode.walkie && currentFriendId != null) {
      await SystemSound.play(SystemSoundType.click);
    }

    await ref.read(pttControllerProvider.notifier).stopTalk();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talkState = ref.watch(pttControllerProvider);
    final isTalking = talkState == PttTalkState.talking;
    final mode = ref.watch(pttModeProvider);
    final currentFriendId = ref.watch(currentPttFriendIdProvider);
    final friends = ref.watch(friendListProvider);
    final pttAllowMap = ref.watch(friendPttAllowProvider);

    final currentFriend = currentFriendId == null
        ? null
        : friends.where((f) => f.id == currentFriendId).isEmpty
            ? null
            : friends.firstWhere((f) => f.id == currentFriendId);

    var friendAllowed = false;
    if (currentFriendId != null) {
      friendAllowed = pttAllowMap[currentFriendId] ?? false;
    }

    String targetStatusText;
    if (currentFriend == null) {
      targetStatusText =
          '현재 무전 대상이 없습니다. Friends 화면에서 친구를 길게 눌러 설정하세요.';
    } else if (!friendAllowed) {
      targetStatusText =
          '현재 대상: ${currentFriend.name} (이 친구는 무전 허용이 꺼져 있어, '
          'Walkie 모드여도 매너 처리됩니다.)';
    } else if (mode == PttMode.walkie) {
      targetStatusText =
          '현재 대상: ${currentFriend.name} (무전모드: 즉시 재생 대상)';
    } else {
      targetStatusText =
          '현재 대상: ${currentFriend.name} (매너모드: 녹음본 형태로만 전송 예정)';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('MJTalk PTT (MVP)'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'chats':
                  context.push('/chats');
                  break;
                case 'friends':
                  context.push('/friends');
                  break;
                case 'settings':
                  context.push('/settings');
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'chats',
                child: Text('Chats'),
              ),
              PopupMenuItem(
                value: 'friends',
                child: Text('Friends'),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('모드'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('무전모드'),
                  selected: mode == PttMode.walkie,
                  onSelected: (_) {
                    ref.read(pttModeProvider.notifier).state =
                        PttMode.walkie;
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('매너모드'),
                  selected: mode == PttMode.manner,
                  onSelected: (_) {
                    ref.read(pttModeProvider.notifier).state =
                        PttMode.manner;
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                targetStatusText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTapDown: (_) async =>
                      await _handlePressStart(context, ref),
                  onTapUp: (_) async =>
                      await _handlePressEnd(context, ref),
                  onTapCancel: () async =>
                      await _handlePressEnd(context, ref),
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: isTalking
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isTalking ? 'Talking…' : 'Hold to Talk',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
