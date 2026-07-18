import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

class GetCashShiftsStatusCountParams {
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? profileId;

  const GetCashShiftsStatusCountParams({
    this.dateFrom,
    this.dateTo,
    this.profileId,
  });
}

@lazySingleton
class GetCashShiftsStatusCountUseCase
    implements
        UseCase<
          ({int openCount, int closedCount}),
          GetCashShiftsStatusCountParams
        > {
  final CashShiftRepository repository;

  GetCashShiftsStatusCountUseCase(this.repository);

  @override
  Future<Either<Failure, ({int openCount, int closedCount})>> call(
    GetCashShiftsStatusCountParams params,
  ) async {
    return await repository.getShiftsStatusCount(
      dateFrom: params.dateFrom,
      dateTo: params.dateTo,
      profileId: params.profileId,
    );
  }
}
