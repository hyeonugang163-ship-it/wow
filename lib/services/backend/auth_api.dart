import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:voyage/services/backend/api_result.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

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
  RealAuthApi({
    http.Client? httpClient,
    Uri? baseUri,
  })  : _client = httpClient ?? http.Client(),
        // TODO(ASK_SUPERVISOR): 실제 auth API base URL
        // (예: "https://api.example.com") 확정 후 교체한다.
        _baseUri = baseUri ?? Uri.parse('https://example.com/');

  final http.Client _client;
  final Uri _baseUri;

  Uri _buildLoginUri() {
    // TODO(ASK_SUPERVISOR): 실제 로그인 엔드포인트 경로
    // (예: "/v1/auth/login")를 확인해 교체한다.
    return _baseUri.resolve('api/auth/login');
  }

  Uri _buildRefreshUri() {
    // TODO(ASK_SUPERVISOR): 실제 토큰 갱신 엔드포인트 경로
    // (예: "/v1/auth/refresh")를 확인해 교체한다.
    return _baseUri.resolve('api/auth/refresh');
  }

  ApiError _mapHttpError({
    required int statusCode,
    String? body,
  }) {
    final ApiErrorType type;
    if (statusCode == 401) {
      type = ApiErrorType.unauthorized;
    } else if (statusCode == 403) {
      type = ApiErrorType.forbidden;
    } else if (statusCode == 404) {
      type = ApiErrorType.notFound;
    } else if (statusCode >= 500) {
      type = ApiErrorType.server;
    } else {
      type = ApiErrorType.unknown;
    }

    String? message;
    String? code;

    if (body != null && body.isNotEmpty) {
      final String trimmedBody =
          body.length > 500 ? body.substring(0, 500) : body;
      try {
        final dynamic decoded = jsonDecode(trimmedBody);
        if (decoded is Map<String, dynamic>) {
          code = decoded['code'] as String?;
          message = (decoded['message'] as String?) ?? trimmedBody;
        } else {
          message = trimmedBody;
        }
      } catch (_) {
        message = trimmedBody;
      }
    }

    return ApiError(
      type: type,
      statusCode: statusCode,
      code: code,
      message: message,
    );
  }

  AuthSession _parseSession(Map<String, dynamic> json) {
    // TODO(ASK_SUPERVISOR): 실제 백엔드 응답 필드 이름과
    // userId/accessToken/refreshToken/expiresAt 매핑을 정밀히 맞춘다.
    final String? userId = json['userId'] as String?;
    final String? accessToken = json['accessToken'] as String?;
    final String? refreshToken = json['refreshToken'] as String?;
    final String? expiresAtRaw = json['expiresAt'] as String?;

    if (userId == null ||
        accessToken == null ||
        refreshToken == null ||
        expiresAtRaw == null) {
      throw const FormatException(
        'Missing required auth fields in response',
      );
    }

    DateTime expiresAt;
    try {
      // TODO(LATER_MVP2): 백엔드가 epoch millis 등 숫자 타임스탬프를
      // 사용할 경우 파싱 로직을 조정한다.
      expiresAt = DateTime.parse(expiresAtRaw);
    } catch (_) {
      // If parsing fails, fall back to a short-lived session.
      expiresAt = DateTime.now().add(const Duration(hours: 1));
    }

    return AuthSession(
      userId: userId,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<ApiResult<AuthSession>> loginWithToken(String deviceId) async {
    final Uri uri = _buildLoginUri();
    PttLogger.log(
      '[Backend][AuthApi][Real]',
      'loginWithToken request',
      meta: <String, Object?>{
        'uri': uri.toString(),
        'deviceIdHash': deviceId.hashCode,
      },
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              // TODO(ASK_SUPERVISOR): 필요 시 Authorization 헤더 포맷을 정의하고 추가한다.
            },
            body: jsonEncode(<String, Object?>{
              // TODO(ASK_SUPERVISOR): 백엔드에서 요구하는 디바이스 식별자
              // 필드 이름으로 "deviceId" 키를 조정한다.
              'deviceId': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'loginWithToken response',
        meta: <String, Object?>{
          'statusCode': response.statusCode,
          'contentLength': response.contentLength ?? -1,
        },
      );

      final int statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final String body = response.body;
        if (body.isEmpty) {
          return ApiResult<AuthSession>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message: 'Empty auth response body',
            ),
          );
        }

        try {
          final dynamic decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final session = _parseSession(decoded);
            return ApiResult<AuthSession>.success(session);
          }

          return ApiResult<AuthSession>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Unexpected auth response format (expected JSON object)',
            ),
          );
        } catch (e) {
          return ApiResult<AuthSession>.failure(
            ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Failed to parse auth response: ${e.toString()}',
            ),
          );
        }
      }

      final ApiError error = _mapHttpError(
        statusCode: statusCode,
        body: response.body,
      );
      return ApiResult<AuthSession>.failure(error);
    } on SocketException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'loginWithToken network error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'Network error during loginWithToken',
        ),
      );
    } on TimeoutException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'loginWithToken timeout',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.timeout,
          message: 'loginWithToken request timed out',
        ),
      );
    } on HttpException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'loginWithToken http exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'HTTP exception during loginWithToken',
        ),
      );
    } catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'loginWithToken unknown exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        ApiError(
          type: ApiErrorType.unknown,
          message:
              'Unknown error during loginWithToken: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<AuthSession>> refresh(String refreshToken) async {
    final Uri uri = _buildRefreshUri();
    PttLogger.log(
      '[Backend][AuthApi][Real]',
      'refresh request',
      meta: <String, Object?>{
        'uri': uri.toString(),
        'refreshTokenHash': refreshToken.hashCode,
      },
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: <String, String>{
              'Content-Type': 'application/json',
              // TODO(ASK_SUPERVISOR): 필요 시 Authorization 헤더 포맷을 정의하고 추가한다.
            },
            body: jsonEncode(<String, Object?>{
              // TODO(ASK_SUPERVISOR): 백엔드 계약에 맞게 "refreshToken" 키를 조정한다.
              'refreshToken': refreshToken,
            }),
          )
          .timeout(const Duration(seconds: 15));

      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'refresh response',
        meta: <String, Object?>{
          'statusCode': response.statusCode,
          'contentLength': response.contentLength ?? -1,
        },
      );

      final int statusCode = response.statusCode;
      if (statusCode >= 200 && statusCode < 300) {
        final String body = response.body;
        if (body.isEmpty) {
          return ApiResult<AuthSession>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message: 'Empty refresh response body',
            ),
          );
        }

        try {
          final dynamic decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final session = _parseSession(decoded);
            return ApiResult<AuthSession>.success(session);
          }

          return ApiResult<AuthSession>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Unexpected refresh response format (expected JSON object)',
            ),
          );
        } catch (e) {
          return ApiResult<AuthSession>.failure(
            ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Failed to parse refresh response: ${e.toString()}',
            ),
          );
        }
      }

      final ApiError error = _mapHttpError(
        statusCode: statusCode,
        body: response.body,
      );
      return ApiResult<AuthSession>.failure(error);
    } on SocketException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'refresh network error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'Network error during refresh',
        ),
      );
    } on TimeoutException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'refresh timeout',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.timeout,
          message: 'refresh request timed out',
        ),
      );
    } on HttpException catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'refresh http exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'HTTP exception during refresh',
        ),
      );
    } catch (e) {
      PttLogger.log(
        '[Backend][AuthApi][Real]',
        'refresh unknown exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<AuthSession>.failure(
        ApiError(
          type: ApiErrorType.unknown,
          message:
              'Unknown error during refresh: ${e.toString()}',
        ),
      );
    }
  }
}
