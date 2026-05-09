// core/identity/pos_station_identity.dart
// WHY: POS station identity is not the same as a payment terminal profile.
// This model is the runtime identity used by sales, shifts, sync, audit, and print.

class PosStationIdentity {
  final String posStationId;
  final String branchId;
  final String? branchName;
  final String? companyId;
  final String deviceName;
  final String? machineName;
  final DateTime registeredAt;
  final DateTime? lastSeenAt;
  final bool isActive;
  final PosStationIdentitySource source;

  const PosStationIdentity({
    required this.posStationId,
    required this.branchId,
    this.branchName,
    this.companyId,
    required this.deviceName,
    this.machineName,
    required this.registeredAt,
    this.lastSeenAt,
    this.isActive = true,
    required this.source,
  });

  bool get isValid =>
      posStationId.trim().isNotEmpty && branchId.trim().isNotEmpty && isActive;

  PosStationIdentity copyWith({
    String? posStationId,
    String? branchId,
    String? branchName,
    String? companyId,
    String? deviceName,
    String? machineName,
    DateTime? registeredAt,
    DateTime? lastSeenAt,
    bool? isActive,
    PosStationIdentitySource? source,
  }) {
    return PosStationIdentity(
      posStationId: posStationId ?? this.posStationId,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      companyId: companyId ?? this.companyId,
      deviceName: deviceName ?? this.deviceName,
      machineName: machineName ?? this.machineName,
      registeredAt: registeredAt ?? this.registeredAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
      source: source ?? this.source,
    );
  }
}

enum PosStationIdentitySource { setup, server, dev }
