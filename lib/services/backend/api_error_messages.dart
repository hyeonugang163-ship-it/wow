import 'package:voyage/services/backend/api_result.dart';

class ApiErrorMessages {
  const ApiErrorMessages._();

  static String forError(ApiError error) {
    switch (error.type) {
      case ApiErrorType.network:
        return '네트워크 오류로 서버에 연결할 수 없습니다.';
      case ApiErrorType.timeout:
        return '요청 시간이 초과되었습니다. 잠시 후 다시 시도해 주세요.';
      case ApiErrorType.server:
        return '서버 오류가 발생했습니다.';
      case ApiErrorType.unauthorized:
        return '세션이 만료되었거나 권한이 없습니다.';
      case ApiErrorType.forbidden:
        return '이 작업을 수행할 권한이 없습니다.';
      case ApiErrorType.notFound:
        return '요청한 리소스를 찾을 수 없습니다.';
      case ApiErrorType.cancelled:
        return '요청이 취소되었습니다.';
      case ApiErrorType.unknown:
        return '알 수 없는 오류가 발생했습니다.';
    }
  }
}
