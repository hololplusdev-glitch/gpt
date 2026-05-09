// core/services/permission_service.dart
// WHY: Centralized permission checking prevents scattered auth logic.
// All UI and business operations check permissions through this service.

import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/shared/models/enums.dart';

/// Checks user permissions for the current terminal context.
class PermissionService {
  final AuthDao _authDao;

  PermissionService(this._authDao);

  /// Check if user has a permission on the terminal.
  Future<bool> hasPermission({
    required String userId,
    required String terminalId,
    required PermissionCode permission,
  }) async {
    final permissions = await getUserPermissions(
      userId: userId,
      terminalId: terminalId,
    );
    return permissions.contains(permission);
  }

  /// Require a permission — throws if denied.
  Future<void> requirePermission({
    required String userId,
    required String terminalId,
    required PermissionCode permission,
  }) async {
    final allowed = await hasPermission(
      userId: userId,
      terminalId: terminalId,
      permission: permission,
    );
    if (!allowed) {
      throw PermissionDeniedException(
        'Permission denied: ${permission.code}',
        requiredPermission: permission,
      );
    }
  }

  /// Check if a user can perform supervisor override.
  Future<bool> canSupervisorOverride({
    required String supervisorId,
    required String terminalId,
  }) async {
    return hasPermission(
      userId: supervisorId,
      terminalId: terminalId,
      permission: PermissionCode.supervisorOverride,
    );
  }

  /// Get all permission codes for a user on a terminal.
  Future<Set<PermissionCode>> getUserPermissions({
    required String userId,
    required String terminalId,
  }) async {
    final codes = await _authDao.getUserPermissions(userId, terminalId);
    return _mapRawPermissions(codes);
  }

  Set<PermissionCode> _mapRawPermissions(List<String> rawCodes) {
    final raw = rawCodes.map((code) => code.trim().toUpperCase()).toSet();
    final permissions = <PermissionCode>{};
    if (raw.contains('USE_MACHINE')) {
      permissions.addAll({
        PermissionCode.saleCreate,
        PermissionCode.shiftOpen,
        PermissionCode.shiftClose,
        PermissionCode.shiftExtend,
        PermissionCode.holdOrder,
        PermissionCode.recallOrder,
        PermissionCode.cancelHeldOrder,
        PermissionCode.viewShiftReport,
      });
    }
    return permissions;
  }
}

/// Exception thrown when a permission check fails.
class PermissionDeniedException extends AuthException {
  final PermissionCode requiredPermission;

  const PermissionDeniedException(
    super.message, {
    required this.requiredPermission,
  }) : super(code: 'permission_denied');
}
