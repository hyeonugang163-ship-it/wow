// NOTE: 설계도 v1.1 기준 VoiceTransport를 따르는 로컬 테스트용 Fake 구현 (실제 네트워크 전송은 수행하지 않음).

import 'dart:async';

import 'package:voyage/ptt_debug_log.dart';
import 'voice_transport.dart';

/// 네트워크 없이 로컬에서만 녹음/재생을 테스트하기 위한
/// Local Fake 구현 (현재는 No-op 스텁).
///
/// flutter_sound / path_provider 의존성을 제거하기 위해
/// 실제 녹음/재생은 수행하지 않고, 메서드 호출 로그만 남긴다.
class LocalFakeVoiceTransport implements VoiceTransport {
  @override
  Stream<List<int>> get incomingOpus => const Stream.empty();

  @override
  Future<void> warmUp() async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'warmUp',
    );
  }

  @override
  Future<void> connect({required String url, required String token}) async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'connect',
      meta: <String, Object?>{
        'url': url,
      },
    );
  }

  @override
  Future<void> startPublishing(Stream<List<int>> opus) async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'startPublishing',
    );
  }

  @override
  Future<void> stopPublishing() async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'stopPublishing',
    );
  }

  @override
  Future<void> disconnect() async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'disconnect',
    );
  }

  @override
  Future<void> coolDown() async {
    PttLogger.log(
      '[PTT][LocalFakeVoiceTransport]',
      'coolDown',
    );
  }
}
