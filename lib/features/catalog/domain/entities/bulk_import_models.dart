import 'package:equatable/equatable.dart';

/// Cómo se trata el stock de una variante que YA existe en el almacén destino.
enum ImportStockMode {
  /// Suma la cantidad del CSV al stock actual (entrada de inventario).
  add,

  /// Deja el stock exactamente en la cantidad del CSV (ajuste de inventario).
  replace,
}

enum ImportRowAction { createProduct, addVariant, updateVariant }

enum IssueSeverity { error, warning }

/// Normaliza texto para comparar: minúsculas, sin tildes, espacios colapsados.
String normalizeKey(String s) {
  const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
  const to = 'aaaaaeeeeiiiiooooouuuun';
  final b = StringBuffer();
  for (final ch in s.trim().toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

class ImportWarehouse extends Equatable {
  final String id;
  final String name;
  const ImportWarehouse({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

/// Variante ya registrada en la BD (devuelta por el repositorio).
class ExistingVariant extends Equatable {
  final String variantId;
  final String productId;
  final String productName;
  final String brandName; // '' si no tiene marca
  final String sku; // '' si no tiene
  final String variantName; // '' si es variante única
  final bool usesLots;

  /// Stock actual en el almacén seleccionado (suma de lotes si usa lotes).
  final int currentStock;

  const ExistingVariant({
    required this.variantId,
    required this.productId,
    required this.productName,
    this.brandName = '',
    this.sku = '',
    this.variantName = '',
    this.usesLots = false,
    this.currentStock = 0,
  });

  String get productKey =>
      '${normalizeKey(productName)}|${normalizeKey(brandName)}';

  @override
  List<Object?> get props => [variantId, productId, sku, currentStock];
}

/// Datos que la pantalla necesita antes de aceptar un archivo.
class ImportCatalogContext extends Equatable {
  final List<ImportWarehouse> warehouses;
  final List<String> brandNames;
  final List<String> categoryNames;

  const ImportCatalogContext({
    this.warehouses = const [],
    this.brandNames = const [],
    this.categoryNames = const [],
  });

  @override
  List<Object?> get props => [warehouses, brandNames, categoryNames];
}

class ImportIssue extends Equatable {
  final int line;
  final String column;
  final String message;
  final IssueSeverity severity;

  const ImportIssue(this.line, this.column, this.message, this.severity);

  @override
  List<Object?> get props => [line, column, message, severity];
}

/// Una fila del CSV = una variante (y opcionalmente un lote) de un producto.
class ImportRow {
  final int line;
  final String productName;
  final String brand;
  final String category;
  final String variantName;
  final String sku;
  final String description;
  final String imageUrl;
  final String components;
  final String lotCode;
  final String expiryRaw;
  final DateTime? expiry;
  final double? cost;
  final double? salePrice;
  final double? wholesalePrice;
  final int? wholesaleMinQty;
  final int? stock;
  final bool? usesLotsRaw;
  final List<ImportIssue> issues;

  ImportRowAction action = ImportRowAction.createProduct;
  ExistingVariant? existing;
  bool effectiveUsesLots = false;

  /// true si es un lote adicional de una variante que ya apareció antes en el
  /// archivo (misma variante, otro lote): no crea producto ni variante nuevos.
  bool isExtraLot = false;

  ImportRow({
    required this.line,
    required this.productName,
    required this.brand,
    required this.category,
    required this.variantName,
    required this.sku,
    required this.description,
    required this.imageUrl,
    required this.components,
    required this.lotCode,
    required this.expiryRaw,
    required this.expiry,
    required this.cost,
    required this.salePrice,
    required this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.stock,
    required this.usesLotsRaw,
    required this.issues,
  });

  bool get hasError => issues.any((i) => i.severity == IssueSeverity.error);
  bool get hasWarning =>
      !hasError && issues.any((i) => i.severity == IssueSeverity.warning);

  String get productKey =>
      '${normalizeKey(productName)}|${normalizeKey(brand)}';

  String get variantKey =>
      sku.isNotEmpty
          ? 'sku:${normalizeKey(sku)}'
          : 'v:$productKey|${normalizeKey(variantName)}';

  void error(String column, String msg) =>
      issues.add(ImportIssue(line, column, msg, IssueSeverity.error));

  void warn(String column, String msg) =>
      issues.add(ImportIssue(line, column, msg, IssueSeverity.warning));
}

class ImportSummary extends Equatable {
  final int totalRows;
  final int validRows;
  final int errorRows;
  final int warningRows;
  final int newProducts;
  final int newVariants;
  final int updatedVariants;
  final int units;

  /// Lotes de stock distintos que se cargarán (solo productos con lotes).
  final int lots;
  final int newBrands;
  final int newCategories;

  const ImportSummary({
    this.totalRows = 0,
    this.validRows = 0,
    this.errorRows = 0,
    this.warningRows = 0,
    this.newProducts = 0,
    this.newVariants = 0,
    this.updatedVariants = 0,
    this.units = 0,
    this.lots = 0,
    this.newBrands = 0,
    this.newCategories = 0,
  });

  @override
  List<Object?> get props => [
    totalRows,
    validRows,
    errorRows,
    warningRows,
    newProducts,
    newVariants,
    updatedVariants,
    units,
    lots,
    newBrands,
    newCategories,
  ];
}

/// Resultado devuelto por el servidor por cada lote.
class ImportBatchResult extends Equatable {
  final int createdProducts;
  final int createdVariants;
  final int updatedVariants;
  final int stockMovements;

  const ImportBatchResult({
    this.createdProducts = 0,
    this.createdVariants = 0,
    this.updatedVariants = 0,
    this.stockMovements = 0,
  });

  ImportBatchResult operator +(ImportBatchResult o) => ImportBatchResult(
    createdProducts: createdProducts + o.createdProducts,
    createdVariants: createdVariants + o.createdVariants,
    updatedVariants: updatedVariants + o.updatedVariants,
    stockMovements: stockMovements + o.stockMovements,
  );

  @override
  List<Object?> get props => [
    createdProducts,
    createdVariants,
    updatedVariants,
    stockMovements,
  ];
}
