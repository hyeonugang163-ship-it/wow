// NOTE: 설계도 v1.1 기준 PTT 홈/버튼 UX를 담당하며,
// 최소 홀드 시간 이후에만 startTalk를 호출하고,
// 터치 즉시 버튼 색상을 변경해 자연스러운 눌림 피드백을 제공한다.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/auth/auth_state.dart';
import 'package:voyage/auth/auth_state_notifier.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_controller.dart';
import 'package:voyage/ptt_debug_overlay.dart';
import 'package:voyage/ptt_strings.dart';
import 'package:voyage/ptt_ui_event.dart';

/// Minimum hold duration before PTT actually starts.
///
/// TODO: move to PolicyConfig / FeatureFlags if we need
/// platform- or market-specific tuning.
const Duration kPttMinHoldDuration = Duration(seconds: 1);

class PttHomePage extends ConsumerStatefulWidget {
  const PttHomePage({super.key});

  @override
  ConsumerState<PttHomePage> createState() => _PttHomePageState();
}

class _PttHomePageState extends ConsumerState<PttHomePage> {
  DateTime? _pressStartedAt;
  bool _hasStartedTalk = false;
  bool _isPressed = false;
  Timer? _holdTimer;
  bool _showDebugOverlay = false;

  @override
  void initState() {
    super.initState();

    ref.listen<PttUiEvent?>(
      pttUiEventProvider,
      (prev, next) {
        if (!mounted || next == null) {
          return;
        }
        final message = PttUiMessages.messageForType(next.messageKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
        ref.read(pttUiEventProvider.notifier).clear();
      },
    );
  }

  Future<void> _handlePressStart(
    BuildContext context,
    DateTime holdTriggeredAt,
  ) async {
    final ref = this.ref;
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    // 친구가 선택되지 않은 경우에는 모드와 상관없이 막는다.
    if (currentFriendId == null) {
      ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.noFriendSelected(mode: mode),
          );
      return;
    }

    final pttAllowMap = ref.read(friendPttAllowProvider);
    final friendAllowed = pttAllowMap[currentFriendId] ?? false;

    if (mode == PttMode.walkie && friendAllowed) {
      await SystemSound.play(SystemSoundType.click);
    }

    await ref
        .read(pttControllerProvider.notifier)
        .startTalk(uiHoldAt: holdTriggeredAt);
  }

  Future<void> _handlePressEnd(BuildContext context) async {
    final ref = this.ref;
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    if (mode == PttMode.walkie && currentFriendId != null) {
      await SystemSound.play(SystemSoundType.click);
    }

    await ref.read(pttControllerProvider.notifier).stopTalk();
  }

  void _onPressDown(BuildContext context) {
    _pressStartedAt = DateTime.now();
    _hasStartedTalk = false;
    _isPressed = true;
    _holdTimer?.cancel();

    if (kDebugMode) {
      debugPrint('[PTT][UI] press down');
    }

    _holdTimer = Timer(kPttMinHoldDuration, () async {
      if (!_isPressed || _hasStartedTalk) {
        return;
      }
      _hasStartedTalk = true;
      if (kDebugMode) {
        debugPrint(
          '[PTT][UI] hold satisfied, calling startTalk',
        );
      }
      final holdTriggeredAt = DateTime.now();
      await _handlePressStart(context, holdTriggeredAt);
    });
  }

  Future<void> _onPressEnd(BuildContext context) async {
    final ref = this.ref;
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    _isPressed = false;
    _holdTimer?.cancel();
    final startedAt = _pressStartedAt;
    _pressStartedAt = null;

    if (_hasStartedTalk) {
      await _handlePressEnd(context);
      return;
    }

    final heldMs = startedAt == null
        ? 0
        : DateTime.now().difference(startedAt).inMilliseconds;
    if (kDebugMode) {
      debugPrint(
        '[PTT][UI] press too short (<minHold), '
        'heldMs=$heldMs minHoldMs=${kPttMinHoldDuration.inMilliseconds}',
      );
    }

    if (!mounted) {
      return;
    }
    ref.read(pttUiEventProvider.notifier).emit(
          PttUiEvents.holdTooShort(
            friendId: currentFriendId,
            mode: mode,
          ),
        );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final authState = ref.watch(authStateNotifierProvider);

    if (authState.status == AuthStatus.unknown &&
        authState.user == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final talkState = ref.watch(pttControllerProvider);
    final isTalking = talkState == PttTalkState.talking;
    final mode = ref.watch(pttModeProvider);
    final currentFriendId = ref.watch(currentPttFriendIdProvider);
    final friends = ref.watch(friendListProvider);
    final pttAllowMap = ref.watch(friendPttAllowProvider);
    final blockMap = ref.watch(friendBlockProvider);

    final currentFriend = currentFriendId == null
        ? null
        : friends.where((f) => f.id == currentFriendId).isEmpty
            ? null
            : friends.firstWhere((f) => f.id == currentFriendId);

    var friendAllowed = false;
    if (currentFriendId != null) {
      friendAllowed = pttAllowMap[currentFriendId] ?? false;
    }

    var friendBlocked = false;
    if (currentFriendId != null) {
      friendBlocked = blockMap[currentFriendId] ?? false;
    }

    String targetStatusText;
    if (currentFriend == null) {
      targetStatusText =
          '현재 무전 대상이 없습니다. Friends 화면에서 친구를 길게 눌러 설정하세요.';
    } else if (friendBlocked) {
      targetStatusText =
          '현재 대상: ${currentFriend.name} (차단됨: 무전/매너 모두 전송되지 않습니다.)';
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

    final bool isFriendBlocked = friendBlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MJTalk PTT (MVP)'),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                setState(() {
                  _showDebugOverlay = !_showDebugOverlay;
                });
              },
            ),
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
      body: Stack(
        children: [
          Padding(
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
                      onTapDown: (_) => _onPressDown(context),
                      onTapUp: (_) async => _onPressEnd(context),
                      onTapCancel: () async => _onPressEnd(context),
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: isFriendBlocked
                              ? Theme.of(context)
                                  .colorScheme
                                  .errorContainer
                              : (isTalking || _isPressed)
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          currentFriend == null
                              ? '친구 선택 필요'
                              : isFriendBlocked
                                  ? '차단됨'
                                  : isTalking
                                      ? 'Talking…'
                                      : 'Hold to Talk',
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
          if (_showDebugOverlay) const PttDebugOverlay(),
        ],
      ),
    );
  }
}
