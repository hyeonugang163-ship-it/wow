import AVFoundation
import Foundation

/// NOTE: 설계도 v1.1 기준 iOS AudioSession 헬퍼 스텁.
///
/// - 현재 리포는 Windows + Android 환경에서만 실제 실행/테스트 되었으며,
///   이 코드는 Mac + Xcode + 실제 iOS 디바이스에서 나중에 빌드/검증 및
///   세부 튜닝이 필요하다.
/// - PushToTalk(B안) 도입 시에는 별도의 AudioSession 정책이 필요할 수 있다.
enum AudioSessionHelper {
  /// PTT / 음성 채팅에 적합한 기본 AudioSession 설정을 시도한다.
  ///
  /// 실제 배포 전에는 디바이스/OS별로 카테고리/옵션을 반드시 재검증할 것.
  static func configureForPtt() {
    let session = AVAudioSession.sharedInstance()
    do {
      if #available(iOS 10.0, *) {
        try session.setCategory(
          .playAndRecord,
          mode: .voiceChat,
          options: [.duckOthers, .allowBluetooth]
        )
      } else {
        try session.setCategory(.playAndRecord)
      }
      try session.setActive(true)
    } catch {
      NSLog("[PTT][iOS][AudioSession] configureForPtt error: \(error)")
    }
  }

  /// PTT 세션 종료 후 AudioSession을 비활성화한다.
  static func deactivate() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setActive(false)
    } catch {
      NSLog("[PTT][iOS][AudioSession] deactivate error: \(error)")
    }
  }
}

