import 'package:voyage/app_env.dart';

/// LiveKit 서버 접속 설정.
///
/// 실제 URL / API 키 / 토큰 값은
/// 추후 서버/환경별 설정으로 대체된다.
class LiveKitConfig {
  const LiveKitConfig({
    required this.serverUrl,
    required this.apiKey,
    required this.token,
  });

  /// LiveKit 서버 URL (예: https://example.livekit.server)
  final Uri serverUrl;

  /// LiveKit API 키 (JWT 발급 등에 사용).
  final String apiKey;

  /// 접속 토큰 (현재는 placeholder, 추후 서버 발급 값 사용).
  final String token;

  /// 환경별 기본 LiveKit 설정을 반환한다.
  ///
  /// dev / alpha / prod 별로 다른 서버를 사용할 수 있으며,
  /// 현재 단계에서는 placeholder 값만 채워둔다.
  factory LiveKitConfig.forEnv(AppEnvironment env) {
    switch (env) {
      case AppEnvironment.dev:
        return LiveKitConfig(
          serverUrl: Uri.parse('https://dev.livekit.example'),
          apiKey: 'DEV_API_KEY_TODO',
          token: 'DEV_TOKEN_TODO',
        );
      case AppEnvironment.alpha:
        return LiveKitConfig(
          serverUrl: Uri.parse('https://alpha.livekit.example'),
          apiKey: 'ALPHA_API_KEY_TODO',
          token: 'ALPHA_TOKEN_TODO',
        );
      case AppEnvironment.prod:
        return LiveKitConfig(
          serverUrl: Uri.parse('https://prod.livekit.example'),
          apiKey: 'PROD_API_KEY_TODO',
          token: 'PROD_TOKEN_TODO',
        );
    }
  }
}

