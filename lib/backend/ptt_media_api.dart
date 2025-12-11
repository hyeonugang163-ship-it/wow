import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:voyage/backend/api_result.dart';
import 'package:voyage/ptt_debug_log.dart';

abstract class PttMediaApi {
  Future<ApiResult<String>> uploadVoiceFile(String localPath);

  Future<ApiResult<String>> getSignedUrl(String remoteKey);
}

class FakePttMediaApi implements PttMediaApi {
  FakePttMediaApi();

  @override
  Future<ApiResult<String>> uploadVoiceFile(String localPath) async {
    final remoteKey = 'local:$localPath';

    PttLogger.log(
      '[Backend][PttMediaApi][Fake]',
      'uploadVoiceFile',
      meta: <String, Object?>{
        'localPathHash': localPath.hashCode,
        'remoteKeyHash': remoteKey.hashCode,
      },
    );

    return ApiResult<String>.success(remoteKey);
  }

  @override
  Future<ApiResult<String>> getSignedUrl(String remoteKey) async {
    // For Fake implementation, just echo back a pseudo-URL.
    final url = 'https://fake-ptt.local/$remoteKey';

    PttLogger.log(
      '[Backend][PttMediaApi][Fake]',
      'getSignedUrl',
      meta: <String, Object?>{
        'remoteKeyHash': remoteKey.hashCode,
      },
    );

    return ApiResult<String>.success(url);
  }
}

class RealPttMediaApi implements PttMediaApi {
  RealPttMediaApi({
    http.Client? httpClient,
    Uri? baseUri,
  })  : _client = httpClient ?? http.Client(),
        // TODO: Replace with actual media API base URL
        // (e.g. "https://api.example.com").
        _baseUri = baseUri ?? Uri.parse('https://example.com/');

  final http.Client _client;
  final Uri _baseUri;

  Uri _buildUploadUri() {
    // TODO: Replace with the actual upload path (e.g. "/v1/media/voice").
    return _baseUri.resolve('api/voice/upload');
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

  @override
  Future<ApiResult<String>> uploadVoiceFile(String localPath) async {
    final file = File(localPath);
    final bool exists = await file.exists();
    if (!exists) {
      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile local file not found',
        meta: <String, Object?>{
          'localPathHash': localPath.hashCode,
        },
      );
      return ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.notFound,
          message: 'Local file not found for upload',
        ),
      );
    }

    final Uri uri = _buildUploadUri();
    PttLogger.log(
      '[Backend][PttMediaApi][Real]',
      'uploadVoiceFile start',
      meta: <String, Object?>{
        'localPathHash': localPath.hashCode,
        'uri': uri.toString(),
      },
    );

    try {
      final request = http.MultipartRequest('POST', uri);

      // TODO: Replace "file" with the actual multipart field name
      // expected by the backend (e.g. "voice" or "audio").
      request.files.add(
        await http.MultipartFile.fromPath(
          'file', // TODO: field name
          file.path,
        ),
      );

      // TODO: Add additional metadata fields (chatId, friendId,
      // durationMillis, etc.) when the backend contract is defined.
      // request.fields['chatId'] = '<TODO: chat id>';
      // request.fields['durationMillis'] = '<TODO: duration ms>';

      final streamedResponse = await _client.send(request);
      final response =
          await http.Response.fromStream(streamedResponse);

      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile response',
        meta: <String, Object?>{
          'statusCode': response.statusCode,
          'contentLength': response.contentLength ?? -1,
        },
      );

      final int statusCode = response.statusCode;

      if (statusCode >= 200 && statusCode < 300) {
        try {
          final String body = response.body;
          if (body.isEmpty) {
            return ApiResult<String>.failure(
              const ApiError(
                type: ApiErrorType.unknown,
                message:
                    'Empty response body from upload endpoint',
              ),
            );
          }

          final dynamic decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic>) {
            final Map<String, dynamic> json = decoded;

            // TODO: Replace "remoteKey" / "fileUrl" with the actual field
            // name returned by the backend (e.g. "mediaId").
            final String? remoteKey =
                json['remoteKey'] as String? ??
                json['fileUrl'] as String?;

            if (remoteKey != null && remoteKey.isNotEmpty) {
              return ApiResult<String>.success(remoteKey);
            }

            return ApiResult<String>.failure(
              const ApiError(
                type: ApiErrorType.unknown,
                message:
                    'Missing remoteKey/fileUrl in upload response',
              ),
            );
          }

          return ApiResult<String>.failure(
            const ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Unexpected upload response format (expected JSON object)',
            ),
          );
        } catch (e) {
          return ApiResult<String>.failure(
            ApiError(
              type: ApiErrorType.unknown,
              message:
                  'Failed to parse upload response: ${e.toString()}',
            ),
          );
        }
      }

      final ApiError error = _mapHttpError(
        statusCode: statusCode,
        body: response.body,
      );
      return ApiResult<String>.failure(error);
    } on SocketException catch (e) {
      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile network error',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'Network error while uploading voice file',
        ),
      );
    } on TimeoutException catch (e) {
      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile timeout',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.timeout,
          message: 'Upload voice file request timed out',
        ),
      );
    } on HttpException catch (e) {
      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile http exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.network,
          message: 'HTTP exception during upload',
        ),
      );
    } catch (e) {
      PttLogger.log(
        '[Backend][PttMediaApi][Real]',
        'uploadVoiceFile unknown exception',
        meta: <String, Object?>{
          'error': e.toString(),
        },
      );
      return ApiResult<String>.failure(
        ApiError(
          type: ApiErrorType.unknown,
          message:
              'Unknown error during uploadVoiceFile: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<ApiResult<String>> getSignedUrl(String remoteKey) {
    // NOTE: Signed URL retrieval is backend-specific and not yet defined.
    // For now, keep this as a placeholder that callers can handle as an
    // error, similar to other Real*Api stubs.
    return Future<ApiResult<String>>.value(
      ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealPttMediaApi.getSignedUrl is not implemented',
        ),
      ),
    );
  }
}
