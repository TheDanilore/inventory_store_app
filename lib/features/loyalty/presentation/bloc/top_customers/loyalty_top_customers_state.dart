import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

enum TopCustomersPeriod { thisMonth, thisYear, allTime, customMonth }

class TopCustomersState {
  final bool isLoading;
  final int limit;
  final TopCustomersPeriod period;
  final DateTime? customMonth;
  final List<CustomerEntity> participants;
  final bool isSpinning;
  final CustomerEntity? winner;

  const TopCustomersState({
    this.isLoading = false,
    this.limit = 10,
    this.period = TopCustomersPeriod.allTime,
    this.customMonth,
    this.participants = const [],
    this.isSpinning = false,
    this.winner,
  });

  String get periodLabel {
    final now = DateTime.now();
    switch (period) {
      case TopCustomersPeriod.thisMonth:
        return 'Mes Actual (${_monthName(now.month)} ${now.year})';
      case TopCustomersPeriod.thisYear:
        return 'Anual (${now.year})';
      case TopCustomersPeriod.allTime:
        return 'Histórico General';
      case TopCustomersPeriod.customMonth:
        if (customMonth != null) {
          return '${_monthName(customMonth!.month)} ${customMonth!.year}';
        }
        return 'Mes Personalizado';
    }
  }

  static String _monthName(int month) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  TopCustomersState copyWith({
    bool? isLoading,
    int? limit,
    TopCustomersPeriod? period,
    DateTime? customMonth,
    List<CustomerEntity>? participants,
    bool? isSpinning,
    CustomerEntity? winner,
    bool clearWinner = false,
    bool clearCustomMonth = false,
  }) {
    return TopCustomersState(
      isLoading: isLoading ?? this.isLoading,
      limit: limit ?? this.limit,
      period: period ?? this.period,
      customMonth: clearCustomMonth ? null : (customMonth ?? this.customMonth),
      participants: participants ?? this.participants,
      isSpinning: isSpinning ?? this.isSpinning,
      winner: clearWinner ? null : (winner ?? this.winner),
    );
  }
}
