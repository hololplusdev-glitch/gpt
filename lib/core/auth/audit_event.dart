// core/auth/audit_event.dart
// WHY: Every protected action must leave an immutable audit trail.
// This is a regulatory and operational requirement for POS systems.

import 'package:pos_flutter/shared/models/enums.dart';

/// Immutable audit record for sensitive/protected actions.
class AuditEvent {
  final String id;

  /// What action was performed.
  final AuditAction action;

  /// Who performed the action (cashier ID).
  final String actorId;

  /// Who approved the action (supervisor ID), if supervisor override was used.
  final String? supervisorId;

  /// Type of entity the action targeted.
  final String? targetEntityType;

  /// ID of the entity the action targeted (e.g., transaction ID).
  final String? targetEntityId;

  /// Structured details about the action (serialized JSON).
  /// e.g., {"oldPrice": 1000, "newPrice": 800, "reason": "damaged packaging"}
  final String? details;

  /// When the action was performed.
  final DateTime timestamp;

  /// Station where the action was performed.
  final String stationId;

  const AuditEvent({
    required this.id,
    required this.action,
    required this.actorId,
    this.supervisorId,
    this.targetEntityType,
    this.targetEntityId,
    this.details,
    required this.timestamp,
    required this.stationId,
  });

  /// Whether a supervisor approved this action.
  bool get hasSupervisorApproval => supervisorId != null;
}

/// Result of a supervisor approval check.
class ApprovalResult {
  final bool approved;
  final String? supervisorId;
  final DateTime timestamp;
  final String? reason;

  const ApprovalResult({
    required this.approved,
    this.supervisorId,
    required this.timestamp,
    this.reason,
  });

  static ApprovalResult denied({String? reason}) => ApprovalResult(
    approved: false,
    timestamp: DateTime.now(),
    reason: reason,
  );
}

/// Defines whether a protected action requires supervisor approval
/// and at what cashier permission level.
class ApprovalRequirement {
  final ProtectedAction action;
  final bool requiresSupervisor;

  /// Maximum cashier permission level that can perform without supervisor.
  /// e.g., level 1 = basic cashier, level 2 = senior cashier, level 3 = supervisor
  final int maxCashierLevel;

  const ApprovalRequirement({
    required this.action,
    required this.requiresSupervisor,
    this.maxCashierLevel = 1,
  });

  /// Default approval requirements for all protected actions.
  static const Map<ProtectedAction, ApprovalRequirement> defaults = {
    ProtectedAction.voidSale: ApprovalRequirement(
      action: ProtectedAction.voidSale,
      requiresSupervisor: true,
    ),
    ProtectedAction.returnSale: ApprovalRequirement(
      action: ProtectedAction.returnSale,
      requiresSupervisor: true,
    ),
    ProtectedAction.priceOverride: ApprovalRequirement(
      action: ProtectedAction.priceOverride,
      requiresSupervisor: true,
    ),
    ProtectedAction.discountOverride: ApprovalRequirement(
      action: ProtectedAction.discountOverride,
      requiresSupervisor: true,
      maxCashierLevel: 2,
    ),
    ProtectedAction.settingsChange: ApprovalRequirement(
      action: ProtectedAction.settingsChange,
      requiresSupervisor: true,
    ),
    ProtectedAction.reprintReceipt: ApprovalRequirement(
      action: ProtectedAction.reprintReceipt,
      requiresSupervisor: false,
      maxCashierLevel: 2,
    ),
    ProtectedAction.clearCart: ApprovalRequirement(
      action: ProtectedAction.clearCart,
      requiresSupervisor: false,
      maxCashierLevel: 1,
    ),
  };
}
