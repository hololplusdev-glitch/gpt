import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/payments/payment_method_resolver.dart';
import 'package:holol_POS/core/services/pos_devices/payment_profile_service.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';

typedef PaymentRuleExceptionFactory = BusinessException Function(String message);

class PaymentDraftLine {
  final String id;
  final SaleTenderKind kind;
  final double amount;
  final double tenderedAmount;

  const PaymentDraftLine({
    required this.id,
    required this.kind,
    required this.amount,
    required this.tenderedAmount,
  });

  double get change {
    if (kind != SaleTenderKind.cash) return 0.0;
    final value = PricingEngine.roundAmount(tenderedAmount - amount);
    return value > 0 ? value : 0.0;
  }

  PaymentDraftLine copyWith({
    String? id,
    SaleTenderKind? kind,
    double? amount,
    double? tenderedAmount,
  }) {
    return PaymentDraftLine(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      tenderedAmount: tenderedAmount ?? this.tenderedAmount,
    );
  }
}

class PaymentDraftTotals {
  final double totalAmount;
  final double actualPaidAmount;
  final double creditAmount;
  final double arrangedAmount;
  final double remainingAmount;
  final double change;
  final bool hasCreditLine;

  const PaymentDraftTotals({
    required this.totalAmount,
    required this.actualPaidAmount,
    required this.creditAmount,
    required this.arrangedAmount,
    required this.remainingAmount,
    required this.change,
    required this.hasCreditLine,
  });
}

enum PaymentDraftLineError { invalidAmount, exceedsRemaining }

class PaymentDraftLineBuildResult {
  final PaymentDraftLine? line;
  final PaymentDraftLineError? error;

  const PaymentDraftLineBuildResult.success(this.line) : error = null;
  const PaymentDraftLineBuildResult.failure(this.error) : line = null;

  bool get isSuccess => line != null;
}

abstract final class PaymentDraftRules {
  static double parseMoney(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return 0.0;
    return double.tryParse(normalized) ?? double.nan;
  }

  static PaymentDraftTotals calculateTotals({
    required double totalAmount,
    required Iterable<PaymentDraftLine> lines,
  }) {
    final actualPaidAmount = PricingEngine.roundAmount(
      lines.where((line) => line.kind != SaleTenderKind.credit).fold(0.0, (sum, line) => sum + line.amount),
    );
    final creditAmount = PricingEngine.roundAmount(
      lines.where((line) => line.kind == SaleTenderKind.credit).fold(0.0, (sum, line) => sum + line.amount),
    );
    final arrangedAmount = PricingEngine.roundAmount(actualPaidAmount + creditAmount);
    final remaining = PricingEngine.roundAmount(totalAmount - arrangedAmount);
    return PaymentDraftTotals(
      totalAmount: totalAmount,
      actualPaidAmount: actualPaidAmount,
      creditAmount: creditAmount,
      arrangedAmount: arrangedAmount,
      remainingAmount: remaining > PosDomainTolerances.money ? remaining : 0.0,
      change: PricingEngine.roundAmount(lines.fold(0.0, (sum, line) => sum + line.change)),
      hasCreditLine: lines.any((line) => line.kind == SaleTenderKind.credit),
    );
  }

  static double availableFor({
    required double totalAmount,
    required Iterable<PaymentDraftLine> lines,
    PaymentDraftLine? existing,
  }) {
    final totals = calculateTotals(totalAmount: totalAmount, lines: lines);
    return PricingEngine.roundAmount(totals.remainingAmount + (existing?.amount ?? 0));
  }

  static PaymentDraftLineBuildResult buildDraftLine({
    required String id,
    required SaleTenderKind kind,
    required double rawInputAmount,
    required double availableAmount,
  }) {
    final input = PricingEngine.roundAmount(rawInputAmount);
    if (input.isNaN || input <= 0) {
      return const PaymentDraftLineBuildResult.failure(PaymentDraftLineError.invalidAmount);
    }
    if (kind != SaleTenderKind.cash && input - availableAmount > PosDomainTolerances.money) {
      return const PaymentDraftLineBuildResult.failure(PaymentDraftLineError.exceedsRemaining);
    }
    final amount = kind == SaleTenderKind.cash && input > availableAmount ? availableAmount : input;
    return PaymentDraftLineBuildResult.success(
      PaymentDraftLine(
        id: id,
        kind: kind,
        amount: PricingEngine.roundAmount(amount),
        tenderedAmount: kind == SaleTenderKind.cash ? input : amount,
      ),
    );
  }

  static List<SalePaymentIntent> toPaymentIntents(Iterable<PaymentDraftLine> lines) {
    return lines
        .map((line) => SalePaymentIntent(
              kind: line.kind,
              amount: line.amount,
              tenderedAmount: line.kind == SaleTenderKind.cash ? line.tenderedAmount : line.amount,
            ))
        .toList(growable: false);
  }

  static String? validateBeforeSubmit({
    required bool quoteReady,
    required bool hasPaymentLines,
    required double remainingAmount,
    required bool hasCreditLine,
    required String? selectedCustomerId,
    required String quoteNotReadyMessage,
    required String emptyPaymentMessage,
    required String remainingNotCoveredMessage,
    required String creditRequiresCustomerMessage,
  }) {
    if (!quoteReady) return quoteNotReadyMessage;
    if (!hasPaymentLines) return emptyPaymentMessage;
    if (remainingAmount > PosDomainTolerances.money) return remainingNotCoveredMessage;
    if (hasCreditLine && (selectedCustomerId == null || selectedCustomerId.trim().isEmpty)) {
      return creditRequiresCustomerMessage;
    }
    return null;
  }
}

class CheckoutPaymentRequirements {
  final bool requiresReference;
  final bool showsReference;

  const CheckoutPaymentRequirements({
    required this.requiresReference,
    required this.showsReference,
  });
}

CheckoutPaymentRequirements checkoutPaymentRequirements(
  ResolvedPaymentMethod method, {
  bool paymentProfileRequiresReference = false,
}) {
  final requiresReference = method.type.isManualCard
      ? false
      : method.requiresReference ||
            (method.needsPaymentProfile && paymentProfileRequiresReference);

  return CheckoutPaymentRequirements(
    requiresReference: requiresReference,
    showsReference: requiresReference || !method.type.isCash,
  );
}

class PaymentInputResolver {
  final CatalogDao catalogDao;
  final PaymentProfileService paymentProfileService;
  final ActivePosSession? activeSession;
  final PaymentRuleExceptionFactory? exceptionFactory;

  const PaymentInputResolver({
    required this.catalogDao,
    required this.paymentProfileService,
    required this.activeSession,
    this.exceptionFactory,
  });

  Future<SalePaymentInput> build(SalePaymentIntent intent) async {
    final resolved = await resolve(intent);
    final amount = PricingEngine.roundAmount(intent.amount);

    if (amount <= 0 || amount.isNaN) {
      throw _exception('Payment amount must be greater than zero.');
    }

    var tendered = amount;
    var change = 0.0;

    if (resolved.allowsChange) {
      tendered = PricingEngine.roundAmount(intent.tenderedAmount ?? amount);
      if (tendered.isNaN) throw _exception('Enter a valid tendered amount.');
      if (tendered < amount) throw _exception('Insufficient amount tendered.');
      change = PricingEngine.roundAmount(tendered - amount);
    }

    var effectiveType = resolved.type;
    var profileRequiresReference = false;

    if (resolved.needsPaymentProfile) {
      final session = PosBusinessGuards.requireActiveSession(
        activeSession,
        message: 'Select a cashier and POS machine before selling.',
        exceptionFactory: exceptionFactory,
      );
      final profile = await paymentProfileService.getActivePaymentProfile(session.activeUserId);
      if (profile == null || !profile.enabled) {
        effectiveType = PaymentMethodType.manualCard;
      } else {
        effectiveType = PaymentMethodType.manualCard;
      }
    }

    final requirements = checkoutPaymentRequirements(
      resolved,
      paymentProfileRequiresReference: profileRequiresReference,
    );

    final reference = intent.reference.trim();
    if (requirements.requiresReference && reference.isEmpty) {
      throw _exception('Payment reference is required.');
    }

    return SalePaymentInput(
      paymentMethodId: resolved.methodId,
      paymentMethodCode: resolved.code,
      paymentMethodName: resolved.displayName,
      paymentMethodType: effectiveType,
      requiresReference: requirements.requiresReference,
      amount: amount,
      cashTendered: resolved.allowsChange ? tendered : null,
      changeGiven: resolved.allowsChange ? change : null,
      referenceNo: reference.isEmpty ? null : reference,
      bankId: resolved.bankId,
      cardTypeId: resolved.cardTypeId,
    );
  }

  Future<ResolvedPaymentMethod> resolve(SalePaymentIntent intent) async {
    final methods = await catalogDao.getActivePaymentMethods();

    PaymentMethod? firstWhere(bool Function(PaymentMethod method) test) {
      for (final method in methods) {
        final type = PaymentMethodResolver.typeFromStored(
          methodCode: method.code,
          storedTypeCode: method.type,
        );
        if (type != null && test(method)) return method;
      }
      return null;
    }

    PaymentMethodType? typeOf(PaymentMethod method) {
      return PaymentMethodResolver.typeFromStored(
        methodCode: method.code,
        storedTypeCode: method.type,
      );
    }

    ResolvedPaymentMethod fromRow(PaymentMethod method) {
      return PaymentMethodResolver.resolve(
        methodId: method.id,
        code: method.code,
        displayName: method.name,
        storedTypeCode: method.type,
        requiresReference: method.requiresReference,
        bankId: method.bankId,
        cardTypeId: method.cardTypeId,
      );
    }

    ResolvedPaymentMethod withoutReference(ResolvedPaymentMethod method) {
      return ResolvedPaymentMethod(
        methodId: method.methodId,
        code: method.code,
        displayName: method.displayName,
        type: method.type,
        bankId: method.bankId,
        cardTypeId: method.cardTypeId,
        requiresReference: false,
        allowsChange: method.allowsChange,
        isManual: method.isManual,
        needsPaymentProfile: method.needsPaymentProfile,
      );
    }

    switch (intent.kind) {
      case SaleTenderKind.cash:
        final method = firstWhere((method) => typeOf(method)?.isCash ?? false);
        if (method == null) return PaymentMethodResolver.builtInCash;
        return fromRow(method);
      case SaleTenderKind.network:
        final manual = firstWhere((method) => typeOf(method) == PaymentMethodType.manualCard);
        if (manual != null) return withoutReference(fromRow(manual));
        final card = firstWhere((method) => typeOf(method)?.isCard ?? false);
        if (card != null) return withoutReference(fromRow(card));
        return PaymentMethodResolver.builtInManualCard;
      case SaleTenderKind.credit:
        final method = firstWhere((method) => typeOf(method) == PaymentMethodType.customerCredit);
        if (method != null) return fromRow(method);
        return PaymentMethodResolver.builtInCustomerCredit;
    }
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ?? BusinessException(message, code: 'payment_input_error');
  }
}

class PaymentPolicy {
  final bool requireCardReference;
  final PaymentRuleExceptionFactory? exceptionFactory;

  const PaymentPolicy({
    required this.requireCardReference,
    this.exceptionFactory,
  });

  PaymentValidationResult validate({
    required CheckoutQuote quote,
    required List<SalePaymentInput> payments,
  }) {
    if (payments.isEmpty) throw _exception('At least one payment is required.');
    if (quote.grandTotal < 0) throw _exception('Invalid sale total.');

    var paidTotal = 0.0;
    var explicitChangeTotal = 0.0;
    var arrangementTotal = 0.0;
    var hasChangeCapablePayment = false;

    for (final payment in payments) {
      final type = payment.resolvedType;
      arrangementTotal += payment.amount;

      if (payment.amount <= 0) throw _exception('Payment amount must be greater than zero.');

      final cashTendered = payment.cashTendered;
      final changeGiven = payment.changeGiven ?? 0;

      if ((cashTendered ?? 0) < 0 || changeGiven < 0) {
        throw _exception('Invalid cash tendered/change values.');
      }

      if (type.allowsChange) {
        hasChangeCapablePayment = true;
        if (cashTendered != null && cashTendered < payment.amount) {
          throw _exception('Cash tendered is less than payment amount.');
        }
      } else if (changeGiven > 0 || cashTendered != null) {
        throw _exception('Change is only allowed for cash payments.');
      }

      if (payment.requiresReference && !payment.hasReference) {
        throw _exception('Card payment reference is required.');
      }

      if (type == PaymentMethodType.customerCredit) continue;

      paidTotal += payment.amount;
      explicitChangeTotal += changeGiven;
    }

    if ((arrangementTotal - quote.grandTotal).abs() > PosDomainTolerances.money) {
      throw _exception('Payment split must equal invoice total.');
    }

    final remaining = quote.grandTotal - paidTotal;
    if (remaining > 0 && !payments.any((payment) => payment.resolvedType == PaymentMethodType.customerCredit)) {
      throw _exception('Payment of ${paidTotal.toStringAsFixed(2)} is insufficient for total ${quote.grandTotal.toStringAsFixed(2)}');
    }

    final overpayment = paidTotal > quote.grandTotal ? paidTotal - quote.grandTotal : 0.0;
    if ((overpayment > 0 || explicitChangeTotal > 0) && !hasChangeCapablePayment) {
      throw _exception('Overpayment requires a cash payment for change.');
    }

    return PaymentValidationResult(
      paidTotal: paidTotal,
      remainingTotal: remaining > 0 ? remaining : 0,
      changeTotal: explicitChangeTotal > 0 ? explicitChangeTotal : overpayment,
    );
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ?? BusinessException(message, code: 'payment_policy_error');
  }
}
