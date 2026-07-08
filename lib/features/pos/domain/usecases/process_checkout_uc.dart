import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/utils/result.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/pos/domain/entities/sale_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/pos_repository.dart';

/// Caso de uso para procesar y finalizar una venta en el POS.
class ProcessCheckoutUseCase extends UseCase<String, SaleEntity> {
  final PosRepository repository;

  ProcessCheckoutUseCase(this.repository);

  @override
  Future<Result<String>> execute(SaleEntity params) async {
    try {
      // 1. Validaciones de negocio puras
      if (params.items.isEmpty) {
        return const Error(ValidationFailure(message: 'La venta no tiene ítems.'));
      }

      if (params.totalAmount < 0) {
        return const Error(ValidationFailure(message: 'El total no puede ser negativo.'));
      }

      if (params.isCredit && !params.hasCustomer) {
        return const Error(
          ValidationFailure(
            message: 'Debe seleccionar un cliente para realizar una venta al crédito.',
          ),
        );
      }

      // 2. Ejecución a través del repositorio
      final orderId = await repository.processSale(params);
      return Success(orderId);
    } catch (e) {
      // En caso de que el repositorio lance una excepción
      return Error(Failure.from(e));
    }
  }
}
