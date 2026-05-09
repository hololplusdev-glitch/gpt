import 'package:pos_flutter/shared/models/enums.dart';

class PaymentMethodOption {
  final String id;
  final String code;
  final String name;
  final PaymentMethodType type;
  final bool requiresReference;
  final String? bankId;
  final String? cardTypeId;

  const PaymentMethodOption({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.requiresReference = false,
    this.bankId,
    this.cardTypeId,
  });
}
