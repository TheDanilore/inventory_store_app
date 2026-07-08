import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

/// Caso de uso para verificar si existe un turno de caja activo
/// para una cuenta financiera específica.
class CheckActiveShiftUseCase extends UseCase<CashShiftEntity?, String> {
  final PosRepository repository;

  CheckActiveShiftUseCase(this.repository);

  @override
  Future<Either<Failure, CashShiftEntity?>> call(String accountId) async {
    try {
      if (accountId.isEmpty) {
        return left(ValidationFailure(message: 'El ID de la cuenta no puede estar vacío.'));
      }
      final shift = await repository.checkActiveShift(accountId);
      return right(shift);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
