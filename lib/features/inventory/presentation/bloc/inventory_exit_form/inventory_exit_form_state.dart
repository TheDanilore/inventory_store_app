import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';

class ExitItemUI {
  final ProductModel product;
  final ProductVariantModel variant;
  final Map<String, dynamic>? selectedBatch;
  double quantity;
  final double unitCost;

  ExitItemUI({
    required this.product,
    required this.variant,
    this.selectedBatch,
    required this.quantity,
    required this.unitCost,
  });

  double get totalCost => quantity * unitCost;

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'variant': variant.toJson(),
      'selectedBatch': selectedBatch,
      'quantity': quantity,
      'unit_cost': unitCost,
    };
  }

  factory ExitItemUI.fromJson(Map<String, dynamic> json) {
    return ExitItemUI(
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      variant: ProductVariantModel.fromJson(
        json['variant'] as Map<String, dynamic>,
      ),
      selectedBatch: json['selectedBatch'] as Map<String, dynamic>?,
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num).toDouble(),
    );
  }
}

class InventoryExitFormState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final String errorMessage;
  final bool isSuccess;

  final List<WarehouseModel> warehouses;
  final List<ProductModel> allProducts;
  final Map<String, List<ProductVariantModel>> variantsByProduct;

  final String? selectedWarehouseId;
  final String selectedReason;
  final List<ExitItemUI> items;

  const InventoryExitFormState({
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage = '',
    this.isSuccess = false,
    this.warehouses = const [],
    this.allProducts = const [],
    this.variantsByProduct = const {},
    this.selectedWarehouseId,
    this.selectedReason = 'AJUSTE',
    this.items = const [],
  });

  double get totalLossCost =>
      items.fold(0, (sum, item) => sum + item.totalCost);
  int get totalUnits =>
      items.fold(0, (sum, item) => sum + item.quantity.toInt());

  InventoryExitFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? isSuccess,
    List<WarehouseModel>? warehouses,
    List<ProductModel>? allProducts,
    Map<String, List<ProductVariantModel>>? variantsByProduct,
    String? selectedWarehouseId,
    String? selectedReason,
    List<ExitItemUI>? items,
  }) {
    return InventoryExitFormState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
      warehouses: warehouses ?? this.warehouses,
      allProducts: allProducts ?? this.allProducts,
      variantsByProduct: variantsByProduct ?? this.variantsByProduct,
      selectedWarehouseId: selectedWarehouseId ?? this.selectedWarehouseId,
      selectedReason: selectedReason ?? this.selectedReason,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSaving,
    errorMessage,
    isSuccess,
    warehouses,
    allProducts,
    variantsByProduct,
    selectedWarehouseId,
    selectedReason,
    items,
  ];
}
