import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';

/// Contrato abstracto para la persistencia de Cuentas Financieras.
/// La capa de dominio depende de esta interfaz; la implementación concreta
/// vive en data/repositories_impl/.
abstract class FinancialAccountsRepository {
  /// Retorna una página de cuentas ordenadas por estado activo y nombre.
  Future<List<FinancialAccountEntity>> getAccounts({
    required int page,
    required int pageSize,
  });

  /// Retorna el total de cuentas para calcular la paginación.
  Future<int> getAccountsCount();

  /// Crea o actualiza una cuenta financiera.
  /// Si [accountId] es null, se crea una nueva cuenta.
  Future<void> saveAccount({
    String? accountId,
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
  });
}
