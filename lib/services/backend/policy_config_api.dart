import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:voyage/app/app_env.dart';
import 'package:voyage/services/backend/api_result.dart';
import 'package:voyage/core/feature_flags.dart';
import 'package:voyage/features/ptt/application/ptt_debug_log.dart';

/// Lightweight HTTP client for fetching PolicyConfig JSON
/// from a backend, enabling server-driven feature flags.
///
/// The actual endpoint/base URL are backend-specific and can be
/// customized via constructor parameters or compile-time defines.
class PolicyConfigApi {
  PolicyConfigApi({
    http.Client? httpClient,
    Uri? baseUri,
  })  : _client = httpClient ?? http.Client(),
        _baseUri = baseUri ?? _defaultBaseUri();

  final http.Client _client;
  final Uri _baseUri;

  static Uri _defaultBaseUri() {
    const String raw = String.fromEnvironment(
      'POLICY_CONFIG_BASE_URL',
      defaultValue: 'https://example.com/',
    );
    return Uri.parse(raw);
  }

  Uri _buildPolicyUri(AppEnvironment env) {
    // TODO(ASK_SUPERVISOR): 실제 정책 엔드포인트 경로 및 쿼리
    // (플랫폼, 앱 버전 등) 규약을 확인해 조정한다.
    final String envName = env.name;
    return _baseUri.resolve('api/config/ptt_policy/$envName.json');
  }

  Future<ApiResult<PolicyConfig>> fetchPolicy(
    AppEnvironment env,
  ) async {
    final Uri uri = _buildPolicyUri(env);
    PttLogger.log(
      '[Backend][PolicyConfigApi]',
      'fetchPolicy request',
      meta: <String, Object?>{
        'uri': uri.toString(),
        'env': env.name,
      },
    );

    try {
      final http.Response response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        final String body = response.body;
        if (body.isEmpty) {
          return ApiResult<PolicyConfig>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message: 'Empty policy response body',
            ),
          );
        }

        try {
          final dynamic decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final PolicyConfig config =
                PolicyConfig.fromJson(decoded);
            return ApiResult<PolicyConfig>.success(config);
          }
          return ApiResult<PolicyConfig>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Unexpected policy response format (expected JSON object)',
            ),
          );
        } catch (e) {
          return ApiResult<PolicyConfig>.failure(
            ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Failed to parse policy response: ${e.toString()}',
            ),
          );
        }
      }

      final String trimmedBody =
          response.body.length > 500
              ? response.body.substring(0, 500)
              : response.body;
      return ApiResult<PolicyConfig>.failure(
        ApiError(
          type: ApiErrorType.unknown,
          statusCode: response.statusCode,
          message: trimmedBody.isEmpty
              ? 'Policy endpoint returned status ${response.statusCode}'
              : trimmedBody,
        ),
      );
    } on TimeoutException catch (e) {
      return ApiResult<PolicyConfig>.failure(
        ApiError(
          type: ApiErrorType.timeout,
          message:
              'PolicyConfigApi.fetchPolicy timeout: ${e.toString()}',
        ),
      );
    } catch (e) {
      return ApiResult<PolicyConfig>.failure(
        ApiError(
          type: ApiErrorType.network,
          message:
              'PolicyConfigApi.fetchPolicy error: ${e.toString()}',
        ),
      );
    }
  }
}
