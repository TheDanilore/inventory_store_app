import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';

class GetCashShiftsParams {
  final int limit;
  final int offset;
  final String? status;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? profileId;

  const GetCashShiftsParams({
    required this.limit,
    required this.offset,
    this.status,
    this.dateFrom,
    this.dateTo,
    this.profileId,
  });
}

@lazySingleton
class GetCashShiftsUseCase implements UseCase<({List<CashShiftEntity> shifts, int totalCount}), GetCashShiftsParams> {
  final CashShiftRepository repository;

  GetCashShiftsUseCase(this.repository);

  @override
  Future<Either<Failure, ({List<CashShiftEntity> shifts, int totalCount})>> call(GetCashShiftsParams params) async {
    return await repository.getShifts(
      limit: params.limit,
      offset: params.offset,
      status: params.status,
      dateFrom: params.dateFrom,
      dateTo: params.dateTo,
      profileId: params.profileId,
    );
  }
}
