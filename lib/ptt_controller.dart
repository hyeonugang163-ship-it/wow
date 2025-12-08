import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/android_ptt_service.dart' as android_ptt;
import 'package:voyage/chat_state.dart';
import 'package:voyage/conversation_state.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/friend_state.dart';
import 'package:voyage/ptt_local_audio.dart';
import 'package:voyage/chat_voice_player.dart';
import 'package:voyage/voice_transport.dart';

enum PttTalkState {
  idle,
  talking,
}

final pttModeProvider = StateProvider<PttMode>(
  (ref) => PttMode.manner,
);

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
    VoiceTransport? transport,
    PttMode initialMode = PttMode.manner,
    PttLocalAudioEngine? localAudio,
  })  : _transport = transport ?? _NoopVoiceTransport(),
        _mode = initialMode,
        _localAudio = localAudio ?? PttLocalAudioEngine();

  final VoiceTransport _transport;
  final PttLocalAudioEngine _localAudio;
  bool _localAudioInitialized = false;
  PttMode _mode;
  bool _isPublishing = false;
  PttSessionContext? _lastContext;

  PttMode get mode => _mode;

  set mode(PttMode value) {
    _mode = value;
  }

  bool get isWalkie => _mode == PttMode.walkie;

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
    _mode = mode;
    final modeLabel = mode == PttMode.walkie ? 'walkie' : 'manner';
    final targetIdLabel = targetFriendId ?? '(none)';
    final targetNameLabel = targetFriendName ?? '(none)';

    _lastContext = PttSessionContext(
      mode: mode,
      targetFriendId: targetFriendId,
      targetFriendName: targetFriendName,
    );

    // NOTE: 운영 환경에서는 사용자 이름 대신 id 위주의 메타데이터만
    // 로그로 남기는 것이 바람직하다.
    print(
      '[PTT] startTalk called. '
      'mode=$modeLabel '
      'target_friend_id=$targetIdLabel '
      'target_friend_name=$targetNameLabel',
    );

    // 매너/무전 모드 모두에서 녹음을 시작해 두고,
    // 모드에 따라 stop 시점에 어떻게 사용할지 결정한다.
    if (!_localAudioInitialized) {
      await _localAudio.init();
      _localAudioInitialized = true;
    }
    await _localAudio.startRecording();

    if (isWalkie && FF.androidInstantPlay) {
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

  /// 홀드-투-톡 종료.
  Future<String?> stopTalk() async {
    final ctx = _lastContext;
    final modeLabel =
        ctx?.mode == PttMode.walkie ? 'walkie' : 'manner';
    final targetIdLabel = ctx?.targetFriendId ?? '(none)';
    final targetNameLabel = ctx?.targetFriendName ?? '(none)';

    print(
      '[PTT] stopTalk called. '
      'mode=$modeLabel '
      'target_friend_id=$targetIdLabel '
      'target_friend_name=$targetNameLabel',
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
    print(
      '[PTT][stopTalk] mode=$modeName '
      'hasPath=$hasRecordedPath '
      'target_friend_id=$targetIdLabel',
    );

    // 즉시 재생은 walkie 모드에서만 수행
    if (mode == PttMode.walkie && recordedPath != null) {
      await _localAudio.playFromPath(recordedPath);
    }

    if (mode == PttMode.walkie && FF.androidInstantPlay) {
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

/// 아직 전송 엔진이 준비되지 않은 상태에서
/// 앱을 컴파일/실행할 수 있도록 하는 No-op 구현.
class _NoopVoiceTransport implements VoiceTransport {
  @override
  Future<void> connect({required String url, required String token}) async {
    print('[PTT][NoopVoiceTransport] connect() called');
  }

  @override
  Future<void> coolDown() async {
    print('[PTT][NoopVoiceTransport] coolDown() called');
  }

  @override
  Future<void> disconnect() async {
    print('[PTT][NoopVoiceTransport] disconnect() called');
  }

  @override
  Stream<List<int>> get incomingOpus => const Stream.empty();

  @override
  Future<void> startPublishing(Stream<List<int>> opus) async {
    print('[PTT][NoopVoiceTransport] startPublishing() called');
  }

  @override
  Future<void> stopPublishing() async {
    print('[PTT][NoopVoiceTransport] stopPublishing() called');
  }

  @override
  Future<void> warmUp() async {
    print('[PTT][NoopVoiceTransport] warmUp() called');
  }
}

  final pttControllerProvider =
      StateNotifierProvider<PttControllerNotifier, PttTalkState>(
  (ref) {
    final localAudio = ref.read(pttLocalAudioEngineProvider);
    return PttControllerNotifier(
      ref,
      PttController(localAudio: localAudio),
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
///      ptt_<timestamp>.m4a 파일을 생성한다.
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

  /// Last time PTT was started (for global cooldown).
  DateTime? _lastPttStartedAt;

  /// Recent PTT start timestamps per friend for soft rate-limit logging.
  ///
  /// Used only for analytics / future policy hooks; 현재 단계에서는
  /// 실제 블록 대신 로그만 남긴다.
  final Map<String, List<DateTime>> _friendPttStarts = {};

  Future<void> startTalk() async {
    final requestedMode = _ref.read(pttModeProvider);
    final targetFriendId = _ref.read(currentPttFriendIdProvider);

    final pttAllowMap = _ref.read(friendPttAllowProvider);
    var friendAllowed = false;
    if (targetFriendId != null) {
      friendAllowed = pttAllowMap[targetFriendId] ?? false;
    }

    final blockMap = _ref.read(friendBlockProvider);
    var friendBlocked = false;
    if (targetFriendId != null) {
      friendBlocked = blockMap[targetFriendId] ?? false;
    }

    if (friendBlocked) {
      print(
        '[PTT][Policy] startTalk blocked by friendBlock '
        'friendId=$targetFriendId',
      );
      return;
    }

    final now = DateTime.now();
    final minIntervalMs = FF.pttMinIntervalMillis;
    if (_lastPttStartedAt != null && minIntervalMs > 0) {
      final sinceLastMs =
          now.millisecondsSinceEpoch -
              _lastPttStartedAt!.millisecondsSinceEpoch;
      if (sinceLastMs < minIntervalMs) {
        print(
          '[PTT][RateLimit] startTalk blocked by cooldown '
          'sinceLastMs=$sinceLastMs '
          'minIntervalMs=$minIntervalMs '
          'friendId=${targetFriendId ?? '(none)'}',
        );
        return;
      }
    }

    if (targetFriendId != null) {
      final windowSeconds = 60;
      const softLimit = 20;

      final previous = _friendPttStarts[targetFriendId] ?? <DateTime>[];
      final recent = previous
          .where(
            (t) => now.difference(t).inSeconds < windowSeconds,
          )
          .toList();
      recent.add(now);
      _friendPttStarts[targetFriendId] = recent;

      if (recent.length > softLimit) {
        print(
          '[PTT][RateLimit] friend burst friendId=$targetFriendId '
          'count=${recent.length} windowSeconds=$windowSeconds',
        );
        // TODO: hard block or soft warn on too many PTT in short time.
      }
    }

    var effectiveMode = requestedMode;
    if (requestedMode == PttMode.walkie && !friendAllowed) {
      effectiveMode = PttMode.manner;
    }

    String? targetFriendName;
    if (targetFriendId != null) {
      final friends = _ref.read(friendListProvider);
      final matches =
          friends.where((f) => f.id == targetFriendId);
      if (matches.isNotEmpty) {
        targetFriendName = matches.first.name;
      }
    }

    final requestedLabel =
        requestedMode == PttMode.walkie ? 'walkie' : 'manner';
    final effectiveLabel =
        effectiveMode == PttMode.walkie ? 'walkie' : 'manner';

    print(
      '[PTT] notifier.startTalk: '
      'requestedMode=$requestedLabel '
      'friendAllowed=$friendAllowed '
      'cooldownOk=true '
      'effectiveMode=$effectiveLabel '
      'target_friend_id=${targetFriendId ?? '(none)'}',
    );

    await _controller.startTalk(
      mode: effectiveMode,
      targetFriendId: targetFriendId,
      targetFriendName: targetFriendName,
    );
    _lastPttStartedAt = now;
    state = PttTalkState.talking;
  }

  Future<void> stopTalk() async {
    final path = await _controller.stopTalk();
    state = PttTalkState.idle;

    final ctx = _controller.lastContext;
    final mode = ctx?.mode;
    final targetFriendId = ctx?.targetFriendId;

    final modeName = mode?.name ?? 'null';
    final hasPath = path != null && path.isNotEmpty;
    print(
      '[PTT][notifier.stopTalk] '
      'ctxMode=$modeName '
      'target_friend_id=${targetFriendId ?? '(none)'} '
      'hasPath=$hasPath',
    );

    // 매너모드가 아니거나, 대상/녹음 경로가 없으면 아무 것도 하지 않는다.
    if (mode != PttMode.manner || targetFriendId == null || path == null) {
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
      print(
        '[PTT][Manner][addVoice] '
        'chatId=$targetFriendId pathLen=$pathLen',
      );

      // 매너모드: 방금 녹음한 음성을 음성 메시지(voice)로 채팅에 저장한다.
      _ref.read(chatMessagesProvider.notifier).addVoiceMessage(
            chatId: targetFriendId,
            audioPath: path,
            // TODO: 실제 음성 길이를 계산해서 durationMillis에 채운다.
            durationMillis: null,
            fromMe: true,
          );

      _ref.read(conversationListProvider.notifier).upsertFromMessage(
            chatId: targetFriendId,
            title: friendName ?? targetFriendId,
            subtitle: '음성 메시지',
            updatedAt: DateTime.now(),
          );
    } catch (e) {
      final hasPath = path.isNotEmpty;
      // 메타데이터 위주 로그 (내용/경로는 남기지 않음).
      // ignore: avoid_print
      print(
        '[PTT] notifier.stopTalk error: '
        'mode=manner hasPath=$hasPath target_friend_id=$targetFriendId error=$e',
      );
    }
  }
}
