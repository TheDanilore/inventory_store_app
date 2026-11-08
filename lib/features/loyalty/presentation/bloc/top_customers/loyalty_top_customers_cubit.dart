import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers/loyalty_top_customers_state.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_top_customers_uc.dart';

@injectable
class LoyaltyTopCustomersCubit extends Cubit<TopCustomersState> {
  final GetTopCustomersUC getTopCustomersUC;

  LoyaltyTopCustomersCubit({required this.getTopCustomersUC})
    : super(TopCustomersState()) {
    _fetchParticipants();
  }

  void setLimit(int newLimit) {
    if (state.limit != newLimit) {
      emit(state.copyWith(limit: newLimit));
      _fetchParticipants();
    }
  }

  void setPeriod(TopCustomersPeriod period, {DateTime? customMonth}) {
    if (state.period != period || state.customMonth != customMonth) {
      emit(
        state.copyWith(
          period: period,
          customMonth: customMonth,
          clearCustomMonth:
              customMonth == null && period != TopCustomersPeriod.customMonth,
        ),
      );
      _fetchParticipants();
    }
  }

  Future<void> refresh() async {
    await _fetchParticipants();
  }

  Future<void> _fetchParticipants() async {
    emit(state.copyWith(isLoading: true, clearWinner: true));

    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    switch (state.period) {
      case TopCustomersPeriod.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        final nextMonth =
            now.month == 12
                ? DateTime(now.year + 1, 1, 1)
                : DateTime(now.year, now.month + 1, 1);
        endDate = nextMonth.subtract(const Duration(milliseconds: 1));
        break;
      case TopCustomersPeriod.thisYear:
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        break;
      case TopCustomersPeriod.allTime:
        startDate = null;
        endDate = null;
        break;
      case TopCustomersPeriod.customMonth:
        if (state.customMonth != null) {
          final m = state.customMonth!;
          startDate = DateTime(m.year, m.month, 1);
          final nextM =
              m.month == 12
                  ? DateTime(m.year + 1, 1, 1)
                  : DateTime(m.year, m.month + 1, 1);
          endDate = nextM.subtract(const Duration(milliseconds: 1));
        }
        break;
    }

    final result = await getTopCustomersUC(
      state.limit,
      startDate: startDate,
      endDate: endDate,
    );

    result.fold(
      (failure) {
        if (!isClosed) {
          emit(state.copyWith(isLoading: false, participants: []));
        }
      },
      (customers) {
        if (!isClosed) {
          emit(state.copyWith(isLoading: false, participants: customers));
        }
      },
    );
  }

  void startSpinning(CustomerEntity randomWinner) {
    emit(state.copyWith(isSpinning: true, winner: randomWinner));
  }

  void stopSpinning() {
    emit(state.copyWith(isSpinning: false));
  }
}
