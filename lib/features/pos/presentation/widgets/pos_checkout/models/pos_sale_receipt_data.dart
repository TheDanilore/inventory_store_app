/// Modelo inmutable que encapsula los metadatos de la venta completada
/// requeridos para comprobantes, resúmenes e impresiones.
class PosSaleReceiptData {
  final bool isDraft;
  final double totalAmount;
  final double? amountReceived;
  final String paymentMethod;
  final String customerName;
  final String documentType;
  final String? documentSeries;
  final String? paymentReference;
  final String currencyCode;
  final Map<String, int> soldQuantities;
  final String? accountId;

  const PosSaleReceiptData({
    required this.isDraft,
    required this.totalAmount,
    this.amountReceived,
    required this.paymentMethod,
    required this.customerName,
    required this.documentType,
    this.documentSeries,
    this.paymentReference,
    this.currencyCode = 'PEN',
    this.soldQuantities = const {},
    this.accountId,
  });

  String get currencySymbol => currencyCode == 'USD' ? '\$' : 'S/';

  PosSaleReceiptData copyWith({
    bool? isDraft,
    double? totalAmount,
    double? amountReceived,
    String? paymentMethod,
    String? customerName,
    String? documentType,
    String? documentSeries,
    String? paymentReference,
    String? currencyCode,
    Map<String, int>? soldQuantities,
    String? accountId,
  }) {
    return PosSaleReceiptData(
      isDraft: isDraft ?? this.isDraft,
      totalAmount: totalAmount ?? this.totalAmount,
      amountReceived: amountReceived ?? this.amountReceived,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      customerName: customerName ?? this.customerName,
      documentType: documentType ?? this.documentType,
      documentSeries: documentSeries ?? this.documentSeries,
      paymentReference: paymentReference ?? this.paymentReference,
      currencyCode: currencyCode ?? this.currencyCode,
      soldQuantities: soldQuantities ?? this.soldQuantities,
      accountId: accountId ?? this.accountId,
    );
  }
}
