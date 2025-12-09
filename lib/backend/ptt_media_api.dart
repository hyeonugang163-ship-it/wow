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
  RealPttMediaApi();

  @override
  Future<ApiResult<String>> uploadVoiceFile(String localPath) {
    return Future<ApiResult<String>>.value(
      ApiResult<String>.failure(
        const ApiError(
          type: ApiErrorType.unknown,
          message: 'RealPttMediaApi.uploadVoiceFile is not implemented',
        ),
      ),
    );
  }

  @override
  Future<ApiResult<String>> getSignedUrl(String remoteKey) {
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

