// NOTE: 설계도 v1.1 기준 PTT 홈/버튼 UX를 담당하며,
// 버튼을 누르는 즉시 startTalk를 호출하고,
// 누르고 있는 동안 녹음/전송이 유지되도록 한다.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:voyage/features/auth/application/auth_state.dart';
import 'package:voyage/features/auth/application/auth_state_notifier.dart';
import 'package:voyage/features/chat/presentation/chat_page.dart';
import 'package:voyage/features/chat/application/chat_voice_player.dart';
import 'package:voyage/core/theme/app_colors.dart';
import 'package:voyage/core/theme/app_tokens.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/features/friends/application/friend_state.dart';
import 'package:voyage/features/ptt/application/ptt_controller.dart';
import 'package:voyage/features/ptt/presentation/ptt_debug_overlay.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';
import 'package:voyage/features/ptt/presentation/ptt_strings.dart';
import 'package:voyage/features/ptt/application/ptt_mode_provider.dart';
import 'package:voyage/features/ptt/application/ptt_user_prefs.dart';
import 'package:voyage/features/ptt/application/ptt_ui_event.dart';

class PttHomePage extends ConsumerStatefulWidget {
  const PttHomePage({
    super.key,
    this.embeddedInTabs = false,
  });

  /// When true, this page is used as a bottom-tab destination
  /// and should not render redundant top-level navigation actions.
  final bool embeddedInTabs;

  @override
  ConsumerState<PttHomePage> createState() => _PttHomePageState();
}

class _PttHomePageState extends ConsumerState<PttHomePage>
    with SingleTickerProviderStateMixin {
  static const Duration _minHoldDuration =
      Duration(milliseconds: 300);
  static const Duration _releaseTailDuration =
      Duration(milliseconds: 200);

  DateTime? _pressStartedAt;
  bool _isPressed = false;
  bool _showDebugOverlay = false;
  late final AnimationController _holdProgressController;
  Timer? _minHoldTimer;
  Timer? _releaseTailTimer;
  bool _talkStartedForPress = false;
  int _pressSequence = 0;

  @override
  void initState() {
    super.initState();
    _holdProgressController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
  }

  Future<bool> _handlePressStart(
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
      return false;
    }

    final pttAllowMap = ref.read(friendPttAllowProvider);
    final friendAllowed = pttAllowMap[currentFriendId] ?? false;

    final beepOnStart = ref.read(pttBeepOnStartProvider);
    final vibrateInWalkie =
        ref.read(pttVibrateInWalkieProvider);

    if (mode == PttMode.walkie && friendAllowed) {
      final localAudio = ref.read(pttLocalAudioEngineProvider);
      if (beepOnStart) {
        await localAudio.playBeep(allowDuringRecording: true);
      }
      if (vibrateInWalkie) {
        await HapticFeedback.mediumImpact();
      }
    }

    final started = await ref
        .read(pttControllerProvider.notifier)
        .startTalk(uiHoldAt: holdTriggeredAt);
    return started;
  }

  Future<void> _handlePressEnd() async {
    final ref = this.ref;
    final mode = ref.read(pttModeProvider);
    final currentFriendId = ref.read(currentPttFriendIdProvider);

    final beepOnEnd = ref.read(pttBeepOnEndProvider);

    if (mode == PttMode.walkie &&
        currentFriendId != null &&
        beepOnEnd) {
      final localAudio = ref.read(pttLocalAudioEngineProvider);
      await localAudio.playBeep(allowDuringRecording: true);
    }

    await ref.read(pttControllerProvider.notifier).stopTalk();
  }

  void _onPressDown(BuildContext context) {
    final now = DateTime.now();
    final ref = this.ref;
    _releaseTailTimer?.cancel();
    _releaseTailTimer = null;
    _pressSequence += 1;
    setState(() {
      _pressStartedAt = now;
      _isPressed = true;
    });
    _talkStartedForPress = false;
    final alreadyTalking =
        ref.read(pttControllerProvider.notifier).isTalking;
    if (alreadyTalking) {
      _talkStartedForPress = true;
      return;
    }

    if (kDebugMode) {
      debugPrint('[PTT][UI] press down');
    }
    PttLogger.log(
      '[PTT][UI]',
      'press_down',
      meta: <String, Object?>{
        'at': now.toIso8601String(),
      },
    );

    _minHoldTimer?.cancel();
    final pressSeq = _pressSequence;
    _minHoldTimer = Timer(_minHoldDuration, () {
      if (!mounted || !_isPressed) {
        return;
      }
      unawaited(() async {
        final started =
            await _handlePressStart(DateTime.now());
        if (!mounted || pressSeq != _pressSequence || !_isPressed) {
          if (started) {
            unawaited(_handlePressEnd());
          }
          return;
        }
        _talkStartedForPress = started;
      }());
    });
  }

  Future<void> _onPressEnd(BuildContext context) async {
    final startedAt = _pressStartedAt;
    _minHoldTimer?.cancel();
    _minHoldTimer = null;
    setState(() {
      _isPressed = false;
      _pressStartedAt = null;
    });

    final int heldMs = startedAt == null
        ? 0
        : DateTime.now()
            .difference(startedAt)
            .inMilliseconds;
    PttLogger.log(
      '[PTT][UI]',
      'press_end',
      meta: <String, Object?>{
        'heldMs': heldMs,
      },
    );

    if (!_talkStartedForPress) {
      return;
    }

    _releaseTailTimer?.cancel();
    _releaseTailTimer = Timer(_releaseTailDuration, () {
      if (!mounted) {
        return;
      }
      unawaited(_handlePressEnd());
    });
  }

  @override
  void dispose() {
    _minHoldTimer?.cancel();
    _releaseTailTimer?.cancel();
    _holdProgressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final embeddedInTabs = widget.embeddedInTabs;

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
      appBar: embeddedInTabs
          ? null
          : AppBar(
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
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (embeddedInTabs) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        '무전',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
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
                  const SizedBox(height: AppSpacing.md),
                ],
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
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
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.subtleSurfaceGradient,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.brandGradient,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              hasTarget
                                  ? targetName.characters.first
                                  : '＋',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
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
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                        overflow:
                                            TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm,
                                        vertical: AppSpacing.xs,
                                      ),
                                      decoration: BoxDecoration(
                                        color: targetChipColor
                                            .withAlpha(31),
                                        borderRadius:
                                            BorderRadius.circular(
                                          AppRadii.md,
                                        ),
                                        border: Border.all(
                                          color: targetChipColor
                                              .withAlpha(128),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize:
                                            MainAxisSize.min,
                                        children: [
                                          Icon(
                                            targetChipIcon,
                                            size: 14,
                                            color: targetChipColor,
                                          ),
                                          const SizedBox(
                                            width: AppSpacing.xs,
                                          ),
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
                                                  color:
                                                      targetChipColor,
                                                  fontWeight:
                                                      FontWeight.w700,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
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
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _holdProgressController,
                      builder: (context, _) {
                        final bool isActive =
                            _isPressed || isTalking;

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
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (_) => _onPressDown(context),
                          onPointerUp: (_) =>
                              unawaited(_onPressEnd(context)),
                          onPointerCancel: (_) =>
                              unawaited(_onPressEnd(context)),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isActive)
                                Container(
                                  width: 244,
                                  height: 244,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        ringColor.withAlpha(80),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
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
                              if (isActive)
                                SizedBox(
                                  width: 216,
                                  height: 216,
                                  child:
                                      CircularProgressIndicator(
                                    value: 1,
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
                                duration: AppMotion.fast,
                                curve: AppMotion.standard,
                                width: isActive
                                    ? 188
                                    : 180,
                                height: isActive
                                    ? 188
                                    : 180,
                                decoration: BoxDecoration(
                                  color: buttonColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ringColor.withAlpha(
                                        isActive ? 89 : 38,
                                      ),
                                      blurRadius: 18,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  centerIcon,
                                  size: 44,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!hasTarget)
                      Text(
                        'Friends에서 무전 대상을 먼저 골라주세요.',
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
      ),
    );
  }
}
