import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

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
