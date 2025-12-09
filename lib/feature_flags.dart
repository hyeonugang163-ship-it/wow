// NOTE: 설계도 v1.1 기준 PolicyConfig/FF 구조와 거의 일치하며, PTT 쿨다운/Android FGS 플래그를 추가로 포함한다.

enum PttMode {
  walkie, // 무전모드 (즉시 재생 시도)
  manner, // 매너모드 (녹음본 수신)
}

class PolicyConfig {
  final bool androidInstantPlay; // Android FGS 즉시 재생 허용 여부
  final bool enableAndroidPttForegroundService; // Android PTT ForegroundService 사용 여부
  final bool iosModeA_PushTapPlay; // iOS A안 활성
  final bool iosModeB_PTTFramework; // iOS B안(PushToTalk) 활성
  final bool callKitVoip; // iOS VoIP Push + CallKit 사용 여부
  final bool forceTurnTcpTls443; // TURN 443 강제 여부
  final int pttMinIntervalMillis; // PTT 호출 간 최소 간격(ms) - 글로벌 쿨다운
  final bool useFakeVoiceTransport; // true이면 항상 LocalFakeVoiceTransport 사용
  final bool useFakeBackend; // true이면 Fake backend/repositories 사용

  const PolicyConfig({
    required this.androidInstantPlay,
    required this.enableAndroidPttForegroundService,
    required this.iosModeA_PushTapPlay,
    required this.iosModeB_PTTFramework,
    required this.callKitVoip,
    required this.forceTurnTcpTls443,
    required this.pttMinIntervalMillis,
    required this.useFakeVoiceTransport,
    required this.useFakeBackend,
  });

  factory PolicyConfig.fromJson(Map<String, dynamic> json) {
    return PolicyConfig(
      androidInstantPlay: (json['androidInstantPlay'] as bool?) ?? true,
      enableAndroidPttForegroundService:
          (json['enableAndroidPttForegroundService'] as bool?) ?? true,
      iosModeA_PushTapPlay: (json['iosModeA_PushTapPlay'] as bool?) ?? true,
      iosModeB_PTTFramework: (json['iosModeB_PTTFramework'] as bool?) ?? false,
      callKitVoip: (json['callKitVoip'] as bool?) ?? false,
      forceTurnTcpTls443:
          (json['forceTurnTcpTls443'] as bool?) ?? false,
      pttMinIntervalMillis:
          (json['pttMinIntervalMillis'] as int?) ?? 300,
      useFakeVoiceTransport:
          (json['useFakeVoiceTransport'] as bool?) ?? true,
      useFakeBackend:
          (json['useFakeBackend'] as bool?) ?? true,
    );
  }

  static const PolicyConfig defaultConfig = PolicyConfig(
    androidInstantPlay: true,
    enableAndroidPttForegroundService: true,
    iosModeA_PushTapPlay: true,
    iosModeB_PTTFramework: false,
    callKitVoip: false,
    forceTurnTcpTls443: false,
    pttMinIntervalMillis: 300,
    useFakeVoiceTransport: true,
    useFakeBackend: true,
  );

  PolicyConfig copyWith({
    bool? androidInstantPlay,
    bool? enableAndroidPttForegroundService,
    bool? iosModeA_PushTapPlay,
    bool? iosModeB_PTTFramework,
    bool? callKitVoip,
    bool? forceTurnTcpTls443,
    int? pttMinIntervalMillis,
    bool? useFakeVoiceTransport,
    bool? useFakeBackend,
  }) {
    return PolicyConfig(
      androidInstantPlay: androidInstantPlay ?? this.androidInstantPlay,
      enableAndroidPttForegroundService:
          enableAndroidPttForegroundService ??
              this.enableAndroidPttForegroundService,
      iosModeA_PushTapPlay:
          iosModeA_PushTapPlay ?? this.iosModeA_PushTapPlay,
      iosModeB_PTTFramework:
          iosModeB_PTTFramework ?? this.iosModeB_PTTFramework,
      callKitVoip: callKitVoip ?? this.callKitVoip,
      forceTurnTcpTls443:
          forceTurnTcpTls443 ?? this.forceTurnTcpTls443,
      pttMinIntervalMillis:
          pttMinIntervalMillis ?? this.pttMinIntervalMillis,
      useFakeVoiceTransport:
          useFakeVoiceTransport ?? this.useFakeVoiceTransport,
      useFakeBackend:
          useFakeBackend ?? this.useFakeBackend,
    );
  }
}

/// 서버에서 받은 원본 정책(raw)과
/// 플랫폼 가드(엔타이틀먼트, OS 버전 등)를 적용한 최종 정책(effective)을 분리
class FF {
  static PolicyConfig _raw = PolicyConfig.defaultConfig;
  static PolicyConfig _effective = PolicyConfig.defaultConfig;

  // 플랫폼/OS 정보 (런타임에서 세팅)
  static bool hasIosPttEntitlement = false; // iOS PushToTalk 엔타이틀먼트 여부
  static int iosMajorVersion = 18; // 런타임에서 감지

  static void applyPolicy(PolicyConfig newPolicy) {
    _raw = newPolicy;
    _recomputeEffective();
  }

  static void _recomputeEffective() {
    final p = _raw;

    if (iosMajorVersion >= 18 && hasIosPttEntitlement) {
      _effective = p.copyWith(
        iosModeA_PushTapPlay: false,
        iosModeB_PTTFramework: true,
      );
    } else {
      _effective = p.copyWith(
        iosModeA_PushTapPlay: true,
        iosModeB_PTTFramework: false,
      );
    }
  }

  static PolicyConfig get policy => _effective;

  // 편의 getter
  static bool get androidInstantPlay => policy.androidInstantPlay;
  static bool get enableAndroidPttForegroundService =>
      policy.enableAndroidPttForegroundService;
  static bool get iosModeA_PushTapPlay => policy.iosModeA_PushTapPlay;
  static bool get iosModeB_PTTFramework => policy.iosModeB_PTTFramework;
  static bool get callKitVoip => policy.callKitVoip;
  static bool get forceTurnTcpTls443 => policy.forceTurnTcpTls443;
  static int get pttMinIntervalMillis => policy.pttMinIntervalMillis;
  static bool get useFakeVoiceTransport => policy.useFakeVoiceTransport;
  static bool get useFakeBackend => policy.useFakeBackend;
}
