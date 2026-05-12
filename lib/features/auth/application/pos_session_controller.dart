import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:holol_POS/core/errors/app_exception.dart';
import 'package:holol_POS/core/persistence/daos/active_pos_session_dao.dart';
import 'package:holol_POS/core/persistence/daos/audit_dao.dart';
import 'package:holol_POS/core/persistence/daos/auth_dao.dart';
import 'package:holol_POS/core/persistence/daos/shift_dao.dart';
import 'package:holol_POS/core/persistence/database.dart';
import 'package:holol_POS/features/cashier/application/product_providers.dart';
import 'package:holol_POS/features/cashier/domain/models/cart.dart';
import 'package:holol_POS/shared/models/enums.dart';
import 'package:holol_POS/shared/providers/core_providers.dart';
import 'package:uuid/uuid.dart';

/// Command controller for POS runtime session.
///
/// SSOT rules:
/// - ActivePosSession stores runtime user + machine only.
/// - Shifts table is the only source of open-shift state.
/// - AuthDao owns PIN/user lookup only.
/// - AuditDao owns login/logout audit.
class PosSessionState {
  final bool isLoading;
  final bool isResolvingUser;
  final String? errorMessage;
  final PosUser? resolvedUser;
  final List<RuntimeMachineChoice> machineChoices;
  final String? selectedMachineNo;

  const PosSessionState({
    this.isLoading = false,
    this.isResolvingUser = false,
    this.errorMessage,
    this.resolvedUser,
    this.machineChoices = const [],
    this.selectedMachineNo,
  });

  bool get canLogin {
    return resolvedUser != null &&
        selectedMachineNo?.trim().isNotEmpty == true &&
        !isResolvingUser &&
        !isLoading;
  }

  PosSessionState copyWith({
    bool? isLoading,
    bool? isResolvingUser,
    String? errorMessage,
    bool clearError = false,
    PosUser? resolvedUser,
    bool clearResolvedUser = false,
    List<RuntimeMachineChoice>? machineChoices,
    String? selectedMachineNo,
    bool clearSelectedMachine = false,
  }) {
    return PosSessionState(
      isLoading: isLoading ?? this.isLoading,
      isResolvingUser: isResolvingUser ?? this.isResolvingUser,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      resolvedUser: clearResolvedUser
          ? null
          : (resolvedUser ?? this.resolvedUser),
      machineChoices: machineChoices ?? this.machineChoices,
      selectedMachineNo: clearSelectedMachine
          ? null
          : (selectedMachineNo ?? this.selectedMachineNo),
    );
  }
}

class PosSessionController extends StateNotifier<PosSessionState> {
  final AuthDao _authDao;
  final AuditDao _auditDao;
  final ActivePosSessionDao _sessionDao;
  final ShiftDao _shiftDao;
  final Ref _ref;

  PosSessionController({
    required AuthDao authDao,
    required AuditDao auditDao,
    required ActivePosSessionDao sessionDao,
    required ShiftDao shiftDao,
    required Ref ref,
  }) : _authDao = authDao,
       _auditDao = auditDao,
       _sessionDao = sessionDao,
       _shiftDao = shiftDao,
       _ref = ref,
       super(const PosSessionState());

  static const _uuid = Uuid();

  int _resolveToken = 0;

  Future<void> resolveUserNumber(String value) async {
    final token = ++_resolveToken;
    final number = value.trim();

    state = const PosSessionState();

    if (number.isEmpty) {
      return;
    }

    state = state.copyWith(isResolvingUser: true, clearError: true);

    try {
      final user = await _authDao.findByUsername(number);

      if (token != _resolveToken) return;

      if (user == null) {
        state = const PosSessionState(
          errorMessage: 'رقم المستخدم غير موجود في بيانات التشغيل.',
        );
        return;
      }

      if (!user.isActive || !user.canLoginPos) {
        state = const PosSessionState(
          errorMessage: 'هذا المستخدم غير مسموح له بالدخول إلى نقاط البيع.',
        );
        return;
      }

      final choices = await _sessionDao.listRuntimeMachineChoicesForUser(
        user: user,
      );

      if (token != _resolveToken) return;

      state = PosSessionState(
        resolvedUser: user,
        machineChoices: choices,
        selectedMachineNo: choices.length == 1
            ? choices.single.machineNo
            : null,
        errorMessage: choices.isEmpty
            ? 'لا توجد نقطة تشغيل مرتبطة بهذا المستخدم.'
            : null,
      );
    } catch (e) {
      if (token != _resolveToken) return;
      state = PosSessionState(errorMessage: ErrorMapper.userMessage(e));
    }
  }

  void selectMachine(String? machineNo) {
    state = state.copyWith(
      selectedMachineNo: machineNo,
      clearSelectedMachine: machineNo == null || machineNo.trim().isEmpty,
      clearError: true,
    );
  }

  Future<bool> hasLocalPinForResolvedUser() async {
    final user = state.resolvedUser;

    if (user == null) {
      state = state.copyWith(errorMessage: 'أدخل رقم المستخدم أولًا.');
      return false;
    }

    return _authDao.hasLocalPin(userId: user.id);
  }

  Future<bool> loginWithPin(String pin) async {
    final user = state.resolvedUser;
    final machineNo = state.selectedMachineNo?.trim();

    if (user == null || machineNo == null || machineNo.isEmpty) {
      state = state.copyWith(
        errorMessage: 'أدخل رقم المستخدم واختر نقطة التشغيل.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final hasPin = await _authDao.hasLocalPin(userId: user.id);

      if (hasPin) {
        final ok = await _authDao.verifyLocalPin(userId: user.id, pin: pin);

        if (!ok) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'PIN غير صحيح.',
          );
          return false;
        }
      } else {
        await _authDao.setLocalPin(userId: user.id, pin: pin);
      }

      final machine = await _sessionDao.getMachine(machineNo: machineNo);

      if (machine == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Selected POS machine not found.',
        );
        return false;
      }

      final existingMachineShift = await _shiftDao.getOpenShift(
        machine.machineNo,
      );

      if (existingMachineShift != null &&
          existingMachineShift.cashierId != user.id) {
        state = state.copyWith(
          isLoading: false,
          errorMessage:
              'يوجد شفت مفتوح على هذا الجهاز لمستخدم آخر. أغلق الشفت أولًا.',
        );
        return false;
      }

      final session = await _sessionDao.startSession(
        user: user,
        machine: machine,
      );

      _clearCashierState();
      await _refreshActiveSession();

      final refreshedSession = await _sessionDao.getActive();
      final effectiveSession = refreshedSession ?? session;

      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.login,
        actorId: effectiveSession.activeUserId,
        actorName: effectiveSession.activeUserName,
        terminalId: effectiveSession.activeMachineNo,
      );

      state = const PosSessionState();
      return true;
    } catch (e) {
      state = PosSessionState(errorMessage: ErrorMapper.userMessage(e));
      return false;
    }
  }

  Future<void> logout() async {
    final session = await _sessionDao.getActive();

    if (session != null) {
      await _auditDao.log(
        id: 'AUD_${_uuid.v4()}',
        action: AuditAction.logout,
        actorId: session.activeUserId,
        actorName: session.activeUserName,
        terminalId: session.activeMachineNo,
      );
    }

    await _sessionDao.clearActive();
    _clearCashierState();
    await _refreshActiveSession();

    state = const PosSessionState();
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  Future<void> _refreshActiveSession() async {
    _ref.invalidate(activePosSessionProvider);
    _ref.invalidate(activePaymentProfileProvider);
    _ref.invalidate(manualPaymentProfileProvider);
    await _ref.read(activePosSessionProvider.future);
  }

  void _clearCashierState() {
    _ref.read(cartProvider.notifier).clearCart();
    _ref.read(searchQueryProvider.notifier).state = '';
    _ref.read(selectedCategoryProvider.notifier).state = null;
    _ref.invalidate(cashierProductCardsProvider);
    _ref.invalidate(categoryListProvider);
  }
}

final posSessionControllerProvider =
    StateNotifierProvider<PosSessionController, PosSessionState>((ref) {
      return PosSessionController(
        authDao: ref.watch(authDaoProvider),
        auditDao: ref.watch(auditDaoProvider),
        sessionDao: ref.watch(activePosSessionDaoProvider),
        shiftDao: ref.watch(shiftDaoProvider),
        ref: ref,
      );
    });
