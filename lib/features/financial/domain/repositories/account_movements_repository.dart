import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';

/// Parámetros de filtrado para la consulta de movimientos.
class MovementFilters {
  final String filterType; // 'Todos', 'INCOME', 'EXPENSE', 'TRANSFER'
  final String filterAccountId; // 'Todas' o un UUID
  final String searchText;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const MovementFilters({
    this.filterType = 'Todos',
    this.filterAccountId = 'Todas',
    this.searchText = '',
    this.dateFrom,
    this.dateTo,
  });
}

/// Totales agregados para el conjunto de movimientos filtrado.
class MovementTotals {
  final double totalIncome;
  final double totalExpense;

  const MovementTotals({required this.totalIncome, required this.totalExpense});
}

/// Contrato abstracto para la persistencia de Movimientos de Cuenta.
/// La capa de dominio depende de esta interfaz; la implementación concreta
/// vive en data/repositories_impl/.
abstract class AccountMovementsRepository {
  /// Retorna una página de movimientos con filtros y paginación aplicados.
  Future<List<AccountMovementEntity>> getMovements({
    required MovementFilters filters,
    required int page,
    required int pageSize,
  });

  /// Retorna el conteo total de movimientos para la paginación.
  Future<int> getMovementsCount({required MovementFilters filters});

  /// Retorna los totales de ingresos y egresos del conjunto filtrado.
  Future<MovementTotals> getMovementTotals({required MovementFilters filters});

  /// Registra un movimiento de cuenta manual (ingreso o egreso) y actualiza el saldo de la cuenta.
  Future<void> registerManualMovement({
    required String profileId,
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
  });

  /// Realiza una transferencia de fondos entre dos cuentas, actualizando saldos y registrando ambos movimientos.
  Future<void> transferFunds({
    required String profileId,
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  });
}
