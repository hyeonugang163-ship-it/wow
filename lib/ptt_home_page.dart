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
import 'package:voyage/chat_page.dart';
import 'package:voyage/core/theme/app_colors.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_controller.dart';
import 'package:voyage/ptt_debug_overlay.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_strings.dart';
import 'package:voyage/ptt/ptt_mode_provider.dart';
import 'package:voyage/ptt/ptt_user_prefs.dart';
import 'package:voyage/ptt_ui_event.dart';

/// Minimum hold duration before PTT actually starts.
///
/// 사용자가 오동작 없이 "꾹 눌러서 말하기"를 인지할 수 있도록
/// 기본값을 1초로 둔다.
///
/// TODO: 플랫폼/시장별 튜닝이 필요하면 PolicyConfig / FeatureFlags 로 이동한다.
const Duration kPttMinHoldDuration = Duration(milliseconds: 1000);

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

    final beepOnStart = ref.read(pttBeepOnStartProvider);
    final vibrateInWalkie =
        ref.read(pttVibrateInWalkieProvider);

    if (mode == PttMode.walkie && friendAllowed) {
      if (beepOnStart) {
        await SystemSound.play(SystemSoundType.alert);
      }
      if (vibrateInWalkie) {
        await HapticFeedback.mediumImpact();
      }
    }

    await ref
        .read(pttControllerProvider.notifier)
        .startTalk(uiHoldAt: holdTriggeredAt);
  }

  Future<void> _handlePressEnd(BuildContext context) async {
    final ref = this.ref;
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    final beepOnEnd = ref.read(pttBeepOnEndProvider);

    if (mode == PttMode.walkie &&
        currentFriendId != null &&
        beepOnEnd) {
      await SystemSound.play(SystemSoundType.alert);
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
    PttLogger.log(
      '[PTT][UI]',
      'press_down',
      meta: <String, Object?>{
        'at': _pressStartedAt!.toIso8601String(),
        'minHoldMs': kPttMinHoldDuration.inMilliseconds,
      },
    );

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

    final startedAt = _pressStartedAt;
    _isPressed = false;
    _holdTimer?.cancel();
    _pressStartedAt = null;

    if (_hasStartedTalk) {
      final int heldMs = startedAt == null
          ? 0
          : DateTime.now()
              .difference(startedAt)
              .inMilliseconds;
      PttLogger.log(
        '[PTT][UI]',
        'press_end_valid',
        meta: <String, Object?>{
          'heldMs': heldMs,
          'minHoldMs': kPttMinHoldDuration.inMilliseconds,
        },
      );
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
    PttLogger.log(
      '[PTT][UI]',
      'press_end_short',
      meta: <String, Object?>{
        'heldMs': heldMs,
        'minHoldMs': kPttMinHoldDuration.inMilliseconds,
      },
    );

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

    // NOTE: ref.listen은 ConsumerState.build 안에서만 사용한다.
    // PTT UI 이벤트(PttUiEvent)를 감지해 SnackBar를 노출하고,
    // 처리 후에는 이벤트를 즉시 clear한다.
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
    final bool isWalkieAllowed =
        friendAllowed && !friendBlocked;

    return Scaffold(
      appBar: AppBar(
        title: const Text('채팅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: '채팅',
            onPressed: () {
              context.push('/chats');
            },
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: '친구',
            onPressed: () {
              context.push('/friends');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () {
              context.push('/settings');
            },
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report_outlined),
              tooltip: '디버그',
              onPressed: () {
                setState(() {
                  _showDebugOverlay = !_showDebugOverlay;
                });
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PTT 모드',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('무전모드'),
                              selected: mode == PttMode.walkie,
                              onSelected: (_) {
                                ref
                                    .read(
                                      pttModeProvider.notifier,
                                    )
                                    .setMode(PttMode.walkie);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('매너모드'),
                              selected: mode == PttMode.manner,
                              onSelected: (_) {
                                ref
                                    .read(
                                      pttModeProvider.notifier,
                                    )
                                    .setMode(PttMode.manner);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: currentFriend == null
                              ? null
                              : () {
                                  final friend = currentFriend;
                                  final args = PttChatRouteArgs(
                                    friendId: friend.id,
                                    friendName: friend.name,
                                    isWalkieAllowed: isWalkieAllowed,
                                  );
                                  context.pushNamed(
                                    'chat',
                                    pathParameters: <String, String>{
                                      'id': friend.id,
                                    },
                                    extra: args,
                                  );
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                            ),
                            child: Text(
                              targetStatusText,
                              textAlign: TextAlign.start,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium,
                            ),
                          ),
                        ),
                        if (currentFriend != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                '무전 허용',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium,
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: isWalkieAllowed,
                                onChanged: (value) async {
                                  if (friendBlocked) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '"${currentFriend.name}"은(는) 차단되어 있어 '
                                          '무전 허용을 변경할 수 없습니다.',
                                        ),
                                        duration: const Duration(
                                          seconds: 2,
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  await ref
                                      .read(
                                        friendPttAllowProvider.notifier,
                                      )
                                      .setAllowed(
                                        currentFriend.id,
                                        value,
                                      );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isPressed && !isTalking) ...[
                          Text(
                            '1초 이상 꾹 누르면 전송, 짧게 떼면 취소',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.textPrimary
                                      .withOpacity(0.7),
                                ),
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '녹음 중… 손을 떼면 전송, 1초 이내 떼면 취소',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        GestureDetector(
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
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                      : AppColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              currentFriend == null
                                  ? '친구 선택 필요'
                                  : isFriendBlocked
                                      ? '차단됨'
                                      : isTalking
                                          ? '녹음 중…'
                                          : '꾹 누르고 말하기',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                        ),
                      ],
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
