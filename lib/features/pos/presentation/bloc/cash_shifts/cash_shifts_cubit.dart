import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/get_cash_shifts_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/get_cash_shifts_status_count_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/open_cash_shift_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/close_cash_shift_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/calc_expected_cash_shift_uc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@injectable
class CashShiftsCubit extends Cubit<CashShiftsState> {
  final GetCashShiftsUseCase _getCashShifts;
  final GetCashShiftsStatusCountUseCase _getCounts;
  final OpenCashShiftUseCase _openShift;
  final CloseCashShiftUseCase _closeShift;
  final CalcExpectedCashShiftUseCase _calcExpected;

  CashShiftsCubit({
    required GetCashShiftsUseCase getCashShifts,
    required GetCashShiftsStatusCountUseCase getCounts,
    required OpenCashShiftUseCase openShift,
    required CloseCashShiftUseCase closeShift,
    required CalcExpectedCashShiftUseCase calcExpected,
  })  : _getCashShifts = getCashShifts,
        _getCounts = getCounts,
        _openShift = openShift,
        _closeShift = closeShift,
        _calcExpected = calcExpected,
        super(const CashShiftsState());

  void setFilterStatus(String status) {
    emit(state.copyWith(filterStatus: status, currentPage: 0));
    fetchShifts();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    emit(state.copyWith(
      dateFrom: from,
      dateTo: to,
      currentPage: 0,
      clearDates: from == null && to == null,
    ));
    fetchShifts();
  }

  void setPage(int page) {
    if (page >= 0 && page < state.totalPages) {
      emit(state.copyWith(currentPage: page));
      fetchShifts();
    }
  }

  void setProfileFilter(String? profileId) {
    if (state.profileFilter != profileId) {
      emit(state.copyWith(
        profileFilter: profileId,
        currentPage: 0,
        clearProfileFilter: profileId == null,
      ));
      fetchShifts();
    }
  }

  Future<void> fetchShifts() async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));

    final offset = state.currentPage * state.pageSize;
    
    // Convert 'Todos' back to null for the query
    final statusQuery = state.filterStatus == 'Todos' ? null : (state.filterStatus == 'OPEN' ? 'OPEN' : 'CLOSED');

    final countRes = await _getCounts(GetCashShiftsStatusCountParams(
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      profileId: state.profileFilter,
    ));

    int totalOpen = 0;
    int totalClosed = 0;
    countRes.fold(
      (l) => null,
      (r) {
        totalOpen = r.openCount;
        totalClosed = r.closedCount;
      }
    );

    final shiftsRes = await _getCashShifts(GetCashShiftsParams(
      limit: state.pageSize,
      offset: offset,
      status: statusQuery,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      profileId: state.profileFilter,
    ));

    shiftsRes.fold(
      (failure) {
        emit(state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          totalOpenCount: totalOpen,
          totalClosedCount: totalClosed,
        ));
      },
      (data) {
        final openAccountIds = data.shifts
            .where((s) => s.status == CashShiftStatus.open && s.accountId != null)
            .map((s) => s.accountId!)
            .toSet();

        emit(state.copyWith(
          isLoading: false,
          shifts: data.shifts,
          totalCount: data.totalCount,
          totalOpenCount: totalOpen,
          totalClosedCount: totalClosed,
          openAccountIds: openAccountIds,
        ));
      }
    );
  }

  Future<void> openShift(String accountId, double openingBalance, {String? notes}) async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));
    final res = await _openShift(OpenCashShiftParams(
      accountId: accountId,
      openingBalance: openingBalance,
      notes: notes,
    ));

    res.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (_) {
        // Reload after open
        fetchShifts();
      }
    );
  }

  Future<void> closeShift(String shiftId, double closingBalance, {String? notes}) async {
    emit(state.copyWith(isLoading: true, errorMessage: ''));
    final res = await _closeShift(CloseCashShiftParams(
      shiftId: shiftId,
      closingBalance: closingBalance,
      notes: notes,
    ));

    res.fold(
      (failure) => emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (_) {
        // Reload after close
        fetchShifts();
      }
    );
  }

  Future<double> calcExpected(String shiftId, String accountId, double openingAmount) async {
    final res = await _calcExpected(CalcExpectedCashShiftParams(
      shiftId: shiftId,
      accountId: accountId,
      openingAmount: openingAmount,
    ));

    return res.fold(
      (failure) => openingAmount, // fallback
      (expectedAmount) => expectedAmount,
    );
  }

  Future<List<Map<String, dynamic>>> getAvailableAccounts() async {
    try {
      final res = await Supabase.instance.client
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .eq('type', 'CAJA')
          .order('name');
      
      final accounts = (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
      return accounts.where((a) => !state.openAccountIds.contains(a['id'])).toList();
    } catch (e) {
      return [];
    }
  }
}
