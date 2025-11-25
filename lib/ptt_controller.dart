import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voyage/feature_flags.dart';
import 'package:voyage/voice_transport.dart';

enum PttTalkState {
  idle,
  talking,
}

final pttModeProvider = StateProvider<PttMode>(
  (ref) => PttMode.manner,
);

/// 공통 PTT 컨트롤러.
///
/// UI에서는 `startTalk` / `stopTalk`만 호출하고,
/// 권한 확인, 전송 모드, 전송 구현은 이 컨트롤러가 담당한다.
class PttController {
  PttController({
    VoiceTransport? transport,
    PttMode initialMode = PttMode.manner,
  })  : _transport = transport ?? _NoopVoiceTransport(),
        _mode = initialMode;

  final VoiceTransport _transport;
  PttMode _mode;

  PttMode get mode => _mode;

  set mode(PttMode value) {
    _mode = value;
  }

  bool get isWalkie => _mode == PttMode.walkie;

  /// 홀드-투-톡 시작.
  ///
  /// 실제 구현에서는:
  /// - 권한 확인
  /// - LiveKit/WebRTC 연결
  /// - Opus 인코딩 및 발행
  /// 등을 수행한다.
  Future<void> startTalk(PttMode mode) async {
    _mode = mode;
    final label = mode == PttMode.walkie ? 'instant' : 'manner';
    print('[PTT] startTalk called. mode=$label');
    // v1.1 뼈대: 아직 전송 구현 없음.
    // 이후 LiveKitTransport를 주입해 실제 전송을 구현한다.
    if (isWalkie && FF.androidInstantPlay) {
      // 플랫폼/정책에 따라 즉시 재생 모드를 선택적으로 처리.
    }
  }

  /// 홀드-투-톡 종료.
  Future<void> stopTalk() async {
    // 후속 구현에서 발행 종료 및 상태 정리를 수행.
    print('[PTT] stopTalk called.');
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
  (ref) => PttControllerNotifier(ref, PttController()),
);

class PttControllerNotifier extends StateNotifier<PttTalkState> {
  PttControllerNotifier(this._ref, this._controller)
      : super(PttTalkState.idle);

  final Ref _ref;
  final PttController _controller;

  Future<void> startTalk() async {
    final mode = _ref.read(pttModeProvider);
    await _controller.startTalk(mode);
    state = PttTalkState.talking;
  }

  Future<void> stopTalk() async {
    await _controller.stopTalk();
    state = PttTalkState.idle;
  }
}
