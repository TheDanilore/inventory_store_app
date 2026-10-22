import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';

import 'package:inventory_store_app/features/pos/data/models/document_series_model.dart';

enum PosStatus { initial, loading, success, error }

class PosState extends Equatable {
  final bool isLoading;
  final String errorMessage;

  final String? selectedClientId;
  final String? selectedClientName;
  final int saldoActualCliente;
  final int puntosAUsar;
  final String paymentMethod;
  final String? selectedWarehouseId;

  final Map<String, List<BatchAssignmentModel>> batchOverrides;

  final List<WarehouseModel> warehouses;
  final List<Map<String, dynamic>> accounts;
  final List<DocumentSeriesModel> documentSeries;

  final PosStatus status;
  final CashShiftEntity? activeShift;
  final List<Map<String, dynamic>> clientMatches;
  final String? lastOrderId;
  final Map<String, dynamic>? creditInfo;
  final String? selectedAccountId;

  // ── Dimensiones Fiscales y Facturación ─────────────────────────────────────
  final String documentType; // 'NOTA_VENTA', 'BOLETA', 'FACTURA'
  final String? selectedSeries; // 'NV01', 'B001', 'F001'
  final String? paymentReference; // Nº Op / Ref (Yape, Plin, Tarjeta)
  final String? customerDocumentType; // 'DNI', 'RUC'
  final String? customerDocumentNumber; // '10723456789'
  final String? customerAddress; // Dirección fiscal para Facturas

  final List<OrderModel> recentOrders;
  final bool isLoadingRecentOrders;
  final bool isLoadingMoreOrders;
  final bool hasMoreOrders;
  final String recentOrdersError;
  final double dailyTotalAmount;
  final int dailyTotalCount;
  final bool isLoadingDailySummary;
  final String salesSearchQuery;

  final String discountText;
  final bool isDiscountPercentage;

  // ── Multimoneda ──────────────────────────────────────────────────────────
  final String currencyCode;
  final double exchangeRate;

  const PosState({
    this.isLoading = false,
    this.errorMessage = '',
    this.selectedClientId,
    this.selectedClientName,
    this.saldoActualCliente = 0,
    this.puntosAUsar = 0,
    this.paymentMethod = 'EFECTIVO',
    this.selectedWarehouseId,
    this.batchOverrides = const {},
    this.warehouses = const [],
    this.accounts = const [],
    this.documentSeries = const [],
    this.status = PosStatus.initial,
    this.activeShift,
    this.clientMatches = const [],
    this.lastOrderId,
    this.creditInfo,
    this.selectedAccountId,
    this.documentType = 'NOTA_VENTA',
    this.selectedSeries,
    this.paymentReference,
    this.customerDocumentType,
    this.customerDocumentNumber,
    this.customerAddress,
    this.recentOrders = const [],
    this.isLoadingRecentOrders = false,
    this.isLoadingMoreOrders = false,
    this.hasMoreOrders = true,
    this.recentOrdersError = '',
    this.dailyTotalAmount = 0.0,
    this.dailyTotalCount = 0,
    this.isLoadingDailySummary = false,
    this.salesSearchQuery = '',
    this.discountText = '',
    this.isDiscountPercentage = false,
    this.currencyCode = 'PEN',
    this.exchangeRate = 1.0,
  });

  PosState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? selectedClientId,
    String? selectedClientName,
    int? saldoActualCliente,
    int? puntosAUsar,
    String? paymentMethod,
    String? selectedWarehouseId,
    Map<String, List<BatchAssignmentModel>>? batchOverrides,
    List<WarehouseModel>? warehouses,
    List<Map<String, dynamic>>? accounts,
    List<DocumentSeriesModel>? documentSeries,
    PosStatus? status,
    CashShiftEntity? activeShift,
    List<Map<String, dynamic>>? clientMatches,
    String? lastOrderId,
    Map<String, dynamic>? creditInfo,
    String? selectedAccountId,
    String? documentType,
    String? selectedSeries,
    String? paymentReference,
    String? customerDocumentType,
    String? customerDocumentNumber,
    String? customerAddress,
    List<OrderModel>? recentOrders,
    bool? isLoadingRecentOrders,
    bool? isLoadingMoreOrders,
    bool? hasMoreOrders,
    String? recentOrdersError,
    double? dailyTotalAmount,
    int? dailyTotalCount,
    bool? isLoadingDailySummary,
    String? salesSearchQuery,
    String? discountText,
    bool? isDiscountPercentage,
    String? currencyCode,
    double? exchangeRate,
    bool clearClient = false,
    bool clearActiveShift = false,
  }) {
    return PosState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedClientId:
          clearClient ? null : (selectedClientId ?? this.selectedClientId),
      selectedClientName:
          clearClient ? null : (selectedClientName ?? this.selectedClientName),
      saldoActualCliente:
          clearClient ? 0 : (saldoActualCliente ?? this.saldoActualCliente),
      puntosAUsar: clearClient ? 0 : (puntosAUsar ?? this.puntosAUsar),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      batchOverrides: batchOverrides ?? this.batchOverrides,
      warehouses: warehouses ?? this.warehouses,
      accounts: accounts ?? this.accounts,
      documentSeries: documentSeries ?? this.documentSeries,
      status: status ?? this.status,
      activeShift: clearActiveShift ? null : (activeShift ?? this.activeShift),
      clientMatches: clientMatches ?? this.clientMatches,
      lastOrderId: lastOrderId ?? this.lastOrderId,
      creditInfo: clearClient ? null : (creditInfo ?? this.creditInfo),
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      documentType: documentType ?? this.documentType,
      selectedSeries: selectedSeries ?? this.selectedSeries,
      paymentReference: paymentReference ?? this.paymentReference,
      customerDocumentType:
          clearClient
              ? null
              : (customerDocumentType ?? this.customerDocumentType),
      customerDocumentNumber:
          clearClient
              ? null
              : (customerDocumentNumber ?? this.customerDocumentNumber),
      customerAddress:
          clearClient ? null : (customerAddress ?? this.customerAddress),
      recentOrders: recentOrders ?? this.recentOrders,
      isLoadingRecentOrders:
          isLoadingRecentOrders ?? this.isLoadingRecentOrders,
      isLoadingMoreOrders: isLoadingMoreOrders ?? this.isLoadingMoreOrders,
      hasMoreOrders: hasMoreOrders ?? this.hasMoreOrders,
      recentOrdersError: recentOrdersError ?? this.recentOrdersError,
      dailyTotalAmount: dailyTotalAmount ?? this.dailyTotalAmount,
      dailyTotalCount: dailyTotalCount ?? this.dailyTotalCount,
      isLoadingDailySummary:
          isLoadingDailySummary ?? this.isLoadingDailySummary,
      salesSearchQuery: salesSearchQuery ?? this.salesSearchQuery,
      discountText: discountText ?? this.discountText,
      isDiscountPercentage: isDiscountPercentage ?? this.isDiscountPercentage,
      currencyCode: currencyCode ?? this.currencyCode,
      exchangeRate: exchangeRate ?? this.exchangeRate,
    );
  }

  /// Lista de series activas compatibles con el tipo de comprobante seleccionado
  List<DocumentSeriesModel> get activeSeriesList =>
      documentSeries
          .where((s) => s.documentType == documentType && s.isActive)
          .toList();

  /// Serie efectiva a usar: la elegida explícitamente o la predeterminada del tipo
  String get effectiveSeries {
    if (selectedSeries != null && selectedSeries!.isNotEmpty) {
      return selectedSeries!;
    }
    final matching = activeSeriesList;
    if (matching.isNotEmpty) {
      final def = matching.firstWhere(
        (s) => s.isDefault,
        orElse: () => matching.first,
      );
      return def.series;
    }
    return documentType == 'FACTURA'
        ? 'F001'
        : (documentType == 'BOLETA' ? 'B001' : 'NV01');
  }

  @override
  List<Object?> get props => [
    isLoading,
    errorMessage,
    selectedClientId,
    selectedClientName,
    saldoActualCliente,
    puntosAUsar,
    paymentMethod,
    selectedWarehouseId,
    batchOverrides,
    warehouses,
    accounts,
    documentSeries,
    status,
    activeShift,
    clientMatches,
    lastOrderId,
    creditInfo,
    selectedAccountId,
    documentType,
    selectedSeries,
    paymentReference,
    customerDocumentType,
    customerDocumentNumber,
    customerAddress,
    recentOrders,
    isLoadingRecentOrders,
    isLoadingMoreOrders,
    hasMoreOrders,
    recentOrdersError,
    dailyTotalAmount,
    dailyTotalCount,
    isLoadingDailySummary,
    salesSearchQuery,
    discountText,
    isDiscountPercentage,
    currencyCode,
    exchangeRate,
  ];
}
