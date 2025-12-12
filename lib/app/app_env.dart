// NOTE: 앱 실행 환경(dev/alpha/prod)을 나타내는 간단한 enum 및 헬퍼.
//
// - 실제 값은 `--dart-define=APP_ENV=dev|alpha|prod` 로 주입한다.
// - 기본값은 dev 이며, alpha/prod 빌드에서는 명시적으로 정의하는 것을 권장한다.
// - iOS/macOS 환경에서도 동일하게 동작해야 하며, 추후 실제 배포 빌드에서
//   Mac+iOS 환경으로 다시 검증이 필요하다.

enum AppEnvironment {
  dev,
  alpha,
  prod,
}

class AppEnv {
  static const String _envString =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static final AppEnvironment current = _parse(_envString);

  static AppEnvironment _parse(String value) {
    switch (value.toLowerCase()) {
      case 'alpha':
        return AppEnvironment.alpha;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      case 'dev':
      default:
        return AppEnvironment.dev;
    }
  }

  static String get currentName => _envString;
}

