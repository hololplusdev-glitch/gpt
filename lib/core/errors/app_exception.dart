// core/errors/app_exception.dart
// WHY: Typed exceptions enable structured error handling and prevent silent failures.

/// Base exception for all app-specific errors.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(this.message, {this.code, this.originalError});

  @override
  String toString() => 'AppException($code): $message';
}

/// Network / API errors.
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
    this.statusCode,
  });
}

/// Local database errors.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code, super.originalError});
}

/// Authentication / authorization errors.
class AuthException extends AppException {
  const AuthException(super.message, {super.code, super.originalError});
}

/// Business rule violation.
class BusinessException extends AppException {
  const BusinessException(super.message, {super.code});
}

/// Device / peripheral errors (printer, terminal, scanner).
class DeviceException extends AppException {
  const DeviceException(super.message, {super.code, super.originalError});
}

/// Sync errors.
class SyncException extends AppException {
  const SyncException(super.message, {super.code, super.originalError});
}

/// Validation errors.
class ValidationException extends AppException {
  final Map<String, String>? fieldErrors;

  const ValidationException(super.message, {super.code, this.fieldErrors});
}

abstract final class ErrorMapper {
  static String userMessage(Object error) {
    if (error is AppException) return error.message;
    if (error is FormatException) return 'Enter a valid value.';
    return 'Something went wrong. Please try again.';
  }
}
