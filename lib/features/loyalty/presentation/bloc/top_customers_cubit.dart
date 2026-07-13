import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_top_customers_uc.dart';

class TopCustomersState {
  final bool isLoading;
  final int limit;
  final List<CustomerEntity> participants;
  final bool isSpinning;
  final CustomerEntity? winner;

  const TopCustomersState({
    this.isLoading = false,
    this.limit = 10,
    this.participants = const [],
    this.isSpinning = false,
    this.winner,
  });

  TopCustomersState copyWith({
    bool? isLoading,
    int? limit,
    List<CustomerEntity>? participants,
    bool? isSpinning,
    CustomerEntity? winner,
    bool clearWinner = false,
  }) {
    return TopCustomersState(
      isLoading: isLoading ?? this.isLoading,
      limit: limit ?? this.limit,
      participants: participants ?? this.participants,
      isSpinning: isSpinning ?? this.isSpinning,
      winner: clearWinner ? null : (winner ?? this.winner),
    );
  }
}

@injectable
class TopCustomersCubit extends Cubit<TopCustomersState> {
  final GetTopCustomersUC getTopCustomersUC;

  TopCustomersCubit({required this.getTopCustomersUC}) : super(const TopCustomersState()) {
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
        if (!isClosed) emit(state.copyWith(isLoading: false, participants: []));
      },
      (customers) {
        if (!isClosed) emit(state.copyWith(isLoading: false, participants: customers));
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
