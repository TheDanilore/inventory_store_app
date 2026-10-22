import 'package:equatable/equatable.dart';

class OrderEntity extends Equatable {
  final String id;
  final String? customerId;
  final double totalAmount;
  final double totalProfit;
  final String paymentMethod;
  final String status;
  final DateTime? createdAt;
  final String? warehouseId;
  final int pointsUsed;
  final int pointsEarned;
  final String customerName;
  final String paymentStatus;
  final double amountPaid;
  final DateTime? dueDate;
  final String? createdBy;
  final String? updatedBy;
  final DateTime? updatedAt;
  final double discountAmount;

  final String? warehouseName; // Extracted from warehouse relation if needed
  final String? profileFullName;
  final String? profilePhone;

  // ── Dimensiones Fiscales y de Comprobante ─────────────────────────────────
  final String
  documentType; // 'NOTA_VENTA', 'BOLETA', 'FACTURA', 'TICKET', 'NINGUNO'
  final String? documentSeries; // 'NV01', 'B001', 'F001'
  final String? documentNumber; // 'B001-00000045'
  final DateTime? documentDate;
  final double taxAmount; // IGV 18%
  final double subtotalAmount; // Base imponible
  final String? paymentReference; // Nº Op / Ref (Yape, Plin, Tarjeta)
  final String? customerDocumentType; // 'DNI', 'RUC', 'CE'
  final String? customerDocumentNumber; // '10723456789'
  final String? customerAddress; // Dirección fiscal para Facturas

  // ── Multimoneda ──────────────────────────────────────────────────────────
  final String currencyCode; // 'PEN', 'USD', 'EUR'
  final double exchangeRate; // Tipo de cambio congelado en la venta
  final double totalAmountBase; // Monto total en Soles (PEN)
  final double subtotalAmountBase; // Subtotal en Soles
  final double taxAmountBase; // Impuesto en Soles

  const OrderEntity({
    required this.id,
    this.customerId,
    this.totalAmount = 0.00,
    this.totalProfit = 0.00,
    this.paymentMethod = 'EFECTIVO',
    this.status = 'COMPLETED',
    this.createdAt,
    this.warehouseId,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.customerName = '',
    this.paymentStatus = 'PENDING',
    this.amountPaid = 0.00,
    this.dueDate,
    this.createdBy,
    this.updatedBy,
    this.updatedAt,
    this.discountAmount = 0.00,
    this.warehouseName,
    this.profileFullName,
    this.profilePhone,
    this.documentType = 'NINGUNO',
    this.documentSeries,
    this.documentNumber,
    this.documentDate,
    this.taxAmount = 0.00,
    this.subtotalAmount = 0.00,
    this.paymentReference,
    this.customerDocumentType,
    this.customerDocumentNumber,
    this.customerAddress,
    this.currencyCode = 'PEN',
    this.exchangeRate = 1.0,
    this.totalAmountBase = 0.00,
    this.subtotalAmountBase = 0.00,
    this.taxAmountBase = 0.00,
  });

  /// Símbolo de la moneda congelada al momento de registrar la venta
  String get currencySymbol {
    switch (currencyCode.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'PEN':
      default:
        return 'S/';
    }
  }

  String get displayCustomerName {
    if (profileFullName != null && profileFullName!.trim().isNotEmpty) {
      return profileFullName!;
    }
    if (customerName.trim().isNotEmpty) {
      return customerName;
    }
    return 'Cliente General';
  }

  /// Código o número de comprobante para mostrar en interfaz y tickets
  String get displayReceiptNumber {
    if (documentNumber != null && documentNumber!.trim().isNotEmpty) {
      return documentNumber!.trim();
    }
    final prefix =
        documentType == 'FACTURA'
            ? 'F'
            : (documentType == 'BOLETA'
                ? 'B'
                : (documentType == 'NOTA_VENTA' ? 'NV' : ''));
    final code =
        id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    return prefix.isNotEmpty ? '$prefix-$code' : '#$code';
  }

  @override
  List<Object?> get props => [
    id,
    customerId,
    totalAmount,
    totalProfit,
    paymentMethod,
    status,
    createdAt,
    warehouseId,
    pointsUsed,
    pointsEarned,
    customerName,
    paymentStatus,
    amountPaid,
    dueDate,
    createdBy,
    updatedBy,
    updatedAt,
    discountAmount,
    warehouseName,
    profileFullName,
    profilePhone,
    documentType,
    documentSeries,
    documentNumber,
    documentDate,
    taxAmount,
    subtotalAmount,
    paymentReference,
    customerDocumentType,
    customerDocumentNumber,
    customerAddress,
    currencyCode,
    exchangeRate,
    totalAmountBase,
    subtotalAmountBase,
    taxAmountBase,
  ];

  OrderEntity copyWith({
    String? id,
    String? customerId,
    double? totalAmount,
    double? totalProfit,
    String? paymentMethod,
    String? status,
    DateTime? createdAt,
    String? warehouseId,
    int? pointsUsed,
    int? pointsEarned,
    String? customerName,
    String? paymentStatus,
    double? amountPaid,
    DateTime? dueDate,
    String? createdBy,
    String? updatedBy,
    DateTime? updatedAt,
    double? discountAmount,
    String? warehouseName,
    String? profileFullName,
    String? profilePhone,
    String? documentType,
    String? documentSeries,
    String? documentNumber,
    DateTime? documentDate,
    double? taxAmount,
    double? subtotalAmount,
    String? paymentReference,
    String? customerDocumentType,
    String? customerDocumentNumber,
    String? customerAddress,
    String? currencyCode,
    double? exchangeRate,
    double? totalAmountBase,
    double? subtotalAmountBase,
    double? taxAmountBase,
  }) {
    return OrderEntity(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      totalAmount: totalAmount ?? this.totalAmount,
      totalProfit: totalProfit ?? this.totalProfit,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      warehouseId: warehouseId ?? this.warehouseId,
      pointsUsed: pointsUsed ?? this.pointsUsed,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      customerName: customerName ?? this.customerName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      amountPaid: amountPaid ?? this.amountPaid,
      dueDate: dueDate ?? this.dueDate,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      discountAmount: discountAmount ?? this.discountAmount,
      warehouseName: warehouseName ?? this.warehouseName,
      profileFullName: profileFullName ?? this.profileFullName,
      profilePhone: profilePhone ?? this.profilePhone,
      documentType: documentType ?? this.documentType,
      documentSeries: documentSeries ?? this.documentSeries,
      documentNumber: documentNumber ?? this.documentNumber,
      documentDate: documentDate ?? this.documentDate,
      taxAmount: taxAmount ?? this.taxAmount,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      paymentReference: paymentReference ?? this.paymentReference,
      customerDocumentType: customerDocumentType ?? this.customerDocumentType,
      customerDocumentNumber:
          customerDocumentNumber ?? this.customerDocumentNumber,
      customerAddress: customerAddress ?? this.customerAddress,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      totalAmountBase: totalAmountBase ?? this.totalAmountBase,
      subtotalAmountBase: subtotalAmountBase ?? this.subtotalAmountBase,
      taxAmountBase: taxAmountBase ?? this.taxAmountBase,
    );
  }
}
