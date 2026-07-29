import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

class OpenCashShiftParams {
  final String accountId;
  final double openingBalance;
  final String? notes;

  const OpenCashShiftParams({
    required this.accountId,
    required this.openingBalance,
    this.notes,
  });
}

@lazySingleton
class OpenCashShiftUseCase
    implements UseCase<CashShiftEntity, OpenCashShiftParams> {
  final CashShiftRepository repository;

  OpenCashShiftUseCase(this.repository);

  @override
  Future<Either<Failure, CashShiftEntity>> call(
    OpenCashShiftParams params,
  ) async {
    if (params.openingBalance < 0) {
      return left(
        const ValidationFailure(
          message: 'El saldo inicial no puede ser negativo.',
        ),
      );
    }

    return await repository.openShift(
      accountId: params.accountId,
      openingBalance: params.openingBalance,
      notes: params.notes,
    );
  }
}
