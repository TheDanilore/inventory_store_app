import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers_state.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_top_customers_uc.dart';

@injectable
class TopCustomersCubit extends Cubit<TopCustomersState> {
  final GetTopCustomersUC getTopCustomersUC;

  TopCustomersCubit({required this.getTopCustomersUC})
    : super(TopCustomersState()) {
    _fetchParticipants();
  }

  void setLimit(int newLimit) {
    if (state.limit != newLimit) {
      emit(state.copyWith(limit: newLimit));
      _fetchParticipants();
    }
  }

  Future<void> _fetchParticipants() async {
    emit(state.copyWith(isLoading: true, clearWinner: true));

    final result = await getTopCustomersUC(state.limit);
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
