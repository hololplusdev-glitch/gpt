import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/persistence/daos/auth_dao.dart';
import 'package:pos_flutter/shared/models/enums.dart';

/// DEVICE_PRIV is terminal/machine access only.
/// It must not be expanded into sale/shift/hold/void/discount/print/report permissions.
class PermissionService {
  final AuthDao _authDao;

  PermissionService(this._authDao);

  Future<bool> canUseMachine({
    required String userId,
    required String terminalId,
  }) async {
    final raw = await _authDao.getUserPermissions(userId, terminalId);
    return raw.map((e) => e.trim().toUpperCase()).contains('USE_MACHINE');
  }

  Future<bool> hasPermission({
    required String userId,
    required String terminalId,
    required PermissionCode permission,
  }) async {
    return false;
  }

  Future<void> requirePermission({
    required String userId,
    required String terminalId,
    required PermissionCode permission,
  }) async {
    throw PermissionDeniedException(
      'Business permission is not available from DEVICE_PRIV: ${permission.code}',
      requiredPermission: permission,
    );
  }

  Future<bool> canSupervisorOverride({
    required String supervisorId,
    required String terminalId,
  }) async {
    return false;
  }

  Future<Set<PermissionCode>> getUserPermissions({
    required String userId,
    required String terminalId,
  }) async {
    return const <PermissionCode>{};
  }
}

class PermissionDeniedException extends AuthException {
  final PermissionCode requiredPermission;

  const PermissionDeniedException(
    super.message, {
    required this.requiredPermission,
  }) : super(code: 'permission_denied');
}
