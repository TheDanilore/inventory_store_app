import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

class CloseCashShiftParams {
  final String shiftId;
  final double closingBalance;
  final String? notes;

  const CloseCashShiftParams({
    required this.shiftId,
    required this.closingBalance,
    this.notes,
  });
}

@lazySingleton
class CloseCashShiftUseCase implements UseCase<Unit, CloseCashShiftParams> {
  final CashShiftRepository repository;

  CloseCashShiftUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CloseCashShiftParams params) async {
    if (params.closingBalance < 0) {
      return left(const ValidationFailure(message: 'El saldo de cierre no puede ser negativo.'));
    }
    
    return await repository.closeShift(
      shiftId: params.shiftId,
      closingBalance: params.closingBalance,
      notes: params.notes,
    );
  }
}
