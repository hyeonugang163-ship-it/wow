import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt_controller.dart';

class PttHomePage extends ConsumerWidget {
  const PttHomePage({super.key});

  Future<void> _handlePressStart(WidgetRef ref) async {
    await ref.read(pttControllerProvider.notifier).startTalk();
  }

  Future<void> _handlePressEnd(WidgetRef ref) async {
    await ref.read(pttControllerProvider.notifier).stopTalk();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final talkState = ref.watch(pttControllerProvider);
    final isTalking = talkState == PttTalkState.talking;
    final mode = ref.watch(pttModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MJTalk PTT (MVP)'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
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
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTapDown: (_) async => await _handlePressStart(ref),
                  onTapUp: (_) async => await _handlePressEnd(ref),
                  onTapCancel: () async => await _handlePressEnd(ref),
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
