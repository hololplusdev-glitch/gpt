import 'package:drift/drift.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/core/services/master_data/backend_value_reader.dart';
import 'package:holol_POS/core/services/master_data/master_data_contract.dart';
import 'package:holol_POS/shared/models/enums.dart';

class MasterDataPersistencePlan {
  final List<PosMachinesCompanion> posMachines;
  final List<PosUserMachineAccessCompanion> userMachineAccesses;
  final List<BranchProfileCompanion> branchProfiles;
  final List<StoresCompanion> stores;
  final List<PriceLevelsCompanion> priceLevels;
  final List<PosUsersCompanion> users;
  final List<ItemsCompanion> items;
  final List<ItemUnitsCompanion> itemUnits;
  final List<ItemBarcodesCompanion> itemBarcodes;
  final List<ItemPricesCompanion> itemPrices;
  final List<CustomersCompanion> customers;
  final List<PaymentMethodsCompanion> paymentMethods;

  const MasterDataPersistencePlan({
    this.posMachines = const [],
    this.userMachineAccesses = const [],
    this.branchProfiles = const [],
    this.stores = const [],
    this.priceLevels = const [],
    this.users = const [],
    this.items = const [],
    this.itemUnits = const [],
    this.itemBarcodes = const [],
    this.itemPrices = const [],
    this.customers = const [],
    this.paymentMethods = const [],
  });

  bool get isEmpty =>
      posMachines.isEmpty &&
      userMachineAccesses.isEmpty &&
      branchProfiles.isEmpty &&
      stores.isEmpty &&
      priceLevels.isEmpty &&
      users.isEmpty &&
      items.isEmpty &&
      itemUnits.isEmpty &&
      itemBarcodes.isEmpty &&
      itemPrices.isEmpty &&
      customers.isEmpty &&
      paymentMethods.isEmpty;
}

class MasterDataMapper {
  MasterDataPersistencePlan mapRows({
    required MasterDataType type,
    required MasterDataSyncContext context,
    required List<Map<String, dynamic>> rows,
    required DateTime cachedAt,
  }) {
    final posMachines = <PosMachinesCompanion>[];
    final userMachineAccesses = <PosUserMachineAccessCompanion>[];
    final branchProfiles = <BranchProfileCompanion>[];
    final stores = <StoresCompanion>[];
    final priceLevels = <PriceLevelsCompanion>[];
    final users = <PosUsersCompanion>[];
    final items = <ItemsCompanion>[];
    final itemUnits = <ItemUnitsCompanion>[];
    final itemBarcodes = <ItemBarcodesCompanion>[];
    final itemPrices = <ItemPricesCompanion>[];
    final customers = <CustomersCompanion>[];
    final paymentMethods = <PaymentMethodsCompanion>[];

    for (final row in rows) {
      switch (type) {
        case MasterDataType.posMachine:
          final data = _BackendRow(row);
          final mchnNbr = data.requiredText([
            'mchn_nbr',
            'machine_id',
          ], 'POS_MACHINE.mchn_nbr');
          final branchNo = data.requiredText([
            'bra_nbr',
          ], 'POS_MACHINE.bra_nbr');
          final branchYear = data.text(['bra_year']);
          final defaultStoreId = data.text(['def_st', 'st_id']);
          final priceLevelId = data.text(['price_lvl', 'price_lvl_id']);
          final useTax = data.boolValue(['use_tax'], fallback: true);
          final defaultBankId = data.text(['def_bank']);
          final defaultCardTypeId = data.text(['def_c_cardid']);
          final printerName = data.text(['printer_name']);

          posMachines.add(
            PosMachinesCompanion(
              id: Value(mchnNbr),
              machineNo: Value(mchnNbr),
              invoiceSeries: Value(data.text(['invo_ser'])),
              returnInvoiceSeries: Value(data.text(['rt_invo_ser'])),
              name: Value(data.text(['trmnl_name', 'terminal_name'])),
              storeId: Value(defaultStoreId),
              priceLevelId: Value(priceLevelId),
              useTax: Value(useTax),
              defaultBankId: Value(defaultBankId),
              defaultCardTypeId: Value(defaultCardTypeId),
              printerName: Value(printerName),
              autoPrint: Value(data.boolValue(['print_invo'])),
              allowDuplicateItems: Value(data.boolValue(['pos_dupl_itm'])),
              branchNo: Value(branchNo),
              branchYear: Value(branchYear),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.user:
          _mapUser(row, context, cachedAt, users);
          break;

        case MasterDataType.devicePrivilege:
          final data = _BackendRow(row);
          if (data.text(['login_name', 'usr_name', 'display_name']) != null) {
            _mapUser(row, context, cachedAt, users);
          }
          final usrId = data.requiredText(['usr_id'], 'DEVICE_PRIV.usr_id');
          final mchnNbr = data.requiredText([
            'mchn_nbr',
          ], 'DEVICE_PRIV.mchn_nbr');
          final used = data.boolValue(['used'], fallback: false);

          userMachineAccesses.add(
            PosUserMachineAccessCompanion(
              id: Value('UTA_${usrId}_$mchnNbr'),
              userId: Value(usrId),
              sourceUserId: Value(usrId),
              machineNo: Value(mchnNbr),
              terminalName: Value(data.text(['trmnl_name', 'terminal_name'])),
              useTax: Value(data.boolValue(['use_tax'], fallback: true)),
              branchNo: Value(data.text(['bra_nbr'])),
              branchYear: Value(data.text(['bra_year'])),
              storeId: Value(data.text(['st_id', 'def_st'])),
              priceLevelId: Value(data.text(['price_lvl_id', 'price_lvl'])),
              defaultBankId: Value(data.text(['def_bank'])),
              canUseMachine: Value(used),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.branch:
          final data = _BackendRow(row);
          final branchId = data.requiredText([
            'bra_nbr',
            'branch_id',
            'id',
          ], 'BRANCH.bra_nbr');
          branchProfiles.add(
            BranchProfileCompanion(
              id: Value(branchId),
              branchNo: Value(branchId),
              branchYear: Value(data.text(['bra_year'])),
              branchCode: Value(branchId),
              name: Value(
                data.text(['bra_name', 'branch_name', 'name']) ?? branchId,
              ),
              nameAr: Value(data.text(['bra_fname', 'bra_f_name', 'name_ar'])),
              address: Value(data.text(['bra_addr', 'address'])),
              taxNumber: Value(data.text(['bra_tax_id'])),
              commercialRegistrationNo: Value(data.text(['com_reg_nbr'])),
              commercialName: Value(data.text(['bra_comm_name'])),
              invoiceType: Value(data.text(['bra_inv_type'])),
              streetName: Value(data.text(['bra_street_name'])),
              buildingNo: Value(data.text(['bra_build_nbr'])),
              cityName: Value(data.text(['bra_city_name'])),
              postalZone: Value(data.text(['bra_postalzone'])),
              businessCategory: Value(data.text(['business_category'])),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              isActive: Value(!data.boolValue(['inactive'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.store:
          final data = _BackendRow(row);
          final stId = data.requiredText(['st_id', 'id'], 'STORE.st_id');
          stores.add(
            StoresCompanion(
              id: Value(stId),
              branchNo: Value(data.text(['bra_nbr'])),
              name: Value(data.text(['st_name', 'name']) ?? stId),
              nameAr: Value(data.text(['st_fname', 'st_f_name', 'name_ar'])),
              isDefault: Value(data.boolValue(['def_st', 'default_store'])),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.cash:
          final data = _BackendRow(row);
          final cashId = data.requiredText(['cash_id'], 'CASH.cash_id');
          final currencyId = data.text(['crncy_id']) ?? '';
          final methodId = currencyId.isEmpty
              ? '${PaymentMethodCodes.cashAccountPrefix}$cashId'
              : '${PaymentMethodCodes.cashAccountPrefix}${cashId}_$currencyId';
          final isActive = !data.boolValue(['inactive']);
          final isDefault = data.boolValue(['def_cash', 'is_default']);
          paymentMethods.add(
            PaymentMethodsCompanion(
              id: Value(methodId),
              type: Value(PaymentMethodType.cash.code),
              code: Value(methodId),
              name: Value(data.text(['cash_name', 'name']) ?? cashId),
              nameAr: Value(data.text(['cash_f_name', 'name_ar'])),
              cashId: Value(cashId),
              currencyId: Value(currencyId),
              isDefault: Value(isDefault),
              isActive: Value(isActive),
              requiresReference: const Value(false),
              sortOrder: const Value(10),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.bank:
          final data = _BackendRow(row);
          final bankId = data.requiredText(['bank_id'], 'BANK.bank_id');
          final methodId = '${PaymentMethodCodes.bankAccountPrefix}$bankId';
          paymentMethods.add(
            PaymentMethodsCompanion(
              id: Value(methodId),
              type: Value(PaymentMethodType.manualCard.code),
              code: Value(methodId),
              name: Value(data.text(['bank_name', 'name']) ?? bankId),
              nameAr: Value(
                data.text(['bank_fname', 'bank_f_name', 'name_ar']),
              ),
              bankId: Value(bankId),
              bankAccountId: Value(data.text(['bank_acc_id'])),
              isActive: Value(!data.boolValue(['inactive'])),
              requiresReference: const Value(true),
              sortOrder: const Value(20),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.creditCardType:
          final data = _BackendRow(row);
          final cardTypeId = data.requiredText([
            'c_card_id',
            'card_type_id',
            'credit_card_type_id',
          ], 'CREDIT_CARD_TYPE.card_type_id');
          final name =
              data.text(['c_card_name', 'card_type_name', 'name']) ??
              cardTypeId;
          final methodCode = '${PaymentMethodCodes.cardTypePrefix}$cardTypeId';
          paymentMethods.add(
            PaymentMethodsCompanion(
              id: Value(methodCode),
              type: Value(PaymentMethodType.manualCard.code),
              code: Value(methodCode),
              name: Value(name),
              nameAr: Value(data.text(['c_card_fname', 'name_ar'])),
              cardTypeId: Value(cardTypeId),
              bankId: Value(data.text(['bank_id'])),
              bankAccountId: Value(data.text(['bank_acc_id'])),
              commissionAccountId: Value(data.text(['coms_acc_id'])),
              commissionRate: Value(data.decimal(['coms_per']) ?? 0.0),
              dueIntervalDays: Value(
                BackendValueReader.parseInt(data.raw(['due_intrvl'])),
              ),
              branchNo: Value(data.text(['bra_nbr'])),
              branchYear: Value(data.text(['bra_year'])),
              isActive: Value(!data.boolValue(['inactive'])),
              requiresReference: const Value(true),
              sortOrder: const Value(30),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.priceLevel:
          final data = _BackendRow(row);
          final id = data.requiredText([
            'price_lvl_id',
            'price_lvl',
            'id',
          ], 'PRICE_LEVEL.price_lvl_id');
          priceLevels.add(
            PriceLevelsCompanion(
              id: Value(id),
              name: Value(data.text(['price_lvl_name', 'name']) ?? id),
              nameAr: Value(
                data.text(['price_lvl_fname', 'price_lvl_f_name', 'name_ar']),
              ),
              isDefault: Value(data.boolValue(['def_price', 'is_default'])),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.item:
          final data = _BackendRow(row);
          final itemId = data.requiredText([
            'itm_id',
            'item_id',
            'id',
          ], 'ITEM.itm_id');
          final inactive = data.boolValue(['inactive']);
          final noSale = data.boolValue(['no_sal', 'no_sale']);
          final taxRate = data.decimal(['tax_per']) ?? 0.0;
          final incomingDefaultUnit = data.text(['default_unit', 'unit_id']);

          items.add(
            ItemsCompanion(
              id: Value(itemId),
              code: Value(data.text(['itm_code', 'code']) ?? itemId),
              name: Value(data.text(['itm_name', 'name']) ?? itemId),
              nameAr: Value(data.text(['itm_fname', 'itm_f_name', 'name_ar'])),
              groupId: Value(data.text(['grp_id'])),
              defaultUnitId: incomingDefaultUnit != null
                  ? Value(incomingDefaultUnit)
                  : const Value.absent(),
              imageUrl: Value(data.text(['image_url'])),
              inactive: Value(inactive),
              noSale: Value(noSale),
              allowDiscount: Value(
                data.boolValue(['allow_disc'], fallback: false),
              ),
              taxRate: Value(taxRate),
              useQtyFraction: Value(data.boolValue(['use_qty_fraction'])),
              useExpiry: Value(data.boolValue(['use_exp_date'])),
              useBatch: Value(data.boolValue(['use_batch_nbr'])),
              sortOrder: Value(
                BackendValueReader.parseInt(data.raw(['sort_order'])) ?? 0,
              ),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.itemUnit:
          final data = _BackendRow(row);
          final itemId = data.requiredText([
            'itm_id',
            'item_id',
          ], 'ITEM_UNIT.itm_id');
          final unitId = data.requiredText(['unit_id'], 'ITEM_UNIT.unit_id');
          final rowId = '$itemId:$unitId';
          final isDefault = data.boolValue(['default_unit', 'is_default']);
          final inactive = data.boolValue(['inactive']);
          final noSale = data.boolValue(['no_sal', 'no_sale']);

          itemUnits.add(
            ItemUnitsCompanion(
              id: Value(rowId),
              itemId: Value(itemId),
              sourceUnitId: Value(unitId),
              name: Value(data.text(['unit_name', 'name']) ?? unitId),
              nameAr: Value(data.text(['unit_f_name', 'name_ar'])),
              conversionFactor: Value(data.decimal(['unit_size']) ?? 1),
              unitSize: Value(data.decimal(['unit_size'])),
              inactive: Value(inactive),
              noSale: Value(noSale),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              isDefault: Value(isDefault),
              cachedAt: Value(cachedAt),
            ),
          );

          final barcode = data.text(['barcode']);
          if (barcode != null && barcode.isNotEmpty) {
            itemBarcodes.add(
              ItemBarcodesCompanion(
                id: Value('ORA_BARCODE_${itemId}_$unitId'),
                itemId: Value(itemId),
                unitId: Value(rowId),
                barcode: Value(barcode),
                isPrimary: Value(isDefault),
                cachedAt: Value(cachedAt),
              ),
            );
          }

          if (isDefault) {
            // Need a way to update item's default unit if we don't have the item row.
            // But we'll handle this in DAO by updating the item when ItemUnit has isDefault.
          }
          break;

        case MasterDataType.itemPrice:
          final data = _BackendRow(row);
          final priceLevelId = data.requiredText([
            'price_lvl_id',
            'price_lvl',
          ], 'ITEM_PRICE.price_lvl_id');
          final itemId = data.requiredText([
            'itm_id',
            'item_id',
          ], 'ITEM_PRICE.itm_id');
          final storeId = data.text(['st_id']) ?? '';
          final unitId = data.requiredText(['unit_id'], 'ITEM_PRICE.unit_id');
          final id = [priceLevelId, itemId, storeId, unitId].join(':');
          final price = data.decimal(['itm_price', 'price']);
          if (price == null) {
            throw const SyncException(
              'ITEM_PRICE.itm_price is missing in master data response.',
              code: 'MASTER_DATA_MISSING_PRICE',
            );
          }

          itemPrices.add(
            ItemPricesCompanion(
              id: Value(id),
              itemId: Value(itemId),
              unitId: Value(unitId),
              priceLevelId: Value(priceLevelId),
              storeId: Value(storeId),
              unitPrice: Value(price),
              costPrice: Value(data.decimal(['cost_price'])),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;

        case MasterDataType.customer:
          final data = _BackendRow(row);
          final clntId = data.requiredText([
            'clnt_id',
            'customer_id',
          ], 'CLIENT.clnt_id');
          customers.add(
            CustomersCompanion(
              id: Value(clntId),
              name: Value(data.text(['clnt_name', 'name']) ?? clntId),
              accountId: Value(data.text(['clnt_acc_id'])),
              taxNumber: Value(data.text(['clnt_tax_id'])),
              mobile: Value(data.text(['clnt_mobile', 'mobile'])),
              discountRate: Value(data.decimal(['disc_per']) ?? 0.0),
              inactive: Value(data.boolValue(['inactive'])),
              sourceUpdatedAt: Value(data.text(['last_update'])),
              cachedAt: Value(cachedAt),
            ),
          );
          break;
      }
    }

    return MasterDataPersistencePlan(
      posMachines: posMachines,
      userMachineAccesses: userMachineAccesses,
      branchProfiles: branchProfiles,
      stores: stores,
      priceLevels: priceLevels,
      users: users,
      items: items,
      itemUnits: itemUnits,
      itemBarcodes: itemBarcodes,
      itemPrices: itemPrices,
      customers: customers,
      paymentMethods: paymentMethods,
    );
  }

  void _mapUser(
    Map<String, dynamic> row,
    MasterDataSyncContext context,
    DateTime cachedAt,
    List<PosUsersCompanion> users,
  ) {
    final data = _BackendRow(row);
    final usrId = data.requiredText(['usr_id', 'id'], 'USER_DTL.usr_id');
    final loginName = data.text(['login_name', 'username']) ?? usrId;
    users.add(
      PosUsersCompanion(
        id: Value(usrId),
        sourceUserId: Value(usrId),
        username: Value(loginName),
        loginName: Value(loginName),
        displayName: Value(
          data.text(['usr_name', 'display_name']) ?? loginName,
        ),
        displayNameAr: Value(
          data.text(['usr_fname', 'usr_f_name', 'display_name_ar']),
        ),
        authHash: const Value(''),
        // Local PIN is owned by LocalUserPins, never by backend USER data.
        roleId: Value(data.text(['role_id'])),
        defaultStoreId: Value(data.text(['st_id_def'])),
        defaultCashId: Value(data.text(['cash_id_def'])),
        branchNo: Value(data.text(['bra_nbr'])),
        branchYear: Value(data.text(['bra_year'])),
        accountId: Value(data.text(['acc_id'])),
        costCenterId: Value(data.text(['ccntr_id_def'])),
        userLevel: Value(data.text(['user_level'])),
        sourceUpdatedAt: Value(data.text(['last_update'])),
        isActive: Value(!data.boolValue(['inactive'])),
        canLoginPos: const Value(true),
        cachedAt: Value(cachedAt),
      ),
    );
  }
}

class _BackendRow {
  final Map<String, dynamic> _normalized;

  _BackendRow(Map<String, dynamic> row)
    : _normalized = {
        for (final entry in row.entries) entry.key.toLowerCase(): entry.value,
      };

  dynamic raw(List<String> keys) {
    for (final key in keys) {
      final value = _normalized[key.toLowerCase()];
      if (value != null) return value;
    }
    return null;
  }

  String? text(List<String> keys) {
    return BackendValueReader.text(raw(keys));
  }

  String requiredText(List<String> keys, String fieldName) {
    final value = text(keys);
    if (value == null) {
      throw SyncException(
        '$fieldName is missing in master data response.',
        code: 'MASTER_DATA_MISSING_FIELD',
      );
    }
    return value;
  }

  bool boolValue(List<String> keys, {bool fallback = false}) {
    return BackendValueReader.parseBool(raw(keys), fallback: fallback);
  }

  double? decimal(List<String> keys) {
    return BackendValueReader.parseDecimal(raw(keys));
  }
}
