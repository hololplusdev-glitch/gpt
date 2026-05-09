import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_flutter/core/errors/app_exception.dart';
import 'package:pos_flutter/core/services/invoices/invoice_output_coordinator.dart';
import 'package:pos_flutter/core/services/payments/payment_method_resolver.dart';
import 'package:pos_flutter/core/services/pos_devices/payment_profile_service.dart';
import 'package:pos_flutter/core/services/pricing/pricing_engine.dart';
import 'package:pos_flutter/core/persistence/pos_config_repository.dart';
import 'package:pos_flutter/features/auth/application/auth_notifier.dart';
import 'package:pos_flutter/features/cashier/application/cart_mapper.dart';
import 'package:pos_flutter/features/cashier/application/cart_notifier.dart';
import 'package:pos_flutter/features/cashier/domain/models/payment_method_option.dart';
import 'package:pos_flutter/features/sales/application/sales_service.dart';
import 'package:pos_flutter/features/sales/domain/models/sale_inputs.dart';
import 'package:pos_flutter/features/shift/application/shift_notifier.dart';
import 'package:pos_flutter/shared/models/enums.dart';
import 'package:pos_flutter/shared/providers/core_providers.dart';

class CheckoutCoordinator {
  final SalesService _salesService;
  final PaymentProfileService _paymentProfileService;
  final InvoiceOutputCoordinator _invoiceOutputCoordinator;
  final PosConfigRepository _config;

  const CheckoutCoordinator({
    required SalesService salesService,
    required PaymentProfileService paymentProfileService,
    required InvoiceOutputCoordinator invoiceOutputCoordinator,
    required PosConfigRepository config,
  }) : _salesService = salesService,
       _paymentProfileService = paymentProfileService,
       _invoiceOutputCoordinator = invoiceOutputCoordinator,
       _config = config;

  Future<CheckoutResult> complete(CheckoutRequest request) async {
    final authState = request.authState;
    if (!authState.isAuthenticated || authState.session == null) {
      throw const CheckoutException('Login again before completing payment.');
    }
    final shiftState = request.shiftState;
    if (!shiftState.hasOpenShift || shiftState.activeShift == null) {
      throw const CheckoutException('Open a shift before completing payment.');
    }
    if (request.cart.isEmpty) {
      throw const CheckoutException('No items in cart.');
    }

    final lines = CartMapper.saleLineInputs(request.cart);
    final quote = _salesService.quoteSale(lineItems: lines);
    final resolved = resolveCheckoutPaymentMethod(request.paymentMethod);

    var tendered = quote.grandTotal;
    var change = 0.0;
    if (resolved.allowsChange) {
      tendered =
          double.tryParse(
            request.tenderedText.trim().isEmpty ? '0' : request.tenderedText,
          ) ??
          double.nan;
      if (tendered.isNaN) {
        throw const CheckoutException('Enter a valid tendered amount.');
      }
      if (tendered < quote.grandTotal) {
        throw const CheckoutException('Insufficient amount tendered.');
      }
      change = PricingEngine.roundAmount(tendered - quote.grandTotal);
    }

    var effectiveType = resolved.type;
    var profileRequiresReference = false;
    if (resolved.needsPaymentProfile) {
      final profile = await _paymentProfileService.getActivePaymentProfile();
      if (profile == null || !profile.enabled) {
        throw const CheckoutException('Card payment is not configured.');
      }
      final mode = PaymentProfileMode.fromCode(profile.mode);
      if (mode == PaymentProfileMode.integrated) {
        throw const CheckoutException('Integrated payment is not available.');
      }
      effectiveType = PaymentMethodType.manualCard;
      profileRequiresReference = profile.requireReference;
    }
    final requirements = checkoutPaymentRequirements(
      resolved,
      paymentProfileRequiresReference: profileRequiresReference,
    );

    final reference = request.reference.trim();
    if (requirements.requiresReference && reference.isEmpty) {
      throw const CheckoutException('Payment reference is required.');
    }

    final session = authState.session!;
    final shift = shiftState.activeShift!;
    final saleId = await _salesService.completeSale(
      shiftId: shift.id,
      lineItems: lines,
      payments: [
        SalePaymentInput(
          paymentMethodId: resolved.methodId,
          paymentMethodCode: resolved.code,
          paymentMethodName: resolved.displayName,
          paymentMethodType: effectiveType,
          requiresReference: requirements.requiresReference,
          amount: quote.grandTotal,
          cashTendered: resolved.allowsChange ? tendered : null,
          changeGiven: resolved.allowsChange ? change : null,
          referenceNo: reference.isEmpty ? null : reference,
          bankId: resolved.bankId,
          cardTypeId: resolved.cardTypeId,
        ),
      ],
      customerId: request.customerId,
      customerName: request.customerName,
      customerTaxNumber: request.customerTaxNumber,
    );

    final invoice = await _invoiceOutputCoordinator.getOrCreateOriginal(saleId);
    InvoicePrintResult? printResult;
    if (_config.autoPrintAfterSale) {
      printResult = await _invoiceOutputCoordinator.printOriginal(
        saleId,
        createdBy: session.userId,
        requireAutoPrint: true,
      );
    }
    return CheckoutResult(
      saleId: saleId,
      invoiceNo: invoice.localInvoiceNo,
      selectedPaymentType: resolved.type,
      change: change,
      printResult: printResult,
    );
  }
}

class CheckoutRequest {
  final Cart cart;
  final AuthState authState;
  final ShiftState shiftState;
  final PaymentMethodOption paymentMethod;
  final String tenderedText;
  final String reference;
  final String? customerId;
  final String? customerName;
  final String? customerTaxNumber;

  const CheckoutRequest({
    required this.cart,
    required this.authState,
    required this.shiftState,
    required this.paymentMethod,
    required this.tenderedText,
    required this.reference,
    this.customerId,
    this.customerName,
    this.customerTaxNumber,
  });
}

class CheckoutPaymentRequirements {
  final bool requiresReference;
  final bool showsReference;

  const CheckoutPaymentRequirements({
    required this.requiresReference,
    required this.showsReference,
  });
}

ResolvedPaymentMethod resolveCheckoutPaymentMethod(PaymentMethodOption method) {
  return PaymentMethodResolver.resolve(
    methodId: method.id,
    code: method.code,
    displayName: method.name,
    storedTypeCode: method.type.code,
    requiresReference: method.requiresReference,
    bankId: method.bankId,
    cardTypeId: method.cardTypeId,
  );
}

CheckoutPaymentRequirements checkoutPaymentRequirements(
  ResolvedPaymentMethod method, {
  bool paymentProfileRequiresReference = false,
}) {
  final requiresReference =
      method.requiresReference ||
      (method.needsPaymentProfile && paymentProfileRequiresReference);
  return CheckoutPaymentRequirements(
    requiresReference: requiresReference,
    showsReference: requiresReference || !method.type.isCash,
  );
}

class CheckoutResult {
  final String saleId;
  final String invoiceNo;
  final PaymentMethodType selectedPaymentType;
  final double change;
  final InvoicePrintResult? printResult;

  const CheckoutResult({
    required this.saleId,
    required this.invoiceNo,
    required this.selectedPaymentType,
    required this.change,
    this.printResult,
  });
}

class CheckoutException extends BusinessException {
  const CheckoutException(super.message) : super(code: 'checkout_error');
}

final checkoutCoordinatorProvider = Provider<CheckoutCoordinator>((ref) {
  return CheckoutCoordinator(
    salesService: ref.watch(salesServiceProvider),
    paymentProfileService: ref.watch(paymentProfileServiceProvider),
    invoiceOutputCoordinator: ref.watch(invoiceOutputCoordinatorProvider),
    config: ref.watch(posConfigProvider),
  );
});
