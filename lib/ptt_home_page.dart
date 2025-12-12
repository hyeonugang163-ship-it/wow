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

class _PttHomePageState extends ConsumerState<PttHomePage>
    with SingleTickerProviderStateMixin {
  DateTime? _pressStartedAt;
  bool _hasStartedTalk = false;
  bool _isPressed = false;
  Timer? _holdTimer;
  bool _showDebugOverlay = false;
  late final AnimationController _holdProgressController;

  @override
  void initState() {
    super.initState();
    _holdProgressController = AnimationController(
      vsync: this,
      duration: kPttMinHoldDuration,
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
    _holdProgressController.forward(from: 0);

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
    _holdProgressController.stop();
    _holdProgressController.reset();
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
    _holdProgressController.dispose();
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
    final debugOverlayEnabled =
        ref.watch(pttDebugOverlayEnabledProvider);

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

    final bool isFriendBlocked = friendBlocked;
    final bool isWalkieAllowed =
        friendAllowed && !friendBlocked;

    final bool hasTarget = currentFriend != null;
    final String targetName =
        currentFriend?.name ?? '무전 대상 없음';
    final String targetSubtitle;
    final Color targetChipColor;
    final IconData targetChipIcon;

    if (!hasTarget) {
      targetSubtitle = 'Friends에서 친구를 선택해 주세요';
      targetChipColor = AppColors.textSecondary;
      targetChipIcon = Icons.person_add_alt_1_outlined;
    } else if (isFriendBlocked) {
      targetSubtitle = '차단됨 · 무전/매너 모두 전송 불가';
      targetChipColor = AppColors.error;
      targetChipIcon = Icons.block;
    } else if (!friendAllowed) {
      targetSubtitle = '무전 허용 OFF · Walkie도 매너 전송';
      targetChipColor = AppColors.warning;
      targetChipIcon = Icons.volume_off_outlined;
    } else if (mode == PttMode.walkie) {
      targetSubtitle = '즉시 재생 대상 · Walkie 허용';
      targetChipColor = AppColors.accent;
      targetChipIcon = Icons.flash_on_outlined;
    } else {
      targetSubtitle = '매너모드 · 녹음본으로 전송';
      targetChipColor = AppColors.textSecondary;
      targetChipIcon = Icons.chat_bubble_outline;
    }
    final bool showDebugOverlay =
        _showDebugOverlay || debugOverlayEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PTT'),
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
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final friend = currentFriend;
                    if (friend == null) {
                      context.push('/friends');
                      return;
                    }
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
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            hasTarget
                                ? targetName.characters.first
                                : '＋',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      targetName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: targetChipColor
                                          .withAlpha(31),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                      border: Border.all(
                                        color: targetChipColor
                                            .withAlpha(128),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          targetChipIcon,
                                          size: 14,
                                          color: targetChipColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          hasTarget
                                              ? (isFriendBlocked
                                                  ? '차단'
                                                  : (!friendAllowed
                                                      ? '무전 OFF'
                                                      : (mode ==
                                                              PttMode.walkie
                                                          ? '즉시재생'
                                                          : '매너')))
                                              : '친구 선택',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: targetChipColor,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                targetSubtitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (hasTarget && !isFriendBlocked)
                          Switch.adaptive(
                            value: friendAllowed,
                            onChanged: (value) {
                              final id = currentFriendId;
                              if (id == null) return;
                              ref
                                  .read(
                                    friendPttAllowProvider.notifier,
                                  )
                                  .setAllowed(id, value);
                            },
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        '모드',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<PttMode>(
                        segments: const [
                          ButtonSegment<PttMode>(
                            value: PttMode.walkie,
                            label: Text('Walkie'),
                            icon: Icon(Icons.flash_on_outlined),
                          ),
                          ButtonSegment<PttMode>(
                            value: PttMode.manner,
                            label: Text('Manner'),
                            icon: Icon(Icons.chat_bubble_outline),
                          ),
                        ],
                        selected: <PttMode>{mode},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          ref
                              .read(pttModeProvider.notifier)
                              .setMode(selection.first);
                        },
                        style: const ButtonStyle(
                          visualDensity:
                              VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(
                        milliseconds: 150,
                      ),
                      child: Text(
                        _isPressed || isTalking
                            ? '녹음 중… 손을 떼면 전송'
                            : (hasTarget
                                ? '꾹 누르고 말하기'
                                : '친구를 선택해 시작'),
                        key: ValueKey<String>(
                          '${_isPressed}_${isTalking}_${hasTarget}_${mode.name}',
                        ),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: (_isPressed || isTalking)
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AnimatedBuilder(
                      animation: _holdProgressController,
                      builder: (context, _) {
                        final bool isHolding =
                            _isPressed && !_hasStartedTalk;
                        final double holdValue =
                            _holdProgressController.value;

                        final Color ringColor = isTalking
                            ? AppColors.primary
                            : AppColors.accent;

                        final Color buttonColor = isFriendBlocked
                            ? Theme.of(context)
                                .colorScheme
                                .errorContainer
                            : (isTalking || _isPressed)
                                ? Theme.of(context)
                                    .colorScheme
                                    .primary
                                : AppColors.primarySoft;

                        final IconData centerIcon =
                            isFriendBlocked
                                ? Icons.block
                                : (isTalking || _isPressed)
                                    ? Icons.mic
                                    : Icons.mic_none;

                        final String centerLabel =
                            !hasTarget
                                ? '대상 선택'
                                : isFriendBlocked
                                    ? '차단됨'
                                    : (isTalking || _isPressed)
                                        ? '녹음 중…'
                                        : '꾹 누르기';

                        return GestureDetector(
                          onTapDown: (_) => _onPressDown(context),
                          onTapUp: (_) async =>
                              _onPressEnd(context),
                          onTapCancel: () async =>
                              _onPressEnd(context),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 216,
                                height: 216,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                    width: 2,
                                  ),
                                ),
                              ),
                              if (isHolding || isTalking)
                                SizedBox(
                                  width: 216,
                                  height: 216,
                                  child:
                                      CircularProgressIndicator(
                                    value: isHolding
                                        ? holdValue
                                        : 1,
                                    strokeWidth: 6,
                                    backgroundColor:
                                        Colors.transparent,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      ringColor,
                                    ),
                                  ),
                                ),
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 120),
                                curve: Curves.easeOut,
                                width: isHolding || isTalking
                                    ? 188
                                    : 180,
                                height: isHolding || isTalking
                                    ? 188
                                    : 180,
                                decoration: BoxDecoration(
                                  color: buttonColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ringColor.withAlpha(
                                        isHolding || isTalking ? 89 : 38,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize.min,
                                  children: [
                                    Icon(
                                      centerIcon,
                                      size: 44,
                                      color: AppColors.textPrimary,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      centerLabel,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.textPrimary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      hasTarget
                          ? '1초 이상 꾹 누르면 녹음이 시작됩니다.'
                          : 'Friends에서 무전 대상을 먼저 골라주세요.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showDebugOverlay) const PttDebugOverlay(),
        ],
      ),
    );
  }
}
