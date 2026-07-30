import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

@injectable
class CheckActiveShiftUc implements UseCase<CashShiftEntity?, String> {
  final CashShiftRepository _repository;

  CheckActiveShiftUc(this._repository);

  @override
  Future<Either<Failure, CashShiftEntity?>> call(String params) async {
    return await _repository.checkActiveShift(params);
  }
}
