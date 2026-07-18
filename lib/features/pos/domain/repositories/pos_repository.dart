import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';

/// Datos iniciales necesarios para arrancar el POS.
class PosInitData {
  final List<WarehouseModel> warehouses;
  final List<Map<String, dynamic>> accounts;

  const PosInitData({required this.warehouses, required this.accounts});
}

/// Contrato del repositorio para el módulo POS.
abstract class PosRepository {
  /// Carga los datos iniciales necesarios para el POS (almacenes, cuentas).
  Future<Either<Failure, PosInitData>> loadInitialData({
    bool forceRefresh = false,
  });

  /// Verifica si existe un turno de caja abierto para la cuenta dada.
  Future<Either<Failure, CashShiftEntity?>> checkActiveShift(String accountId);

  /// Busca clientes por nombre, documento o teléfono.
  Future<Either<Failure, List<Map<String, dynamic>>>> searchClients(
    String text,
  );

  /// Obtiene la información de crédito de un cliente.
  Future<Either<Failure, Map<String, dynamic>?>> fetchClientCredit(
    String clientId,
  );

  /// Obtiene los lotes disponibles para una variante en un almacén.
  Future<Either<Failure, List<BatchAssignmentModel>>> fetchBatchesForVariant(
    String variantId,
    String warehouseId,
  );

  /// Procesa y guarda una venta en el sistema.
  /// Retorna el ID de la orden generada.
  Future<Either<Failure, String>> processSale(SaleEntity sale);
}
