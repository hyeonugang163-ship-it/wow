// Common API result/error model for backend boundaries.
// Does not depend on any specific HTTP client implementation.

enum ApiErrorType {
  network,
  unauthorized,
  forbidden,
  notFound,
  server,
  timeout,
  cancelled,
  unknown,
}

class ApiError {
  const ApiError({
    required this.type,
    this.statusCode,
    this.code,
    this.message,
  });

  final ApiErrorType type;

  /// Optional HTTP status code or equivalent transport status.
  final int? statusCode;

  /// Backend-specific error code (e.g. "FRIEND_NOT_FOUND").
  final String? code;

  /// Debug-only message, not user-facing.
  final String? message;
}

class ApiResult<T> {
  const ApiResult._({
    this.data,
    this.error,
  });

  final T? data;
  final ApiError? error;

  bool get isSuccess => data != null && error == null;

  bool get isError => error != null;

  factory ApiResult.success(T data) {
    return ApiResult._(data: data);
  }

  factory ApiResult.failure(ApiError error) {
    return ApiResult._(error: error);
  }
}

