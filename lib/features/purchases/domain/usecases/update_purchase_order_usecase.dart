import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class UpdatePurchaseOrderUseCase {
  final PurchaseOrdersRepository repository;

  UpdatePurchaseOrderUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String orderId,
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required List<dynamic> items,
    required double totalAmount,
    required String paymentMode,
    required String paymentStatus,
    required DateTime? dueDate,
    required DateTime? documentDate,
    required String documentType,
    required String? documentNumber,
    required String? notes,
  }) {
    return repository.updatePurchaseOrder(
      orderId: orderId,
      supplierId: supplierId,
      supplierName: supplierName,
      warehouseId: warehouseId,
      items: items,
      totalAmount: totalAmount,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      dueDate: dueDate,
      documentDate: documentDate,
      documentType: documentType,
      documentNumber: documentNumber,
      notes: notes,
    );
  }
}
