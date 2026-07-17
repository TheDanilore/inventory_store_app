import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

class CalcExpectedCashShiftParams {
  final String shiftId;
  final String accountId;
  final double openingAmount;

  CalcExpectedCashShiftParams({
    required this.shiftId,
    required this.accountId,
    required this.openingAmount,
  });
}

@lazySingleton
class CalcExpectedCashShiftUseCase implements UseCase<double, CalcExpectedCashShiftParams> {
  final CashShiftRepository repository;

  CalcExpectedCashShiftUseCase(this.repository);

  @override
  Future<Either<Failure, double>> call(CalcExpectedCashShiftParams params) {
    return repository.calcExpected(
      shiftId: params.shiftId,
      accountId: params.accountId,
      openingAmount: params.openingAmount,
    );
  }
}
