import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
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
