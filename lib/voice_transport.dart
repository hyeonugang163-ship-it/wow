// NOTE: 설계도 v1.1 기준 VoiceTransport 인터페이스와 일치하며, 현재는 No-op/Fake 구현만 사용한다.

abstract class VoiceTransport {
  Future<void> connect({
    required String url,
    required String token,
  });

  /// 수신(압축 데이터)
  Stream<List<int>> get incomingOpus;

  /// 송신 시작
  Future<void> startPublishing(Stream<List<int>> opus);

  /// 송신 종료
  Future<void> stopPublishing();

  /// 연결 종료
  Future<void> disconnect();

  /// 인코더/플레이어 초기화, pre-connect 등
  Future<void> warmUp();

  /// 유휴 타이머 후 완전 disconnect
  Future<void> coolDown();
}
