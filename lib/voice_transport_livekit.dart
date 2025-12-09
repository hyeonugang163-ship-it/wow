// NOTE: 설계도 v1.1 기준 LiveKit/SFU 전송 엔진 뼈대 구현.
//
// 현재 단계에서는 LiveKit 서버/토큰 환경이 없으므로,
// 실제 네트워크 연결/미디어 전송은 수행하지 않고,
// VoiceTransport 인터페이스를 만족하는 최소한의 구조와
// PttLogger 기반 메타데이터 로그만 제공한다.
//
// 나중에 Mac + iOS + 실제 LiveKit 서버 환경에서
// Room/Track 연결, Opus publish/subscribe, jitter buffer 설정 등을
// 이 파일 내부에서 구현하면 된다.

import 'dart:async';

import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_session_config.dart';
import 'package:voyage/voice_transport.dart';

class LiveKitVoiceTransport implements VoiceTransport {
  LiveKitVoiceTransport({
    required PttSessionConfig sessionConfig,
  }) : _sessionConfig = sessionConfig;

  final PttSessionConfig _sessionConfig;

  final StreamController<List<int>> _incomingController =
      StreamController<List<int>>.broadcast();

  bool _connected = false;

  @override
  Stream<List<int>> get incomingOpus => _incomingController.stream;

  @override
  Future<void> warmUp() async {
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'warmUp',
      meta: <String, Object?>{
        'room': _sessionConfig.roomName,
      },
    );
  }

  @override
  Future<void> connect({
    required String url,
    required String token,
  }) async {
    // NOTE: 현재는 실제 LiveKit 서버에 연결하지 않고,
    // roomName / localUserId / remoteUserId 등 메타데이터만 로그로 남긴다.
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'connect called (stub)',
      meta: <String, Object?>{
        'serverUrl': _sessionConfig.serverUrl.toString(),
        'roomName': _sessionConfig.roomName,
        'localUserId': _sessionConfig.localUserId,
        'remoteUserId': _sessionConfig.remoteUserId,
      },
    );
    _connected = true;
  }

  @override
  Future<void> startPublishing(Stream<List<int>> opus) async {
    // TODO: 실제 구현 시에는 로컬 마이크/Opus 스트림을
    // LiveKit LocalTrack에 publish 하도록 연결해야 한다.
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'startPublishing (stub)',
      meta: <String, Object?>{
        'roomName': _sessionConfig.roomName,
      },
    );
    // 현재는 Fake와 동일하게 아무 것도 하지 않는다.
  }

  @override
  Future<void> stopPublishing() async {
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'stopPublishing (stub)',
      meta: <String, Object?>{
        'roomName': _sessionConfig.roomName,
      },
    );
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) {
      return;
    }
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'disconnect (stub)',
      meta: <String, Object?>{
        'roomName': _sessionConfig.roomName,
      },
    );
    _connected = false;
  }

  @override
  Future<void> coolDown() async {
    // TODO: 실제 구현 시에는 유휴 타이머 이후 Room disconnect 등을 수행한다.
    PttLogger.log(
      '[PTT][Transport][LiveKit]',
      'coolDown (stub)',
      meta: <String, Object?>{
        'roomName': _sessionConfig.roomName,
      },
    );
  }
}

