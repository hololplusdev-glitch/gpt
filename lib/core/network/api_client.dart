// core/network/api_client.dart
// WHY: Central HTTP client for Backend API communication.
// Wraps Dio with interceptors for auth, logging, error mapping.

import 'package:dio/dio.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/network/network_models.dart';

class ApiPaths {
  static const data = '/data';
}

/// Local API client for Backend API communication.
///
/// Configured at runtime via [SyncProfile].
/// Converts Dio errors to typed [AppException] subclasses.
class LocalApiClient {
  Dio? _dio;
  SyncProfile? _profile;

  /// Whether the client is configured and ready.
  bool get isConfigured => _dio != null && _profile != null;

  /// Exposes the configured base URL for debug logging only.
  /// Returns empty string if not yet configured.
  String get debugBaseUrl => _profile?.baseUrl ?? '';

  /// Configure the client with a sync profile.
  void configure(SyncProfile profile) {
    _profile = profile;
    _dio = Dio(
      BaseOptions(
        baseUrl: profile.baseUrl,
        connectTimeout: Duration(seconds: profile.timeoutSeconds),
        receiveTimeout: Duration(seconds: profile.timeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Clear the active runtime configuration.
  void clearConfiguration() {
    _profile = null;
    _dio = null;
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    void Function(int, int)? onReceiveProgress,
  }) async {
    final client = _requireClient();
    try {
      return await client.get(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    final client = _requireClient();
    try {
      return await client.post(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Dio _requireClient() {
    final client = _dio;
    if (client == null) {
      throw NetworkException(
        'Backend API client is not configured. Setup must be completed first.',
        code: 'NOT_CONFIGURED',
      );
    }
    return client;
  }

  AppException _mapError(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return NetworkException('Request was cancelled.', code: 'CANCELLED');
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException(
        'Unable to reach the server. Please check your network connection.',
        code: 'NETWORK_ERROR',
        originalError: e.message,
      );
    }

    final response = e.response;
    if (response != null) {
      if (response.statusCode == 401 || response.statusCode == 403) {
        return NetworkException(
          'Authentication failed. Please verify your credentials.',
          code: 'UNAUTHORIZED',
        );
      }

      String message = 'Server returned an error.';
      if (response.data is Map<String, dynamic>) {
        message = response.data['message']?.toString() ?? message;
      }
      return NetworkException(
        message,
        code: 'HTTP_${response.statusCode}',
        originalError: response.data?.toString(),
      );
    }

    return NetworkException(
      'An unexpected error occurred: ${e.message}',
      code: 'UNKNOWN_NETWORK_ERROR',
    );
  }
}
