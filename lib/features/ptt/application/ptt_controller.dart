// NOTE: 설계도 v1.1 기준 Walkie/Manner PTT 플로우를 구현하며, 쿨다운/레이트리밋 및 _isTalking 가드까지 반영된 상태다.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/services/platform/android_ptt_service.dart' as android_ptt;
import 'package:voyage/services/backend/backend_providers.dart';
import 'package:voyage/features/chat/application/chat_state.dart';
import 'package:voyage/features/chat/application/conversation_state.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/core/policy/policy_evaluator.dart';
import 'package:voyage/features/friends/application/friend_state.dart';
import 'package:voyage/features/friends/domain/walkie_consent.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';
import 'package:voyage/features/ptt/data/ptt_local_audio.dart';
import 'package:voyage/features/chat/application/chat_voice_player.dart';
import 'package:voyage/features/ptt/application/ptt_metrics.dart';
import 'package:voyage/features/ptt/data/ptt_session_config.dart';
import 'package:voyage/features/ptt/application/ptt_ui_event.dart';
import 'package:voyage/features/ptt/application/ptt_mode_provider.dart';
import 'package:voyage/features/ptt/data/voice_transport.dart';
import 'package:voyage/features/ptt/data/voice_transport_factory.dart';

enum PttTalkState {
  idle,
  talking,
}

class PttSessionContext {
  const PttSessionContext({
    required this.mode,
    this.targetFriendId,
    this.targetFriendName,
  });

  final PttMode mode;
  final String? targetFriendId;
  final String? targetFriendName;
}

/// 공통 PTT 컨트롤러.
///
/// UI에서는 `startTalk` / `stopTalk`만 호출하고,
/// 권한 확인, 전송 모드, 전송 구현은 이 컨트롤러가 담당한다.
class PttController {
  PttController({
    required VoiceTransport transport,
    PttMode initialMode = PttMode.manner,
    PttLocalAudioEngine? localAudio,
  })  : _transport = transport,
        mode = initialMode,
        _localAudio = localAudio ?? PttLocalAudioEngine();

  final VoiceTransport _transport;
  final PttLocalAudioEngine _localAudio;
  bool _localAudioInitialized = false;
  PttMode mode;
  bool _isPublishing = false;
  PttSessionContext? _lastContext;

  bool get isWalkie => mode == PttMode.walkie;

  PttSessionContext? get lastContext => _lastContext;

  /// 홀드-투-톡 시작.
  ///
  /// 실제 구현에서는:
  /// - 권한 확인
  /// - LiveKit/WebRTC 연결
  /// - Opus 인코딩 및 발행
  /// 등을 수행한다.
  Future<void> startTalk({
    required PttMode mode,
    String? targetFriendId,
    String? targetFriendName,
  }) async {
    this.mode = mode;
    final modeLabel = mode == PttMode.walkie ? 'walkie' : 'manner';
    final targetIdLabel = targetFriendId ?? '(none)';
    final targetNameLabel = targetFriendName ?? '(none)';

    _lastContext = PttSessionContext(
      mode: mode,
      targetFriendId: targetFriendId,
      targetFriendName: targetFriendName,
    );
    PttLogger.log(
      '[PTT] startTalk',
      'startTalk called',
      meta: <String, Object?>{
        'mode': modeLabel,
        'targetFriendId': targetIdLabel,
        'targetFriendName': targetNameLabel,
      },
    );

    // 매너/무전 모드 모두에서 녹음을 시작해 두고,
    // 모드에 따라 stop 시점에 어떻게 사용할지 결정한다.
    if (!_localAudioInitialized) {
      await _localAudio.init();
      _localAudioInitialized = true;
    }
    // 재생 중인 로컬 오디오가 있다면 중단한 뒤 녹음을 시작한다.
    try {
      await _localAudio.stopPlayback();
    } catch (e) {
      debugPrint(
        '[PTT][LocalAudio] stopPlayback before startRecording error: $e',
      );
    }
    await _localAudio.startRecording();
    if (_localAudio.sessionState != PttSessionState.recording) {
      // 마이크 권한 없음 등으로 녹음이 시작되지 않았으면
      // 네트워크/FGS/발행을 진행하지 않는다.
      PttLogger.log(
        '[PTT][Guard]',
        'startTalk aborted: recording not started',
        meta: <String, Object?>{
          'mode': modeLabel,
          'targetFriendId': targetIdLabel,
        },
      );
      return;
    }
    // 네트워크/즉시 재생 PTT는 Walkie 모드에서만 수행한다.
    // Manner 모드에서는 로컬 녹음/음성 노트만 사용한다.
    if (mode == PttMode.walkie) {
      if (FF.androidInstantPlay &&
          FF.enableAndroidPttForegroundService) {
        // 플랫폼/정책에 따라 즉시 재생 모드를 선택적으로 처리.
        await android_ptt.startPttService();
      }

      if (_isPublishing) {
        return;
      }

      await _transport.warmUp();
      await _transport.connect(url: 'noop', token: 'noop');
      await _transport.startPublishing(Stream<List<int>>.empty());
      _isPublishing = true;
    }
  }

  /// 홀드-투-톡 종료.
  Future<String?> stopTalk() async {
    final ctx = _lastContext;
    final modeLabel =
        ctx?.mode == PttMode.walkie ? 'walkie' : 'manner';
    final targetIdLabel = ctx?.targetFriendId ?? '(none)';
    final targetNameLabel = ctx?.targetFriendName ?? '(none)';
    PttLogger.log(
      '[PTT] stopTalk',
      'stopTalk called',
      meta: <String, Object?>{
        'mode': modeLabel,
        'targetFriendId': targetIdLabel,
        'targetFriendName': targetNameLabel,
      },
    );

    String? recordedPath;

    // 녹음 종료 + path 얻기 (walkie / manner 공통)
    if (_localAudioInitialized) {
      recordedPath = await _localAudio.stopRecordingAndGetPath();
    }

    final mode = ctx?.mode;

    final hasRecordedPath =
        recordedPath != null && recordedPath.isNotEmpty;
    final modeName = mode == PttMode.walkie ? 'walkie' : 'manner';
    PttLogger.log(
      '[PTT][stopTalk]',
      'stopTalk finished',
      meta: <String, Object?>{
        'mode': modeName,
        'hasPath': hasRecordedPath,
        'targetFriendId': targetIdLabel,
      },
    );

    // 즉시 재생은 walkie 모드에서만 수행
    if (mode == PttMode.walkie && recordedPath != null) {
      await _localAudio.playBeep();
      await _localAudio.playFromPath(recordedPath);
    }

    if (mode == PttMode.walkie &&
        FF.androidInstantPlay &&
        FF.enableAndroidPttForegroundService) {
      await android_ptt.stopPttService();
    }

    if (!_isPublishing) {
      // 매너모드에서는 상위에서 음성 노트를 저장할 수 있도록 path를 넘겨준다.
      return mode == PttMode.manner ? recordedPath : null;
    }

    await _transport.stopPublishing();
    await _transport.disconnect();
    await _transport.coolDown();
    _isPublishing = false;

    return mode == PttMode.manner ? recordedPath : null;
  }
}

  final pttControllerProvider =
      StateNotifierProvider<PttControllerNotifier, PttTalkState>(
  (ref) {
    final localAudio = ref.read(pttLocalAudioEngineProvider);
    // TODO(LATER_MVP2): 실제 사용자 ID 상태가 생기면 PttSessionConfig에 주입한다.
    const localUserId = 'me';
    return PttControllerNotifier(
      ref,
      PttController(
        transport: VoiceTransportFactory.create(
          policy: FF.policy,
          sessionConfig: PttSessionConfig.placeholder(
            localUserId: localUserId,
            remoteUserId: 'peer',
            mode: PttMode.manner,
          ),
        ),
        localAudio: localAudio,
      ),
    );
  },
);

/// Manual test – Manner voice message flow
///
/// 1) Friends 화면에서 친구 B를 길게 눌러
///    currentPttFriendIdProvider에 B.id를 설정한다.
/// 2) 홈 화면에서 모드를 Manner로 설정한다.
/// 3) PTT 버튼을 길게 눌러 몇 초간 말한 뒤 손을 뗀다.
/// 4) 기대 동작:
///    - PttLocalAudioEngine이 앱 내부 temp/ptt 디렉토리에
///      `ptt_<timestamp>.m4a` 파일을 생성한다.
///    - PttController.stopTalk()가 해당 파일 경로를 반환한다
///      (Walkie 모드에서는 null 반환).
///    - PttControllerNotifier.stopTalk()가
///      ChatMessagesNotifier.addVoiceMessage(...)를 호출한다.
///    - 친구 B와의 채팅방(ChatPage)에
///      ChatMessageType.voice 타입 음성 메시지 버블 1개가 추가된다.
/// 5) 로그에서 다음 키워드를 확인한다:
///    - [PTT] startTalk ...
///    - [PTT] stopTalk ...
///    - [PTT][notifier.stopTalk] ...
///    - [PTT][Manner][addVoice] ...
///    - [Chat] voice message added ...
///
/// Manual test – PTT policy (allow / block / cooldown)
///
/// 1) 친구 A를 Friends 화면에서 PTT 대상으로 설정한다.
/// 2) Friends > 더보기(⋮)에서 다음 케이스를 각각 테스트:
///    a) 무전 허용 ON, 차단 OFF:
///       - Walkie 모드에서 PTT → 즉시 재생 PTT 동작.
///    b) 무전 허용 OFF, 차단 OFF:
///       - Walkie 모드에서 PTT → 내부적으로 Manner로 다운그레이드되어
///         채팅에 음성 노트가 쌓이고, 즉시 재생은 하지 않을 수 있다.
///    c) 차단 ON:
///       - Walkie/Manner 모두에서 PTT 버튼을 눌러도 녹음/전송이 시작되지 않는다.
///       - 로그에 [PTT][Policy] startTalk blocked by friendBlock ... 이 찍힌다.
/// 3) 동일 친구에 대해 빠르게 여러 번 PTT를 눌러,
///    쿨다운(minIntervalMs)으로 [PTT][RateLimit] startTalk blocked by cooldown ...
///    로그가 찍히는지도 확인한다.
class PttControllerNotifier extends StateNotifier<PttTalkState> {
  PttControllerNotifier(this._ref, this._controller)
      : super(PttTalkState.idle);

  final Ref _ref;
  final PttController _controller;

  /// Whether a PTT session is currently active from the notifier's view.
  bool _isTalking = false;

  bool get isTalking => _isTalking;

  /// Last time PTT was started (for global cooldown).
  DateTime? _lastPttStartedAt;

  /// Recent PTT start timestamps per friend for spam protection.
  ///
  /// Used for both soft logging and hard friend-level cooldowns.
  final Map<String, List<DateTime>> _friendPttStarts = {};
  final Map<String, DateTime> _friendBurstBlockedUntil = {};
  DateTime? _lastUiHoldAt;

  Future<bool> startTalk({DateTime? uiHoldAt}) async {
    if (_isTalking) {
      PttLogger.log(
        '[PTT][Guard]',
        'startTalk ignored because session already active',
      );
      return false;
    }

    final requestedMode = _ref.read(pttModeProvider);
    final targetFriendId = _ref.read(currentPttFriendIdProvider);

    if (targetFriendId == null) {
      _ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.noFriendSelected(mode: requestedMode),
          );
      return false;
    }

    // targetFriendId는 위에서 null 가드 후 여기서는 항상 non-null이다.
    final now = DateTime.now();
    if (requestedMode == PttMode.walkie) {
      final blockedUntil = _friendBurstBlockedUntil[targetFriendId];
      if (blockedUntil != null && now.isBefore(blockedUntil)) {
        PttLogger.log(
          '[PTT][RateLimit]',
          'startTalk blocked by friend burst cooldown',
          meta: <String, Object?>{
            'friendId': targetFriendId,
            'until': blockedUntil.toIso8601String(),
          },
        );
        _ref.read(pttMetricsProvider.notifier).recordError(
              friendId: targetFriendId,
              mode: requestedMode,
              reason: 'burst_cooldown',
            );
        return false;
      }
    }
    final pttAllowMap = _ref.read(friendPttAllowProvider);
    final peerAllowMap = _ref.read(peerWalkieAllowProvider);

    final allowFromMe = pttAllowMap[targetFriendId] ?? false;
    final allowFromPeer = peerAllowMap[targetFriendId] ?? true;
    final consent = WalkieConsent(
      allowFromMe: allowFromMe,
      allowFromPeer: allowFromPeer,
    );
    final allowEffective = consent.isMutual;

    final blockMap = _ref.read(friendBlockProvider);
    final friendBlocked = blockMap[targetFriendId] ?? false;

    final DateTime startMark = uiHoldAt ?? now;
    _lastUiHoldAt = startMark;
    _ref.read(pttMetricsProvider.notifier).recordStartRequest(
          friendId: targetFriendId,
          mode: requestedMode,
          at: startMark,
        );

    const evaluator = PolicyEvaluator();
    final decision = evaluator.evaluateStartTalk(
      policy: FF.policy,
      requestedMode: requestedMode,
      allowEffective: allowEffective,
      friendBlocked: friendBlocked,
      now: now,
      lastPttStartedAt: _lastPttStartedAt,
    );

    if (!decision.canStart) {
      switch (decision.blockReason) {
        case PolicyBlockReason.friendBlocked:
          PttLogger.log(
            '[PTT][Policy]',
            'startTalk blocked by friendBlock',
            meta: <String, Object?>{
              'friendId': targetFriendId,
            },
          );
          _ref.read(pttMetricsProvider.notifier).recordError(
                friendId: targetFriendId,
                mode: requestedMode,
                reason: 'blocked',
              );
          _ref.read(pttUiEventProvider.notifier).emit(
                PttUiEvents.friendBlocked(friendId: targetFriendId),
              );
          return false;
        case PolicyBlockReason.cooldown:
          final sinceLastMs = decision.sinceLastMs ?? 0;
          final minIntervalMs =
              decision.minIntervalMs ?? FF.pttMinIntervalMillis;
          PttLogger.log(
            '[PTT][RateLimit]',
            'startTalk blocked by cooldown',
            meta: <String, Object?>{
              'sinceLastMs': sinceLastMs,
              'minIntervalMs': minIntervalMs,
              'friendId': targetFriendId,
            },
          );
          _ref.read(pttMetricsProvider.notifier).recordError(
                friendId: targetFriendId,
                mode: requestedMode,
                reason: 'cooldown',
              );
          _ref.read(pttUiEventProvider.notifier).emit(
                PttUiEvents.cooldownBlocked(
                  friendId: targetFriendId,
                  sinceLastMs: sinceLastMs,
                  minIntervalMs: minIntervalMs,
                  mode: requestedMode,
                ),
              );
          return false;
        case null:
          break;
      }
    }

    // Friend-level spam protection:
    // If a user spams walkie starts within a short window,
    // apply a temporary cooldown for that friend.
    const windowSeconds = 10;
    const hardLimit = 6;
    const burstCooldownSeconds = 8;
    const softLimit = 4;

    final previous = _friendPttStarts[targetFriendId] ?? <DateTime>[];
    final recent = previous
        .where(
          (t) => now.difference(t).inSeconds < windowSeconds,
        )
        .toList();
    recent.add(now);
    _friendPttStarts[targetFriendId] = recent;

    if (requestedMode == PttMode.walkie &&
        recent.length > hardLimit) {
      final until =
          now.add(const Duration(seconds: burstCooldownSeconds));
      _friendBurstBlockedUntil[targetFriendId] = until;
      PttLogger.log(
        '[PTT][RateLimit]',
        'friend burst hard cooldown applied',
        meta: <String, Object?>{
          'friendId': targetFriendId,
          'count': recent.length,
          'windowSeconds': windowSeconds,
          'cooldownSeconds': burstCooldownSeconds,
        },
      );
      _ref.read(pttMetricsProvider.notifier).recordError(
            friendId: targetFriendId,
            mode: requestedMode,
            reason: 'burst_hard',
          );
      return false;
    }

    if (recent.length > softLimit) {
      PttLogger.log(
        '[PTT][RateLimit]',
        'friend burst soft',
        meta: <String, Object?>{
          'friendId': targetFriendId,
          'count': recent.length,
          'windowSeconds': windowSeconds,
        },
      );
    }

    if (requestedMode == PttMode.manner) {
      _ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.mannerModeNoInstantPtt(
              friendId: targetFriendId,
            ),
          );
    }

    final effectiveMode = decision.effectiveMode;
    if (decision.downgradedToManner) {
      _ref.read(pttUiEventProvider.notifier).emit(
            PttUiEvents.friendNotAllowWalkie(
              friendId: targetFriendId,
            ),
          );
    }

    String? targetFriendName;
    final friends = _ref.read(friendListProvider);
    final matches =
        friends.where((f) => f.id == targetFriendId);
    if (matches.isNotEmpty) {
      targetFriendName = matches.first.name;
    }

    final requestedLabel =
        requestedMode == PttMode.walkie ? 'walkie' : 'manner';
    final effectiveLabel =
        effectiveMode == PttMode.walkie ? 'walkie' : 'manner';

    PttLogger.log(
      '[PTT] notifier.startTalk',
      'startTalk accepted',
      meta: <String, Object?>{
        'requestedMode': requestedLabel,
        'effectiveMode': effectiveLabel,
        'friendAllowed': allowEffective,
        'allowFromMe': allowFromMe,
        'allowFromPeer': allowFromPeer,
        'allowEffective': allowEffective,
        'targetFriendId': targetFriendId,
      },
    );

    try {
      await _controller.startTalk(
        mode: effectiveMode,
        targetFriendId: targetFriendId,
        targetFriendName: targetFriendName,
      );
      final DateTime end = DateTime.now();
      final DateTime origin = _lastUiHoldAt ?? now;
      final int ttpMillis =
          end.millisecondsSinceEpoch - origin.millisecondsSinceEpoch;
      _ref.read(pttMetricsProvider.notifier).recordSuccess(
            friendId: targetFriendId,
            mode: effectiveMode,
            ttpMillis: ttpMillis,
          );
      PttLogger.log(
        '[PTT][TTP]',
        'success',
        meta: <String, Object?>{
          'mode': effectiveLabel,
          'friendId': targetFriendId,
          'ttpMs': ttpMillis,
        },
      );
      _lastPttStartedAt = now;
      _isTalking = true;
      state = PttTalkState.talking;
      return true;
    } catch (e) {
      _ref.read(pttMetricsProvider.notifier).recordError(
            friendId: targetFriendId,
            mode: effectiveMode,
            reason: 'start_error',
          );
      PttLogger.log(
        '[PTT][TTP]',
        'error on startTalk',
        meta: <String, Object?>{
          'mode': effectiveLabel,
          'friendId': targetFriendId,
          'error': e.toString(),
        },
      );
      return false;
    }
  }

  Future<void> stopTalk({String reason = 'manual'}) async {
    String? path;
    try {
      path = await _controller.stopTalk();
    } catch (e) {
      PttLogger.log(
        '[PTT][Guard]',
        'stopTalk error',
        meta: <String, Object?>{
          'reason': reason,
          'error': e.toString(),
        },
      );
    } finally {
      if (_isTalking) {
        _isTalking = false;
        state = PttTalkState.idle;
        PttLogger.log(
          '[PTT][State]',
          'isTalking -> false',
          meta: <String, Object?>{
            'reason': reason,
          },
        );
      }
    }

    final ctx = _controller.lastContext;
    final mode = ctx?.mode;
    final targetFriendId = ctx?.targetFriendId;

    final modeName = mode?.name ?? 'null';
    final hasPath = path != null && path.isNotEmpty;
    PttLogger.log(
      '[PTT][notifier.stopTalk]',
      'stopTalk',
      meta: <String, Object?>{
        'mode': modeName,
        'targetFriendId': targetFriendId ?? '(none)',
        'hasPath': hasPath,
        'reason': reason,
      },
    );

    // 대상/녹음 경로가 없으면 아무 것도 하지 않는다.
    if (targetFriendId == null || path == null) {
      return;
    }

    try {
      final friends = _ref.read(friendListProvider);
      String? friendName;
      final matches =
          friends.where((friend) => friend.id == targetFriendId);
      if (matches.isNotEmpty) {
        friendName = matches.first.name;
      }

      final pathLen = path.length;
      PttLogger.log(
        '[PTT][Manner][addVoice]',
        'add voice message',
        meta: <String, Object?>{
          'chatId': targetFriendId,
          'pathLen': pathLen,
        },
      );

      int? durationMillis;
      try {
        final localAudio =
            _ref.read(pttLocalAudioEngineProvider);
        durationMillis =
            await localAudio.probeDurationMillis(path);
        if (durationMillis == null) {
          PttLogger.log(
            '[PTT][Manner][duration]',
            'probeDurationMillis returned null',
            meta: <String, Object?>{
              'chatId': targetFriendId,
              'pathLen': pathLen,
            },
          );
        } else {
          PttLogger.log(
            '[PTT][Manner][duration]',
            'probeDurationMillis success',
            meta: <String, Object?>{
              'chatId': targetFriendId,
              'durationMillis': durationMillis,
            },
          );
        }
      } catch (e, st) {
        PttLogger.log(
          '[PTT][Manner][duration]',
          'probeDurationMillis error',
          meta: <String, Object?>{
            'chatId': targetFriendId,
            'error': e.toString(),
          },
        );
        debugPrint(st.toString());
      }

      final String uploadPath = path;

      // 매너모드: 별도의 미디어 저장소 업로드(예: S3/Cloud Storage)를 수행한다.
      // Walkie 모드에서는 실시간 PTT 채널과의 정합성을 위해
      // ChatMessagesNotifier 경로만 사용하고, 여기서는 업로드하지 않는다.
      if (mode == PttMode.manner) {
        _ref
            .read(pttMediaRepositoryProvider)
            .uploadVoice(
              uploadPath,
              chatId: targetFriendId,
              friendId: targetFriendId,
            )
            .catchError((Object error, StackTrace stackTrace) {
          PttLogger.log(
            '[PTT][Manner][uploadVoice]',
            'upload failed',
            meta: <String, Object?>{
              'targetFriendId': targetFriendId,
              'error': error.toString(),
            },
          );
          return uploadPath;
        });
      }

      // Walkie / Manner 공통:
      // 방금 녹음한 음성을 음성 메시지(voice)로 채팅에 저장하고,
      // ChatRepository가 업로드/전송 성공 여부를 sendStatus로 관리한다.
      _ref.read(chatMessagesProvider.notifier).addVoiceMessage(
            chatId: targetFriendId,
            audioPath: uploadPath,
            durationMillis: durationMillis,
            fromMe: true,
          );

      _ref.read(conversationListProvider.notifier).upsertFromMessage(
            chatId: targetFriendId,
            title: friendName ?? targetFriendId,
            subtitle: '음성 메시지',
            updatedAt: DateTime.now(),
          );
    } catch (e) {
      final bool hasPath = path.isNotEmpty;
      PttLogger.log(
        '[PTT][notifier.stopTalk]',
        'error while adding voice',
        meta: <String, Object?>{
          'mode': 'manner',
          'hasPath': hasPath,
          'targetFriendId': targetFriendId,
          'error': e.toString(),
        },
      );
    }
  }
}
