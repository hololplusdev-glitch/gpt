import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/catalog_dao.dart';
import 'package:holol_POS/core/persistence/daos/sales_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/persistence/pos_config_repository.dart';
import 'package:holol_POS/core/services/payments/payment_method_resolver.dart';
import 'package:holol_POS/core/services/invoice_number_service.dart';
import 'package:holol_POS/core/services/invoices/invoice_document_builder.dart';
import 'package:holol_POS/core/services/pos_devices/payment_profile_service.dart';
import 'package:holol_POS/core/services/pos_devices/print_job_processor.dart';
import 'package:holol_POS/core/services/pos_devices/print_queue.dart';
import 'package:holol_POS/core/services/pricing/pricing_engine.dart';
import 'package:holol_POS/core/services/sync/outbox_event_factory.dart';
import 'package:holol_POS/core/services/time/clock.dart';
import 'package:holol_POS/features/sales/domain/models/sale_inputs.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/refactor/pos_business_rules.dart';
import 'package:uuid/uuid.dart';

typedef PaymentRuleExceptionFactory =
    BusinessException Function(String message);

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
  static double totalFromQuote(PosCheckoutQuote? quote) {
    return quote?.grandTotal ?? 0.0;
  }

  static bool isCreditPaymentType(PaymentMethodType type) {
    return type == PaymentMethodType.customerCredit;
  }

  static double parseMoney(String text) {
    return PosNumericInputRules.parseDecimalInput(text) ?? 0.0;
  }

  static PaymentDraftTotals calculateTotals({
    required double totalAmount,
    required Iterable<PaymentDraftLine> lines,
  }) {
    final actualPaidAmount = PricingEngine.roundAmount(
      lines
          .where((line) => line.kind != SaleTenderKind.credit)
          .fold(0.0, (sum, line) => sum + line.amount),
    );
    final creditAmount = PricingEngine.roundAmount(
      lines
          .where((line) => line.kind == SaleTenderKind.credit)
          .fold(0.0, (sum, line) => sum + line.amount),
    );
    final arrangedAmount = PricingEngine.roundAmount(
      actualPaidAmount + creditAmount,
    );
    final remaining = PricingEngine.roundAmount(totalAmount - arrangedAmount);
    return PaymentDraftTotals(
      totalAmount: totalAmount,
      actualPaidAmount: actualPaidAmount,
      creditAmount: creditAmount,
      arrangedAmount: arrangedAmount,
      remainingAmount: remaining > PosDomainTolerances.money ? remaining : 0.0,
      change: PricingEngine.roundAmount(
        lines.fold(0.0, (sum, line) => sum + line.change),
      ),
      hasCreditLine: lines.any((line) => line.kind == SaleTenderKind.credit),
    );
  }

  static double availableFor({
    required double totalAmount,
    required Iterable<PaymentDraftLine> lines,
    PaymentDraftLine? existing,
  }) {
    final totals = calculateTotals(totalAmount: totalAmount, lines: lines);
    return PricingEngine.roundAmount(
      totals.remainingAmount + (existing?.amount ?? 0),
    );
  }

  static PaymentDraftLineBuildResult buildDraftLine({
    required String id,
    required SaleTenderKind kind,
    required double rawInputAmount,
    required double availableAmount,
  }) {
    final input = PricingEngine.roundAmount(rawInputAmount);
    if (input.isNaN || input <= 0) {
      return const PaymentDraftLineBuildResult.failure(
        PaymentDraftLineError.invalidAmount,
      );
    }
    if (kind != SaleTenderKind.cash &&
        input - availableAmount > PosDomainTolerances.money) {
      return const PaymentDraftLineBuildResult.failure(
        PaymentDraftLineError.exceedsRemaining,
      );
    }
    final amount = kind == SaleTenderKind.cash && input > availableAmount
        ? availableAmount
        : input;
    return PaymentDraftLineBuildResult.success(
      PaymentDraftLine(
        id: id,
        kind: kind,
        amount: PricingEngine.roundAmount(amount),
        tenderedAmount: kind == SaleTenderKind.cash ? input : amount,
      ),
    );
  }

  static List<SalePaymentIntent> toPaymentIntents(
    Iterable<PaymentDraftLine> lines,
  ) {
    return lines
        .map(
          (line) => SalePaymentIntent(
            kind: line.kind,
            amount: line.amount,
            tenderedAmount: line.kind == SaleTenderKind.cash
                ? line.tenderedAmount
                : line.amount,
          ),
        )
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
    if (remainingAmount > PosDomainTolerances.money)
      return remainingNotCoveredMessage;
    if (hasCreditLine &&
        (selectedCustomerId == null || selectedCustomerId.trim().isEmpty)) {
      return creditRequiresCustomerMessage;
    }
    return null;
  }
}

class PaymentDraftSelection {
  final bool canSelect;
  final String amountText;
  final bool autoSubmit;

  const PaymentDraftSelection({
    required this.canSelect,
    required this.amountText,
    required this.autoSubmit,
  });

  const PaymentDraftSelection.rejected()
    : canSelect = false,
      amountText = '',
      autoSubmit = false;
}

class PaymentDraftSubmitResult {
  final bool success;
  final PaymentDraftLine? line;
  final PaymentDraftLineError? error;
  final String? amountText;

  const PaymentDraftSubmitResult({
    required this.success,
    this.line,
    this.error,
    this.amountText,
  });
}

class PaymentDraftController {
  static const _uuid = Uuid();

  final List<PaymentDraftLine> _lines = [];

  SaleTenderKind? activeLineKind;
  String? editingLineId;
  String? lineInputError;

  List<PaymentDraftLine> get lines => List.unmodifiable(_lines);

  bool get hasLines => _lines.isNotEmpty;

  PaymentDraftTotals totals(double totalAmount) {
    return PaymentDraftRules.calculateTotals(
      totalAmount: totalAmount,
      lines: _lines,
    );
  }

  PaymentDraftLine? lineById(String? id) {
    if (id == null) return null;
    for (final line in _lines) {
      if (line.id == id) return line;
    }
    return null;
  }

  double availableFor({
    required double totalAmount,
    PaymentDraftLine? existing,
  }) {
    return PaymentDraftRules.availableFor(
      totalAmount: totalAmount,
      lines: _lines,
      existing: existing,
    );
  }

  void removeLine(String id) {
    _lines.removeWhere((line) => line.id == id);

    if (editingLineId == id) {
      activeLineKind = null;
      editingLineId = null;
      lineInputError = null;
    }
  }

  PaymentDraftSelection selectLineKind({
    required SaleTenderKind kind,
    required double totalAmount,
    PaymentDraftLine? existing,
  }) {
    final available = availableFor(
      totalAmount: totalAmount,
      existing: existing,
    );

    if (available <= 0) {
      return const PaymentDraftSelection.rejected();
    }

    activeLineKind = kind;
    editingLineId = existing?.id;
    lineInputError = null;

    final value = kind == SaleTenderKind.cash
        ? existing?.tenderedAmount ?? available
        : existing?.amount ?? available;

    return PaymentDraftSelection(
      canSelect: true,
      amountText: value.toStringAsFixed(2),
      autoSubmit: existing == null,
    );
  }

  PaymentDraftSubmitResult submitInlineLine({
    required String rawInputText,
    required double totalAmount,
    bool showErrors = true,
    bool updateText = false,
    String invalidAmountMessage = 'أدخل مبلغًا صحيحًا أكبر من صفر.',
    String exceedsRemainingMessage = 'المبلغ لا يمكن أن يتجاوز المتبقي.',
  }) {
    final kind = activeLineKind;

    if (kind == null) {
      return const PaymentDraftSubmitResult(success: false);
    }

    final existing = lineById(editingLineId);

    final result = PaymentDraftRules.buildDraftLine(
      id: existing?.id ?? _uuid.v4(),
      kind: kind,
      rawInputAmount: PaymentDraftRules.parseMoney(rawInputText),
      availableAmount: availableFor(
        totalAmount: totalAmount,
        existing: existing,
      ),
    );

    if (!result.isSuccess) {
      lineInputError = showErrors
          ? switch (result.error) {
              PaymentDraftLineError.invalidAmount => invalidAmountMessage,
              PaymentDraftLineError.exceedsRemaining => exceedsRemainingMessage,
              null => invalidAmountMessage,
            }
          : null;

      return PaymentDraftSubmitResult(success: false, error: result.error);
    }

    final line = result.line!;
    upsertLine(line, existing);

    activeLineKind = kind;
    editingLineId = line.id;
    lineInputError = null;

    return PaymentDraftSubmitResult(
      success: true,
      line: line,
      amountText: updateText ? line.tenderedAmount.toStringAsFixed(2) : null,
    );
  }

  void upsertLine(PaymentDraftLine line, PaymentDraftLine? existing) {
    if (existing == null) {
      _lines.add(line);
      return;
    }

    final index = _lines.indexWhere((item) => item.id == existing.id);
    if (index >= 0) {
      _lines[index] = line.copyWith(id: existing.id);
    }
  }

  List<SalePaymentIntent> buildPaymentIntents() {
    return PaymentDraftRules.toPaymentIntents(_lines);
  }

  String? validateBeforeSubmit({
    required bool quoteReady,
    required double totalAmount,
    required String? selectedCustomerId,
    required String quoteNotReadyMessage,
    required String emptyPaymentMessage,
    required String remainingNotCoveredMessage,
    required String creditRequiresCustomerMessage,
  }) {
    final currentTotals = totals(totalAmount);

    return PaymentDraftRules.validateBeforeSubmit(
      quoteReady: quoteReady,
      hasPaymentLines: _lines.isNotEmpty,
      remainingAmount: currentTotals.remainingAmount,
      hasCreditLine: currentTotals.hasCreditLine,
      selectedCustomerId: selectedCustomerId,
      quoteNotReadyMessage: quoteNotReadyMessage,
      emptyPaymentMessage: emptyPaymentMessage,
      remainingNotCoveredMessage: remainingNotCoveredMessage,
      creditRequiresCustomerMessage: creditRequiresCustomerMessage,
    );
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
  bool requireCardReference = false,
  bool paymentProfileRequiresReference = false,
}) {
  final requiresReference =
      method.requiresReference ||
      (method.type.isManualCard && requireCardReference) ||
      (method.needsPaymentProfile && paymentProfileRequiresReference);

  return CheckoutPaymentRequirements(
    requiresReference: requiresReference,
    showsReference: requiresReference || !method.type.isCash,
  );
}

abstract final class PosCheckoutPaymentMethodDefaults {
  static const cash = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.cash,
    code: PaymentMethodCodes.cash,
    displayName: 'كاش',
    type: PaymentMethodType.cash,
    requiresReference: false,
    allowsChange: true,
    isManual: false,
    needsPaymentProfile: false,
  );

  static const manualCard = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.manualCard,
    code: PaymentMethodCodes.manualCard,
    displayName: 'شبكة',
    type: PaymentMethodType.manualCard,
    requiresReference: false,
    allowsChange: false,
    isManual: true,
    needsPaymentProfile: true,
  );

  static const customerCredit = ResolvedPaymentMethod(
    methodId: PaymentMethodCodes.customerCredit,
    code: PaymentMethodCodes.customerCredit,
    displayName: 'آجل',
    type: PaymentMethodType.customerCredit,
    requiresReference: false,
    allowsChange: false,
    isManual: true,
    needsPaymentProfile: false,
  );
}

abstract final class PosCheckoutPaymentMasterDataPolicy {
  static const bool allowBuiltInPaymentMethods = true;

  static bool hasUsablePaymentMethods(int activePaymentMethodCount) {
    return allowBuiltInPaymentMethods || activePaymentMethodCount > 0;
  }

  static List<String> readinessBlockers(int activePaymentMethodCount) {
    if (hasUsablePaymentMethods(activePaymentMethodCount)) return const [];
    return const ['No active payment methods'];
  }
}

class PaymentInputResolver {
  final CatalogDao catalogDao;
  final PaymentProfileService paymentProfileService;
  final ActivePosSession? activeSession;
  final bool requireCardReference;
  final PaymentRuleExceptionFactory? exceptionFactory;

  const PaymentInputResolver({
    required this.catalogDao,
    required this.paymentProfileService,
    required this.activeSession,
    this.requireCardReference = false,
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
      final profile = await paymentProfileService.getActivePaymentProfile(
        session.activeUserId,
      );
      effectiveType = PaymentMethodType.manualCard;
      profileRequiresReference = profile == null || !profile.enabled
          ? requireCardReference
          : profile.requireReference;
    }

    final requirements = checkoutPaymentRequirements(
      resolved,
      requireCardReference: requireCardReference,
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

    switch (intent.kind) {
      case SaleTenderKind.cash:
        final method = firstWhere((method) => typeOf(method)?.isCash ?? false);
        if (method == null) return PosCheckoutPaymentMethodDefaults.cash;
        return fromRow(method);
      case SaleTenderKind.network:
        final manual = firstWhere(
          (method) => typeOf(method) == PaymentMethodType.manualCard,
        );
        if (manual != null) return fromRow(manual);
        final card = firstWhere((method) => typeOf(method)?.isCard ?? false);
        if (card != null) return fromRow(card);
        return PosCheckoutPaymentMethodDefaults.manualCard;
      case SaleTenderKind.credit:
        final method = firstWhere(
          (method) => typeOf(method) == PaymentMethodType.customerCredit,
        );
        if (method != null) return fromRow(method);
        return PosCheckoutPaymentMethodDefaults.customerCredit;
    }
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ??
        BusinessException(message, code: 'payment_input_error');
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
    String? customerId,
  }) {
    if (payments.isEmpty) throw _exception('At least one payment is required.');
    if (quote.grandTotal < 0) throw _exception('Invalid sale total.');

    var paidTotal = 0.0;
    var explicitChangeTotal = 0.0;
    var arrangementTotal = 0.0;
    var hasChangeCapablePayment = false;
    var hasCustomerCreditPayment = false;

    for (final payment in payments) {
      final type = payment.resolvedType;
      arrangementTotal += payment.amount;

      if (payment.amount <= 0) {
        throw _exception('Payment amount must be greater than zero.');
      }

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

      if ((payment.requiresReference ||
              (requireCardReference && type.isManualCard)) &&
          !payment.hasReference) {
        throw _exception('Card payment reference is required.');
      }

      if (type == PaymentMethodType.customerCredit) {
        hasCustomerCreditPayment = true;
        continue;
      }

      paidTotal += payment.amount;
      explicitChangeTotal += changeGiven;
    }

    if (hasCustomerCreditPayment &&
        (customerId == null || customerId.trim().isEmpty)) {
      throw _exception('Customer is required for credit sale.');
    }

    if ((arrangementTotal - quote.grandTotal).abs() >
        PosDomainTolerances.money) {
      throw _exception('Payment split must equal invoice total.');
    }

    final remaining = quote.grandTotal - paidTotal;

    if (remaining > 0 && !hasCustomerCreditPayment) {
      throw _exception(
        'Payment of ${paidTotal.toStringAsFixed(2)} is insufficient for total ${quote.grandTotal.toStringAsFixed(2)}',
      );
    }

    final overpayment = paidTotal > quote.grandTotal
        ? paidTotal - quote.grandTotal
        : 0.0;

    if ((overpayment > 0 || explicitChangeTotal > 0) &&
        !hasChangeCapablePayment) {
      throw _exception('Overpayment requires a cash payment for change.');
    }

    return PaymentValidationResult(
      paidTotal: paidTotal,
      remainingTotal: remaining > 0 ? remaining : 0,
      changeTotal: explicitChangeTotal > 0 ? explicitChangeTotal : overpayment,
    );
  }

  BusinessException _exception(String message) {
    return exceptionFactory?.call(message) ??
        BusinessException(message, code: 'payment_policy_error');
  }
}

/// SSOT checkout workflow for sale + payment + invoice orchestration.
///
/// This class intentionally lives in shared/refactor during the consolidation
/// phase. Feature-level SaleCheckout must only delegate to this workflow.
class PosSaleCheckoutWorkflow {
  final SalesDao salesDao;
  final ShiftDao shiftDao;
  final CatalogDao catalogDao;
  final PosConfigRepository config;
  final InvoiceNumberService invoiceNumberService;
  final InvoiceDocumentBuilder invoiceDocumentBuilder;
  final OutboxEventFactory outboxEventFactory;
  final PrintQueue printQueue;
  final PrintJobProcessor printJobProcessor;
  final PaymentProfileService paymentProfileService;
  final ActivePosSession? activeSession;
  final PricingEngine pricingEngine;
  final Clock clock;

  const PosSaleCheckoutWorkflow({
    required this.salesDao,
    required this.shiftDao,
    required this.catalogDao,
    required this.config,
    required this.invoiceNumberService,
    required this.invoiceDocumentBuilder,
    required this.outboxEventFactory,
    required this.printQueue,
    required this.printJobProcessor,
    required this.paymentProfileService,
    required this.activeSession,
    this.pricingEngine = const PricingEngine(),
    this.clock = const SystemClock(),
  });

  Future<PosSaleCheckoutResult> complete(PosSaleCheckoutRequest request) async {
    final session = PosBusinessGuards.requireActiveSession(
      activeSession,
      message: 'Select a cashier and POS machine before selling.',
      exceptionFactory: PosSaleCheckoutException.new,
    );

    final shift = await PosBusinessGuards.requireOpenShift(
      shiftDao: shiftDao,
      session: session,
      message: 'No open shift. Open a shift before selling.',
      exceptionFactory: PosSaleCheckoutException.new,
    );

    if (request.cart.isEmpty) {
      throw const PosSaleCheckoutException('No items in cart.');
    }

    final saleLines = request.cart.toSaleLineInputs();

    SaleLineValidator.validateSaleLines(
      saleLines,
      exceptionFactory: PosSaleCheckoutException.new,
      validatePricing: true,
      pricingEngine: pricingEngine,
      priceIncludesTax: session.priceIncludesTax,
    );

    final quote = PosSaleQuoteRules.quote(
      pricingEngine: pricingEngine,
      lines: saleLines,
      useTax: session.activeUseTax,
      priceIncludesTax: session.priceIncludesTax,
      exceptionFactory: PosSaleCheckoutException.new,
    );

    final paymentInputResolver = PaymentInputResolver(
      catalogDao: catalogDao,
      paymentProfileService: paymentProfileService,
      activeSession: session,
      requireCardReference: config.requireCardReference,
      exceptionFactory: PosSaleCheckoutException.new,
    );

    final payments = <SalePaymentInput>[];
    PaymentMethodType? primaryType;

    for (final intent in request.paymentIntents) {
      final payment = await paymentInputResolver.build(intent);
      payments.add(payment);
      primaryType ??= payment.paymentMethodType;
    }

    final paymentResult =
        PaymentPolicy(
          requireCardReference: config.requireCardReference,
          exceptionFactory: PosSaleCheckoutException.new,
        ).validate(
          quote: quote,
          payments: payments,
          customerId: request.customerId,
        );

    final persistenceResult =
        await PosSaleCompletionWorkflow(
          salesDao: salesDao,
          config: config,
          invoiceNumberService: invoiceNumberService,
          invoiceDocumentBuilder: invoiceDocumentBuilder,
          outboxEventFactory: outboxEventFactory,
          printQueue: printQueue,
          printJobProcessor: printJobProcessor,
          clock: clock,
        ).persistCompletedSale(
          shiftId: shift.id,
          session: session,
          lines: saleLines,
          payments: payments,
          quote: quote,
          paymentResult: paymentResult,
          checkoutAttemptId: request.checkoutAttemptId,
          customerId: request.customerId,
          customerName: request.customerName,
          customerTaxNumber: request.customerTaxNumber,
        );

    return PosSaleCheckoutResult(
      saleId: persistenceResult.saleId,
      localSaleNo: persistenceResult.localSaleNo,
      selectedPaymentType: primaryType ?? PaymentMethodType.cash,
      change: paymentResult.changeTotal,
      uploadQueued: persistenceResult.uploadQueued,
    );
  }
}

class PosSaleCheckoutRequest {
  final Cart cart;
  final String checkoutAttemptId;
  final List<SalePaymentIntent> paymentIntents;
  final String? customerId;
  final String? customerName;
  final String? customerTaxNumber;

  PosSaleCheckoutRequest({
    required this.cart,
    required this.checkoutAttemptId,
    required this.paymentIntents,
    this.customerId,
    this.customerName,
    this.customerTaxNumber,
  });
}

class PosSaleCheckoutResult {
  final String saleId;
  final String localSaleNo;
  final PaymentMethodType selectedPaymentType;
  final double change;
  final bool uploadQueued;

  const PosSaleCheckoutResult({
    required this.saleId,
    required this.localSaleNo,
    required this.selectedPaymentType,
    required this.change,
    required this.uploadQueued,
  });

  String get invoiceNo => localSaleNo;
}

class PosSaleCheckoutException extends BusinessException {
  const PosSaleCheckoutException(super.message) : super(code: 'checkout_error');
}
