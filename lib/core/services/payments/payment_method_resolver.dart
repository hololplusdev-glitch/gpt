import 'package:holol_POS/shared/models/enums.dart';

class ResolvedPaymentMethod {
  final String methodId;
  final String code;
  final String displayName;
  final PaymentMethodType type;
  final String? bankId;
  final String? cardTypeId;
  final bool requiresReference;
  final bool allowsChange;
  final bool isManual;
  final bool needsPaymentProfile;

  const ResolvedPaymentMethod({
    required this.methodId,
    required this.code,
    required this.displayName,
    required this.type,
    this.bankId,
    this.cardTypeId,
    required this.requiresReference,
    required this.allowsChange,
    required this.isManual,
    required this.needsPaymentProfile,
  });
}

abstract final class PaymentMethodResolver {
  static const builtInCash = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.cash,
    code: PaymentMethodCodes.cash,
    displayName: 'كاش',
    type: PaymentMethodType.cash,
    requiresReference: false,
    allowsChange: true,
    isManual: false,
    needsPaymentProfile: false,
  );

  static const builtInManualCard = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.manualCard,
    code: PaymentMethodCodes.manualCard,
    displayName: 'شبكة',
    type: PaymentMethodType.manualCard,
    requiresReference: false,
    allowsChange: false,
    isManual: true,
    needsPaymentProfile: true,
  );

  static const builtInCustomerCredit = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.customerCredit,
    code: PaymentMethodCodes.customerCredit,
    displayName: 'آجل',
    type: PaymentMethodType.customerCredit,
    requiresReference: false,
    allowsChange: false,
    isManual: true,
    needsPaymentProfile: false,
  );

  static ResolvedPaymentMethod resolve({
    required String methodId,
    required String code,
    required String displayName,
    String? storedTypeCode,
    bool requiresReference = false,
    String? bankId,
    String? cardTypeId,
  }) {
    final type = typeFromStored(
      methodCode: code,
      storedTypeCode: storedTypeCode,
    );
    if (type == null) {
      throw StateError(
        'Unknown payment method type for "$displayName" (code: $code). '
        'Configure a valid payment method type.',
      );
    }
    return ResolvedPaymentMethod(
      methodId: methodId,
      code: code,
      displayName: displayName,
      type: type,
      bankId: bankId ?? bankIdFromCode(code),
      cardTypeId: cardTypeId ?? cardTypeIdFromCode(code),
      requiresReference: requiresReference,
      allowsChange: type.allowsChange,
      isManual: isManual(type),
      needsPaymentProfile: type.isCard,
    );
  }

  static PaymentMethodType? typeFromStored({
    required String methodCode,
    String? storedTypeCode,
  }) {
    final stored = storedTypeCode?.trim();
    if (stored != null && stored.isNotEmpty) {
      final parsed = PaymentMethodType.fromCode(stored);
      if (parsed != null) return parsed;
      return null;
    }
    return typeFromCode(methodCode);
  }

  static PaymentMethodType? typeFromCode(String code) {
    final normalized = code.trim().toUpperCase();
    if (normalized.startsWith(PaymentMethodCodes.cashAccountPrefix)) {
      return PaymentMethodType.cash;
    }
    if (normalized.startsWith(PaymentMethodCodes.bankAccountPrefix)) {
      return PaymentMethodType.manualCard;
    }
    if (normalized.startsWith(PaymentMethodCodes.cardTypePrefix)) {
      return PaymentMethodType.manualCard;
    }
    return switch (normalized) {
      PaymentMethodCodes.cash => PaymentMethodType.cash,
      PaymentMethodCodes.manualCard => PaymentMethodType.manualCard,
      PaymentMethodCodes.customerCredit => PaymentMethodType.customerCredit,
      _ => null,
    };
  }

  static String? bankIdFromCode(String code) {
    return _suffixForPrefix(code, PaymentMethodCodes.bankAccountPrefix);
  }

  static String? cardTypeIdFromCode(String code) {
    return _suffixForPrefix(code, PaymentMethodCodes.cardTypePrefix);
  }

  static String describe({
    required String methodCode,
    required String? methodName,
    required PaymentMethodType? type,
    required bool manualRecord,
  }) {
    final base = (methodName == null || methodName.trim().isEmpty)
        ? methodCode
        : methodName.trim();
    final resolved = type ?? typeFromCode(methodCode);
    if (manualRecord && resolved == PaymentMethodType.manualCard) {
      return '$base - تسجيل يدوي';
    }
    return base;
  }

  static bool isManual(PaymentMethodType type) {
    return switch (type) {
      PaymentMethodType.cash => false,
      PaymentMethodType.manualCard => true,
      PaymentMethodType.customerCredit => true,
    };
  }

  static String? _suffixForPrefix(String code, String prefix) {
    final trimmed = code.trim();
    if (!trimmed.toUpperCase().startsWith(prefix)) return null;
    final suffix = trimmed.substring(prefix.length).trim();
    return suffix.isEmpty ? null : suffix;
  }
}
