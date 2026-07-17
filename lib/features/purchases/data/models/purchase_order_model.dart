import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_entity.dart';

class PurchaseOrderModel extends PurchaseOrderEntity {

  const PurchaseOrderModel({
    required super.id,
    required super.createdAt,
    super.supplierId,
    required super.supplierName,
    super.warehouseName,
    required super.status,
    required super.totalAmount,
    required super.paymentMethod,
    required super.paymentStatus,
    required super.amountPaid,
    super.dueDate,
    required super.discountAmount,
    required super.taxAmount,
    required super.documentType,
    super.documentNumber,
    super.notes,
    required super.itemCount,
  });

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> m) {
    final sup = m['suppliers'] as Map<String, dynamic>?;
    final wh = m['warehouses'] as Map<String, dynamic>?;

    // El count a veces viene en la misma consulta o como arreglo.
    // Si la query usa `purchase_order_items(count)` o arreglo:
    int count = 0;
    if (m['purchase_order_items'] is List) {
      count = (m['purchase_order_items'] as List).length;
    } else if (m['purchase_order_items'] is Map &&
        m['purchase_order_items']['count'] != null) {
      count = m['purchase_order_items']['count'] as int;
    }

    return PurchaseOrderModel(
      id: m['id'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      supplierId: m['supplier_id'] as String?,
      supplierName:
          m['supplier_name'] as String? ??
          sup?['name'] as String? ??
          'Sin proveedor',
      warehouseName: wh?['name'] as String?,
      status: m['status'] as String? ?? 'PENDING',
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: m['payment_method'] as String? ?? 'EFECTIVO',
      paymentStatus: m['payment_status'] as String? ?? 'PAID',
      amountPaid: (m['amount_paid'] as num?)?.toDouble() ?? 0,
      dueDate:
          m['due_date'] != null
              ? DateTime.tryParse(m['due_date'] as String)
              : null,
      discountAmount: (m['discount_amount'] as num?)?.toDouble() ?? 0,
      taxAmount: (m['tax_amount'] as num?)?.toDouble() ?? 0,
      documentType: m['document_type'] as String? ?? 'NINGUNO',
      documentNumber: m['document_number'] as String?,
      notes: m['notes'] as String?,
      itemCount: count,
    );
  }

  double get pending => totalAmount - amountPaid;
  bool get isFullyPaid => paymentStatus == 'PAID';
}
