import 'package:voyage/feature_flags.dart';

/// PTT 세션/룸/토큰 구성을 표현하는 모델.
///
/// 현재 단계에서는 LiveKit/SFU 서버가 없으므로,
/// serverUrl / token 에는 placeholder 값만 사용하고,
/// roomName 규칙과 local/remote user id, PttMode 정도만 유지한다.
class PttSessionConfig {
  const PttSessionConfig({
    required this.serverUrl,
    required this.roomName,
    required this.token,
    required this.localUserId,
    required this.remoteUserId,
    required this.mode,
  });

  final Uri serverUrl;
  final String roomName;
  final String token;
  final String localUserId;
  final String remoteUserId;
  final PttMode mode;

  /// 간단한 1:1 PTT 룸 네이밍 규칙.
  ///
  /// 예: userA / userB → "ptt_userA_userB" (사전순 정렬).
  static String roomNameForPair({
    required String localUserId,
    required String remoteUserId,
  }) {
    final ids = <String>[localUserId, remoteUserId]..sort();
    return 'ptt_${ids[0]}_${ids[1]}';
  }

  /// Placeholder 세션 구성을 생성한다.
  ///
  /// - serverUrl: "https://example.livekit.server" (TODO)
  /// - token: "TODO_TOKEN" (서버에서 JWT/AccessToken 받아오는 것으로 교체 필요)
  static PttSessionConfig placeholder({
    required String localUserId,
    required String remoteUserId,
    required PttMode mode,
  }) {
    final room = roomNameForPair(
      localUserId: localUserId,
      remoteUserId: remoteUserId,
    );
    return PttSessionConfig(
      serverUrl: Uri.parse('https://example.livekit.server'),
      roomName: room,
      token: 'TODO_TOKEN',
      localUserId: localUserId,
      remoteUserId: remoteUserId,
      mode: mode,
    );
  }
}

