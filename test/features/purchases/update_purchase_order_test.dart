import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_purchase_order_usecase.dart';

class MockPurchaseOrdersRepository implements PurchaseOrdersRepository {
  bool updateCalled = false;
  String? lastOrderId;
  String? lastPaymentStatus;
  double? lastTotalAmount;
  int? lastItemCount;

  @override
  Future<Either<Failure, void>> updatePurchaseOrder({
    required String orderId,
    required String supplierId,
    required String supplierName,
    required String warehouseId,
    required double totalAmount,
    required DateTime? dueDate,
    required String paymentMode,
    required String paymentStatus,
    required String documentType,
    required String? documentNumber,
    required DateTime? documentDate,
    required String? notes,
    required List<dynamic> items,
  }) async {
    updateCalled = true;
    lastOrderId = orderId;
    lastPaymentStatus = paymentStatus;
    lastTotalAmount = totalAmount;
    lastItemCount = items.length;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UpdatePurchaseOrderUseCase useCase;
  late MockPurchaseOrdersRepository mockRepo;

  setUp(() {
    mockRepo = MockPurchaseOrdersRepository();
    useCase = UpdatePurchaseOrderUseCase(mockRepo);
  });

  test('UpdatePurchaseOrderUseCase ejecuta actualización correctamente en el repositorio', () async {
    final result = await useCase.call(
      orderId: 'po-123',
      supplierId: 'sup-1',
      supplierName: 'Distribuidora Central',
      warehouseId: 'wh-1',
      totalAmount: 500.0,
      dueDate: DateTime.now().add(const Duration(days: 5)),
      paymentMode: 'EFECTIVO',
      paymentStatus: 'PENDING',
      documentType: 'FACTURA',
      documentNumber: 'F001-000456',
      documentDate: DateTime.now(),
      notes: 'Actualización de prueba',
      items: [
        {
          'product_id': 'prod-1',
          'quantity_ordered': 10,
          'unit_cost': 50.0,
          'subtotal': 500.0,
        }
      ],
    );

    expect(result.isRight(), isTrue);
    expect(mockRepo.updateCalled, isTrue);
    expect(mockRepo.lastOrderId, equals('po-123'));
    expect(mockRepo.lastPaymentStatus, equals('PENDING'));
    expect(mockRepo.lastTotalAmount, equals(500.0));
    expect(mockRepo.lastItemCount, equals(1));
  });
}
