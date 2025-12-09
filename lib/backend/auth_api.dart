import 'package:voyage/backend/api_result.dart';
import 'package:voyage/ptt_debug_log.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
}

abstract class AuthApi {
  Future<ApiResult<AuthSession>> loginWithToken(String deviceId);

  Future<ApiResult<AuthSession>> refresh(String refreshToken);
}

class FakeAuthApi implements AuthApi {
  const FakeAuthApi();

  @override
  Future<ApiResult<AuthSession>> loginWithToken(String deviceId) async {
    final now = DateTime.now();
    final session = AuthSession(
      userId: 'u_$deviceId',
      accessToken: 'fake_access_$deviceId',
      refreshToken: 'fake_refresh_$deviceId',
      expiresAt: now.add(const Duration(hours: 1)),
    );

    PttLogger.log(
      '[Backend][AuthApi][Fake]',
      'loginWithToken',
      meta: <String, Object?>{
        'deviceIdHash': deviceId.hashCode,
        'expiresAt': session.expiresAt.toIso8601String(),
      },
    );

    return ApiResult<AuthSession>.success(session);
  }

  @override
  Future<ApiResult<AuthSession>> refresh(String refreshToken) async {
    final now = DateTime.now();
    final session = AuthSession(
      userId: 'u_refresh',
      accessToken: 'fake_access_refreshed',
      refreshToken: 'fake_refresh_refreshed',
      expiresAt: now.add(const Duration(hours: 1)),
    );

    PttLogger.log(
      '[Backend][AuthApi][Fake]',
      'refresh',
      meta: <String, Object?>{
        'refreshTokenHash': refreshToken.hashCode,
        'expiresAt': session.expiresAt.toIso8601String(),
      },
    );

    return ApiResult<AuthSession>.success(session);
  }
}

/// Placeholder for real HTTP implementation.
///
/// When wiring a real backend, inject an HTTP client here and translate
/// HTTP/network errors into ApiResult/ApiError.
class RealAuthApi implements AuthApi {
  RealAuthApi();

  @override
  Future<ApiResult<AuthSession>> loginWithToken(String deviceId) {
    // TODO: Implement HTTP call for login.
    return Future<ApiResult<AuthSession>>.value(
      ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealAuthApi.loginWithToken is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<AuthSession>> refresh(String refreshToken) {
    // TODO: Implement HTTP call for refresh.
    return Future<ApiResult<AuthSession>>.value(
      ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealAuthApi.refresh is not implemented',
        ),
      ),
    );
  }
}

