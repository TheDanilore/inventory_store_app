import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

class InventoryEntryFormState extends Equatable {
  final List<WarehouseModel> warehouses;
  final List<Map<String, dynamic>> suppliers;
  final List<FinancialAccountModel> accounts;

  final String? selectedWarehouseId;
  final String? selectedSupplierId;
  final String documentType;
  final String? documentNumber;
  final DateTime? documentDate;
  final String paymentMode;
  final String? selectedAccountId;
  final String? purchaseOrderId;
  final String? activeShiftId;

  final List<InventoryEntryItemEntity> items;

  final bool isLoading;
  final bool isSaving;
  final String errorMessage;
  final bool isSuccess;

  const InventoryEntryFormState({
    this.warehouses = const [],
    this.suppliers = const [],
    this.accounts = const [],
    this.selectedWarehouseId,
    this.selectedSupplierId,
    this.documentType = 'NINGUNO',
    this.documentNumber,
    this.documentDate,
    this.paymentMode = 'CONTADO',
    this.selectedAccountId,
    this.purchaseOrderId,
    this.activeShiftId,
    this.items = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage = '',
    this.isSuccess = false,
  });

  InventoryEntryFormState copyWith({
    List<WarehouseModel>? warehouses,
    List<Map<String, dynamic>>? suppliers,
    List<FinancialAccountModel>? accounts,
    String? selectedWarehouseId,
    String? selectedSupplierId,
    String? documentType,
    String? documentNumber,
    DateTime? documentDate,
    String? paymentMode,
    String? selectedAccountId,
    String? purchaseOrderId,
    String? activeShiftId,
    List<InventoryEntryItemEntity>? items,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? isSuccess,
    bool clearDocumentNumber = false,
    bool clearDocumentDate = false,
    bool clearSelectedSupplierId = false,
    bool clearSelectedAccountId = false,
  }) {
    return InventoryEntryFormState(
      warehouses: warehouses ?? this.warehouses,
      suppliers: suppliers ?? this.suppliers,
      accounts: accounts ?? this.accounts,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      selectedSupplierId:
          clearSelectedSupplierId
              ? null
              : (selectedSupplierId ?? this.selectedSupplierId),
      documentType: documentType ?? this.documentType,
      documentNumber:
          clearDocumentNumber ? null : (documentNumber ?? this.documentNumber),
      documentDate:
          clearDocumentDate ? null : (documentDate ?? this.documentDate),
      paymentMode: paymentMode ?? this.paymentMode,
      selectedAccountId:
          clearSelectedAccountId
              ? null
              : (selectedAccountId ?? this.selectedAccountId),
      purchaseOrderId: purchaseOrderId ?? this.purchaseOrderId,
      activeShiftId: activeShiftId ?? this.activeShiftId,
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  List<Object?> get props => [
    warehouses,
    suppliers,
    accounts,
    selectedWarehouseId,
    selectedSupplierId,
    documentType,
    documentNumber,
    documentDate,
    paymentMode,
    selectedAccountId,
    purchaseOrderId,
    activeShiftId,
    items,
    isLoading,
    isSaving,
    errorMessage,
    isSuccess,
  ];
}
