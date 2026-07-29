import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

abstract class PurchaseOrderFormState extends Equatable {
  const PurchaseOrderFormState();

  @override
  List<Object?> get props => [];
}

class PurchaseOrderFormInitial extends PurchaseOrderFormState {}

class PurchaseOrderFormLoading extends PurchaseOrderFormState {
  final String message;

  const PurchaseOrderFormLoading({this.message = 'Cargando datos...'});

  @override
  List<Object?> get props => [message];
}

class PurchaseOrderFormLoaded extends PurchaseOrderFormState {
  // Catalogs
  final List<Map<String, dynamic>> suppliers;
  final List<WarehouseModel> warehouses;
  final List<FinancialAccountModel> accounts;
  final Map<String, String> activeShiftsByAccount;
  final Map<String, Map<String, dynamic>> supplierCreditsBySupplierId;

  // Form Data
  final List<InventoryEntryItemEntity> items;
  final String? selectedSupplierId;
  final String? selectedWarehouseId;
  final DateTime? dueDate;
  final DateTime? documentDate;
  final String documentType;
  final String paymentMode;
  final String paymentStatus;
  final String? selectedAccountId;
  final String documentNumber;
  final String notes;

  // Helpers
  final bool isSaving;
  final String? errorMessage;
  final bool isDraftRestored;

  const PurchaseOrderFormLoaded({
    required this.suppliers,
    required this.warehouses,
    required this.accounts,
    this.activeShiftsByAccount = const {},
    this.supplierCreditsBySupplierId = const {},
    this.items = const [],
    this.selectedSupplierId,
    this.selectedWarehouseId,
    this.dueDate,
    this.documentDate,
    this.documentType = 'NINGUNO',
    this.paymentMode = 'EFECTIVO',
    this.paymentStatus = 'PENDING',
    this.selectedAccountId,
    this.documentNumber = '',
    this.notes = '',
    this.isSaving = false,
    this.errorMessage,
    this.isDraftRestored = false,
  });

  double get totalAmount {
    return items.fold(
      0.0,
      (sum, item) => sum + (item.unitCost * item.quantity),
    );
  }

  String? get creditWarningMessage {
    if (selectedSupplierId == null) return null;
    if (paymentMode == 'CRÉDITO' || paymentStatus == 'PENDING') {
      final creditData = supplierCreditsBySupplierId[selectedSupplierId];
      if (paymentMode == 'CRÉDITO' && creditData == null) {
        return 'El proveedor seleccionado no tiene una línea de crédito registrada en el sistema.';
      }
      if (creditData != null) {
        final isActive = creditData['is_active'] as bool? ?? true;
        if (!isActive && paymentMode == 'CRÉDITO') {
          return 'La línea de crédito con este proveedor se encuentra inactiva.';
        }
        final creditLimit =
            (creditData['credit_limit'] as num?)?.toDouble() ?? 0.0;
        final currentDebt =
            (creditData['current_debt'] as num?)?.toDouble() ?? 0.0;

        if (paymentMode == 'CRÉDITO' && creditLimit <= 0) {
          return 'El proveedor tiene un límite de crédito de S/ 0.00. Configura un límite en Créditos Proveedores para pedir a crédito.';
        }

        if (creditLimit > 0 && (currentDebt + totalAmount) > creditLimit) {
          final available = (creditLimit - currentDebt).clamp(
            0.0,
            double.infinity,
          );
          return 'Límite de crédito excedido. Crédito disponible: S/ ${available.toStringAsFixed(2)} | Requerido con esta orden: S/ ${totalAmount.toStringAsFixed(2)}.';
        }
      }
    }
    return null;
  }

  bool get isCreditExceeded => creditWarningMessage != null;

  bool get isValid {
    if (selectedSupplierId == null) return false;
    if (selectedWarehouseId == null) return false;
    if (items.isEmpty) return false;
    for (final item in items) {
      if (item.quantity <= 0 || item.unitCost <= 0) return false;
    }
    if (paymentStatus == 'PAID' && selectedAccountId == null) return false;
    if (isCreditExceeded) return false;
    return true;
  }

  PurchaseOrderFormLoaded copyWith({
    List<Map<String, dynamic>>? suppliers,
    List<WarehouseModel>? warehouses,
    List<FinancialAccountModel>? accounts,
    Map<String, String>? activeShiftsByAccount,
    Map<String, Map<String, dynamic>>? supplierCreditsBySupplierId,
    List<InventoryEntryItemEntity>? items,
    String? selectedSupplierId,
    String? selectedWarehouseId,
    DateTime? dueDate,
    DateTime? documentDate,
    String? documentType,
    String? paymentMode,
    String? paymentStatus,
    String? selectedAccountId,
    String? documentNumber,
    String? notes,
    bool? isSaving,
    String? errorMessage,
    bool? isDraftRestored,
  }) {
    return PurchaseOrderFormLoaded(
      suppliers: suppliers ?? this.suppliers,
      warehouses: warehouses ?? this.warehouses,
      accounts: accounts ?? this.accounts,
      activeShiftsByAccount:
          activeShiftsByAccount ?? this.activeShiftsByAccount,
      supplierCreditsBySupplierId:
          supplierCreditsBySupplierId ?? this.supplierCreditsBySupplierId,
      items: items ?? this.items,
      selectedSupplierId: selectedSupplierId ?? this.selectedSupplierId,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      dueDate: dueDate ?? this.dueDate,
      documentDate: documentDate ?? this.documentDate,
      documentType: documentType ?? this.documentType,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      selectedAccountId: selectedAccountId ?? this.selectedAccountId,
      documentNumber: documentNumber ?? this.documentNumber,
      notes: notes ?? this.notes,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      isDraftRestored: isDraftRestored ?? this.isDraftRestored,
    );
  }

  PurchaseOrderFormLoaded clearError() {
    return PurchaseOrderFormLoaded(
      suppliers: suppliers,
      warehouses: warehouses,
      accounts: accounts,
      activeShiftsByAccount: activeShiftsByAccount,
      supplierCreditsBySupplierId: supplierCreditsBySupplierId,
      items: items,
      selectedSupplierId: selectedSupplierId,
      selectedWarehouseId: selectedWarehouseId,
      dueDate: dueDate,
      documentDate: documentDate,
      documentType: documentType,
      paymentMode: paymentMode,
      paymentStatus: paymentStatus,
      selectedAccountId: selectedAccountId,
      documentNumber: documentNumber,
      notes: notes,
      isSaving: isSaving,
      errorMessage: null,
      isDraftRestored: isDraftRestored,
    );
  }

  @override
  List<Object?> get props => [
    suppliers,
    warehouses,
    accounts,
    activeShiftsByAccount,
    supplierCreditsBySupplierId,
    items,
    selectedSupplierId,
    selectedWarehouseId,
    dueDate,
    documentDate,
    documentType,
    paymentMode,
    paymentStatus,
    selectedAccountId,
    documentNumber,
    notes,
    isSaving,
    errorMessage,
    isDraftRestored,
  ];
}

class PurchaseOrderFormSuccess extends PurchaseOrderFormState {}
