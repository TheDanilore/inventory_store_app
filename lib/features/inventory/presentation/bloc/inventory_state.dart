import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

abstract class InventoryState extends Equatable {
  const InventoryState();

  @override
  List<Object?> get props => [];
}

class InventoryInitial extends InventoryState {
  const InventoryInitial();
}

class InventoryLoading extends InventoryState {
  const InventoryLoading();
}

class InventoryLoaded extends InventoryState {
  final List<InventoryStockItem> stockItems;
  final List<InventoryBatchItem> batchItems;

  final int currentStockPage;
  final int totalStockPages;
  final String stockSearchText;
  final String stockCategoryFilter;
  final List<String> categories;

  final int globalTotalVariants;
  final int globalTotalStock;
  final int globalLowStockCount;
  final double globalTotalCost;

  final int currentBatchPage;
  final int totalBatchPages;
  final String batchSearchText;
  final String batchStatusFilter;

  final int countVencido;
  final int countCritico;
  final int countProximo;
  final int countNormal;

  const InventoryLoaded({
    required this.stockItems,
    required this.batchItems,
    required this.currentStockPage,
    required this.totalStockPages,
    required this.stockSearchText,
    required this.stockCategoryFilter,
    required this.categories,
    required this.globalTotalVariants,
    required this.globalTotalStock,
    required this.globalLowStockCount,
    required this.globalTotalCost,
    required this.currentBatchPage,
    required this.totalBatchPages,
    required this.batchSearchText,
    required this.batchStatusFilter,
    required this.countVencido,
    required this.countCritico,
    required this.countProximo,
    required this.countNormal,
  });

  InventoryLoaded copyWith({
    List<InventoryStockItem>? stockItems,
    List<InventoryBatchItem>? batchItems,
    int? currentStockPage,
    int? totalStockPages,
    String? stockSearchText,
    String? stockCategoryFilter,
    List<String>? categories,
    int? globalTotalVariants,
    int? globalTotalStock,
    int? globalLowStockCount,
    double? globalTotalCost,
    int? currentBatchPage,
    int? totalBatchPages,
    String? batchSearchText,
    String? batchStatusFilter,
    int? countVencido,
    int? countCritico,
    int? countProximo,
    int? countNormal,
  }) {
    return InventoryLoaded(
      stockItems: stockItems ?? this.stockItems,
      batchItems: batchItems ?? this.batchItems,
      currentStockPage: currentStockPage ?? this.currentStockPage,
      totalStockPages: totalStockPages ?? this.totalStockPages,
      stockSearchText: stockSearchText ?? this.stockSearchText,
      stockCategoryFilter: stockCategoryFilter ?? this.stockCategoryFilter,
      categories: categories ?? this.categories,
      globalTotalVariants: globalTotalVariants ?? this.globalTotalVariants,
      globalTotalStock: globalTotalStock ?? this.globalTotalStock,
      globalLowStockCount: globalLowStockCount ?? this.globalLowStockCount,
      globalTotalCost: globalTotalCost ?? this.globalTotalCost,
      currentBatchPage: currentBatchPage ?? this.currentBatchPage,
      totalBatchPages: totalBatchPages ?? this.totalBatchPages,
      batchSearchText: batchSearchText ?? this.batchSearchText,
      batchStatusFilter: batchStatusFilter ?? this.batchStatusFilter,
      countVencido: countVencido ?? this.countVencido,
      countCritico: countCritico ?? this.countCritico,
      countProximo: countProximo ?? this.countProximo,
      countNormal: countNormal ?? this.countNormal,
    );
  }

  @override
  List<Object?> get props => [
    stockItems,
    batchItems,
    currentStockPage,
    totalStockPages,
    stockSearchText,
    stockCategoryFilter,
    categories,
    globalTotalVariants,
    globalTotalStock,
    globalLowStockCount,
    globalTotalCost,
    currentBatchPage,
    totalBatchPages,
    batchSearchText,
    batchStatusFilter,
    countVencido,
    countCritico,
    countProximo,
    countNormal,
  ];
}

class InventoryError extends InventoryState {
  final String message;
  const InventoryError(this.message);

  @override
  List<Object?> get props => [message];
}
