// core/network/network_models.dart
// WHY: SyncProfile is the connection/bootstrap SSOT only. Runtime POS context
// lives in ActivePosSession, never in the server connection profile.

import 'package:pos_flutter/shared/models/enums.dart';

class SyncProfile {
  final String host;
  final int? port;
  final String basePath;
  final String custCode;
  final String bootstrapUserId;
  final int pageLimit;
  final int timeoutSeconds;
  final bool useSsl;
  final bool isValidated;
  final DateTime? lastValidatedAt;
  final bool setupCompleted;
  final bool initialSyncCompleted;
  final DateTime? lastFullSyncAt;

  SyncProfile({
    required this.host,
    this.port,
    String basePath = '/ords/erp/pos-api/v1',
    required this.custCode,
    this.bootstrapUserId = '1',
    this.pageLimit = 100,
    this.timeoutSeconds = 30,
    this.useSsl = true,
    this.isValidated = false,
    this.lastValidatedAt,
    this.setupCompleted = false,
    this.initialSyncCompleted = false,
    this.lastFullSyncAt,
  }) : basePath = _stripTrailingData(basePath);

  /// Parse a full API base URL into a SyncProfile.
  ///
  /// Accepts URLs like:
  ///   https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1
  ///
  /// Automatically strips trailing `/data` to prevent `/data/data` duplication.
  factory SyncProfile.fromUrl(
    String url, {
    required String custCode,
    String bootstrapUserId = '1',
    int pageLimit = 100,
    int timeoutSeconds = 120,
  }) {
    final sanitized = _sanitizeBaseUrl(url);
    final parsed = Uri.tryParse(sanitized);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      throw FormatException('Invalid API base URL: $url');
    }

    final useSsl = parsed.scheme == 'https';
    final hasNonDefaultPort =
        parsed.hasPort && parsed.port != (useSsl ? 443 : 80);

    return SyncProfile(
      host: parsed.host,
      port: hasNonDefaultPort ? parsed.port : null,
      basePath: parsed.path.isNotEmpty ? parsed.path : '/ords/erp/pos-api/v1',
      custCode: custCode,
      bootstrapUserId: bootstrapUserId,
      pageLimit: pageLimit,
      useSsl: useSsl,
      timeoutSeconds: timeoutSeconds,
    );
  }

  /// Build the base URL for API calls. Port is omitted when it matches
  /// the scheme default (443 for HTTPS, 80 for HTTP).
  String get baseUrl {
    final scheme = useSsl ? 'https' : 'http';
    final portSuffix = _portSuffix;
    return '$scheme://$host$portSuffix$basePath';
  }

  String get _portSuffix {
    if (port == null) return '';
    // Omit port when it matches the scheme default.
    if (useSsl && port == 443) return '';
    if (!useSsl && port == 80) return '';
    return ':$port';
  }

  SyncProfile copyWith({
    String? host,
    int? port,
    bool clearPort = false,
    String? basePath,
    String? custCode,
    String? bootstrapUserId,
    int? pageLimit,
    int? timeoutSeconds,
    bool? useSsl,
    bool? isValidated,
    DateTime? lastValidatedAt,
    bool? setupCompleted,
    bool? initialSyncCompleted,
    DateTime? lastFullSyncAt,
  }) {
    return SyncProfile(
      host: host ?? this.host,
      port: clearPort ? null : (port ?? this.port),
      basePath: basePath ?? this.basePath,
      custCode: custCode ?? this.custCode,
      bootstrapUserId: bootstrapUserId ?? this.bootstrapUserId,
      pageLimit: pageLimit ?? this.pageLimit,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      useSsl: useSsl ?? this.useSsl,
      isValidated: isValidated ?? this.isValidated,
      lastValidatedAt: lastValidatedAt ?? this.lastValidatedAt,
      setupCompleted: setupCompleted ?? this.setupCompleted,
      initialSyncCompleted:
          initialSyncCompleted ?? this.initialSyncCompleted,
      lastFullSyncAt: lastFullSyncAt ?? this.lastFullSyncAt,
    );
  }

  /// Strips trailing `/data` from basePath to prevent /data/data.
  /// Used by the default constructor.
  static String _stripTrailingData(String path) {
    var trimmed = path.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.endsWith('/data')) {
      trimmed = trimmed.substring(0, trimmed.length - 5);
    }
    return trimmed;
  }

  /// Strips trailing `/data` from a base URL to prevent `/data/data` in requests.
  static String _sanitizeBaseUrl(String url) {
    var trimmed = url.trim();
    // Remove trailing slash.
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    // Strip `/data` suffix — the API client appends `/data` per request.
    if (trimmed.endsWith('/data')) {
      trimmed = trimmed.substring(0, trimmed.length - 5);
    }
    return trimmed;
  }

  /// Validates and sanitizes a user-entered base URL.
  /// Returns the sanitized URL or throws [FormatException].
  static String sanitizeAndValidateUrl(String url) {
    final sanitized = _sanitizeBaseUrl(url);
    final parsed = Uri.tryParse(sanitized);
    if (parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        (parsed.scheme != 'http' && parsed.scheme != 'https')) {
      throw FormatException(
        'Enter a valid HTTP/HTTPS URL, e.g.:\n'
        'https://2481.extrasolutionscloud.com/ords/erp/pos-api/v1',
        url,
      );
    }
    return sanitized;
  }
}

class HealthCheckResult {
  final String service;
  final HealthStatus status;
  final int latencyMs;
  final DateTime checkedAt;
  final String? error;
  final String? serverVersion;

  const HealthCheckResult({
    required this.service,
    required this.status,
    required this.latencyMs,
    required this.checkedAt,
    this.error,
    this.serverVersion,
  });

  bool get isHealthy => status == HealthStatus.ok;
}
