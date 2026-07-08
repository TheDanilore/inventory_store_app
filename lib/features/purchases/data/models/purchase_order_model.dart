class PurchaseOrderModel {
  final String id;
  final DateTime createdAt;
  final String? supplierId;
  final String supplierName;
  final String? warehouseName;
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final double discountAmount;
  final double taxAmount;
  final String documentType;
  final String? documentNumber;
  final String? notes;
  final int itemCount;

  const PurchaseOrderModel({
    required this.id,
    required this.createdAt,
    this.supplierId,
    required this.supplierName,
    this.warehouseName,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.amountPaid,
    this.dueDate,
    required this.discountAmount,
    required this.taxAmount,
    required this.documentType,
    this.documentNumber,
    this.notes,
    required this.itemCount,
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
