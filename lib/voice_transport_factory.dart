import 'package:voyage/feature_flags.dart';
import 'package:voyage/ptt_debug_log.dart';
import 'package:voyage/ptt_session_config.dart';
import 'package:voyage/voice_transport.dart';
import 'package:voyage/voice_transport_livekit.dart';
import 'package:voyage/voice_transport_local_fake.dart';

class VoiceTransportFactory {
  /// VoiceTransport 구현을 선택한다.
  ///
  /// 현재 기본값은 항상 LocalFakeVoiceTransport이며,
  /// PolicyConfig.useFakeVoiceTransport가 false이고
  /// LiveKit 세션 구성이 주어졌을 때만 LiveKitVoiceTransport를 사용하도록
  /// 확장할 수 있다.
  static VoiceTransport create({
    required PolicyConfig policy,
    PttSessionConfig? sessionConfig,
  }) {
    if (policy.useFakeVoiceTransport || sessionConfig == null) {
      PttLogger.log(
        '[PTT][Transport]',
        'using LocalFakeVoiceTransport',
      );
      return LocalFakeVoiceTransport();
    }

    PttLogger.log(
      '[PTT][Transport]',
      'using LiveKitVoiceTransport (stub)',
      meta: <String, Object?>{
        'roomName': sessionConfig.roomName,
      },
    );
    return LiveKitVoiceTransport(sessionConfig: sessionConfig);
  }
}

