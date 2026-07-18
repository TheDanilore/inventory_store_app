import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';

abstract class CashShiftRepository {
  /// Lista los turnos de caja con filtros y paginación.
  Future<Either<Failure, ({List<CashShiftEntity> shifts, int totalCount})>>
  getShifts({
    required int limit,
    required int offset,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? profileId,
  });

  /// Obtiene los contadores totales de turnos abiertos y cerrados.
  Future<Either<Failure, ({int openCount, int closedCount})>>
  getShiftsStatusCount({
    DateTime? dateFrom,
    DateTime? dateTo,
    String? profileId,
  });

  /// Abre un nuevo turno de caja.
  Future<Either<Failure, CashShiftEntity>> openShift({
    required String accountId,
    required double openingBalance,
    String? notes,
  });

  /// Cierra un turno de caja existente.
  Future<Either<Failure, Unit>> closeShift({
    required String shiftId,
    required double closingBalance,
    String? notes,
  });

  /// Calcula el monto esperado de un turno de caja basado en sus movimientos.
  Future<Either<Failure, double>> calcExpected({
    required String shiftId,
    required String accountId,
    required double openingAmount,
  });
}
