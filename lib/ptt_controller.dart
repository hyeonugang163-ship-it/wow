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

class PttControllerNotifier extends StateNotifier<PttTalkState> {
  PttControllerNotifier(this._ref, this._controller)
      : super(PttTalkState.idle);

  final Ref _ref;
  final PttController _controller;

  Future<void> startTalk() async {
    final requestedMode = _ref.read(pttModeProvider);
    final targetFriendId = _ref.read(currentPttFriendIdProvider);

    final pttAllowMap = _ref.read(friendPttAllowProvider);
    var friendAllowed = false;
    if (targetFriendId != null) {
      friendAllowed = pttAllowMap[targetFriendId] ?? false;
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
      'effectiveMode=$effectiveLabel '
      'target_friend_id=${targetFriendId ?? '(none)'}',
    );

    await _controller.startTalk(
      mode: effectiveMode,
      targetFriendId: targetFriendId,
      targetFriendName: targetFriendName,
    );
    state = PttTalkState.talking;
  }

  Future<void> stopTalk() async {
    final path = await _controller.stopTalk();
    state = PttTalkState.idle;

    final ctx = _controller.lastContext;
    final mode = ctx?.mode;
    final targetFriendId = ctx?.targetFriendId;

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
