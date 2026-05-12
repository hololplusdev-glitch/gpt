// core/network/api_client.dart
// WHY: Central HTTP client for Backend API communication.
// SSOT: all Dio/network errors are normalized here only.

import 'package:dio/dio.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/network/network_models.dart';

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
        sendTimeout: Duration(seconds: profile.timeoutSeconds),
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
      return await client.get<T>(
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
      return await client.post<T>(
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
      throw const NetworkException(
        'Backend API client is not configured. Setup must be completed first.',
        code: 'NOT_CONFIGURED',
      );
    }
    return client;
  }

  AppException _mapError(DioException e) {
    if (e.type == DioExceptionType.cancel) {
      return NetworkException(
        'تم إلغاء طلب الاتصال بالخادم.',
        code: 'CANCELLED',
        originalError: _diagnostic(e),
      );
    }

    final response = e.response;
    if (response != null) {
      final statusCode = response.statusCode;
      final serverMessage = _serverMessage(response.data);
      final message = serverMessage.isNotEmpty
          ? serverMessage
          : 'رفض الخادم الطلب أو أعاد استجابة غير ناجحة.';

      return NetworkException(
        message,
        code: 'HTTP_${statusCode ?? 'UNKNOWN'}',
        statusCode: statusCode,
        originalError: _diagnostic(e),
      );
    }

    if (_isNetworkTransportFailure(e)) {
      return NetworkException(
        _networkUserMessage(e),
        code: 'NETWORK_ERROR',
        originalError: _diagnostic(e),
      );
    }

    return NetworkException(
      _unknownUserMessage(e),
      code: 'UNKNOWN_NETWORK_ERROR',
      originalError: _diagnostic(e),
    );
  }

  bool _isNetworkTransportFailure(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.badCertificate) {
      return true;
    }

    final diagnostic = _diagnostic(e).toLowerCase();

    return diagnostic.contains('socket') ||
        diagnostic.contains('connection reset') ||
        diagnostic.contains('connection closed') ||
        diagnostic.contains('connection refused') ||
        diagnostic.contains('failed host lookup') ||
        diagnostic.contains('network is unreachable') ||
        diagnostic.contains('broken pipe') ||
        diagnostic.contains('timed out') ||
        diagnostic.contains('xmlhttprequest');
  }

  String _networkUserMessage(DioException e) {
    final hint = _firstUsefulText([e.message, e.error]);

    if (hint.isEmpty) {
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة أو عنوان API ثم أعد المحاولة.';
    }

    return 'تعذر الاتصال بالخادم. السبب التقني: $hint';
  }

  String _unknownUserMessage(DioException e) {
    final hint = _firstUsefulText([e.message, e.error, _dioTypeName(e.type)]);

    if (hint.isEmpty) {
      return 'تعذر تنفيذ طلب الخادم بسبب خطأ غير معروف.';
    }

    return 'تعذر تنفيذ طلب الخادم. السبب التقني: $hint';
  }

  String _serverMessage(dynamic data) {
    if (data is Map) {
      final message = _firstUsefulText([
        data['message'],
        data['error'],
        data['details'],
        data['code'],
      ]);
      return message;
    }

    return _cleanText(data);
  }

  String _diagnostic(DioException e) {
    final request = e.requestOptions;
    final parts = <String>[
      'type=${_dioTypeName(e.type)}',
      'method=${request.method}',
      'uri=${request.uri}',
      if (_cleanText(e.message).isNotEmpty) 'message=${_cleanText(e.message)}',
      if (_cleanText(e.error).isNotEmpty) 'error=${_cleanText(e.error)}',
      if (e.response?.statusCode != null) 'status=${e.response!.statusCode}',
      if (_cleanText(e.response?.data).isNotEmpty)
        'response=${_cleanText(e.response?.data)}',
    ];

    return parts.join(' | ');
  }

  String _firstUsefulText(Iterable<Object?> values) {
    for (final value in values) {
      final text = _cleanText(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _cleanText(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '';
    return text;
  }

  String _dioTypeName(DioExceptionType type) {
    final raw = type.toString();
    final dot = raw.lastIndexOf('.');
    return dot >= 0 ? raw.substring(dot + 1) : raw;
  }
}
