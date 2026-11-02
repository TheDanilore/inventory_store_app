import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';

/// Columnas canónicas y sus alias aceptados (ya normalizados, con "_").
const Map<String, List<String>> kImportColumnAliases = {
  'nombre': ['nombre', 'producto', 'nombre_producto'],
  'marca': ['marca', 'laboratorio', 'marca_laboratorio', 'laboratorio_marca'],
  'categoria': ['categoria'],
  'variante': ['variante', 'presentacion'],
  'sku': ['sku', 'codigo'],
  'precio_compra': ['precio_compra', 'costo', 'precio_costo', 'costo_compra'],
  'precio_venta': ['precio_venta', 'venta', 'pvp'],
  'precio_mayor': [
    'precio_mayor',
    'precio_mayorista',
    'precio_por_mayor',
    'mayorista',
  ],
  'cantidad_mayor': ['cantidad_mayor', 'cantidad_minima_mayor', 'min_mayor'],
  'stock': ['stock', 'stock_inicial', 'cantidad'],
  'usa_lotes': ['usa_lotes', 'lotes', 'maneja_lotes', 'tiene_lotes'],
  'lote': ['lote', 'nro_lote', 'codigo_lote'],
  'vencimiento': ['vencimiento', 'fecha_vencimiento', 'vence'],
  'componentes': [
    'componentes',
    'principio_activo',
    'componentes_quimicos',
    'composicion',
  ],
  'descripcion': ['descripcion'],
  'imagen_url': ['imagen_url', 'imagen', 'foto'],
};

const List<String> kRequiredColumns = [
  'nombre',
  'precio_compra',
  'precio_venta',
];

/// Servicio de dominio y validación para el motor de importación masiva.
/// Desacopla la lógica de negocio, reglas de consistencia de lotes y construcción de payloads.
class BulkImportValidationService {
  /// Mapea los encabezados de la tabla a las columnas canónicas
  static Map<String, int> mapHeaders(List<String> firstRow) {
    final colIndex = <String, int>{};
    for (var j = 0; j < firstRow.length; j++) {
      final h = normalizeKey(firstRow[j]).replaceAll(' ', '_');
      for (final e in kImportColumnAliases.entries) {
        if (e.value.contains(h) && !colIndex.containsKey(e.key)) {
          colIndex[e.key] = j;
        }
      }
    }
    return colIndex;
  }

  /// Verifica si faltan columnas obligatorias
  static List<String> checkMissingRequiredColumns(Map<String, int> colIndex) {
    return [
      for (final req in kRequiredColumns)
        if (!colIndex.containsKey(req)) 'Falta la columna obligatoria "$req".',
    ];
  }

  /// Parsea y valida individualmente cada fila del archivo
  static ImportRow parseRow(int line, String Function(String) g) {
    final issues = <ImportIssue>[];
    void err(String c, String m) =>
        issues.add(ImportIssue(line, c, m, IssueSeverity.error));
    void warn(String c, String m) =>
        issues.add(ImportIssue(line, c, m, IssueSeverity.warning));

    final name = g('nombre');
    if (name.isEmpty) err('nombre', 'El nombre del producto es obligatorio.');

    double? money(String col, {required bool required}) {
      final raw = g(col);
      if (raw.isEmpty) {
        if (required) err(col, 'Es obligatorio.');
        return null;
      }
      final v = parseNum(raw);
      if (v == null) {
        err(col, 'Valor numérico inválido ("$raw").');
        return null;
      }
      if (v < 0) {
        err(col, 'No puede ser negativo.');
        return null;
      }
      return v;
    }

    final cost = money('precio_compra', required: true);
    final sale = money('precio_venta', required: true);
    final wholesale = money('precio_mayor', required: false);

    if (cost != null && sale != null && sale < cost) {
      warn('precio_venta', 'El precio de venta es menor al costo.');
    }
    if (wholesale != null && sale != null && wholesale > sale) {
      warn('precio_mayor', 'El precio por mayor supera al precio de venta.');
    }
    if (wholesale != null && cost != null && wholesale < cost) {
      warn('precio_mayor', 'El precio por mayor es menor al costo.');
    }

    int? minQty;
    final minQtyRaw = g('cantidad_mayor');
    if (minQtyRaw.isNotEmpty) {
      final v = parseNum(minQtyRaw);
      if (v == null || v < 1 || v != v.roundToDouble()) {
        err('cantidad_mayor', 'Debe ser un entero mayor o igual a 1.');
      } else {
        minQty = v.round();
        if (wholesale == null) {
          warn('cantidad_mayor', 'Se ignora: no hay precio por mayor.');
        }
      }
    } else if (wholesale != null) {
      warn(
        'cantidad_mayor',
        'Hay precio por mayor sin cantidad mínima; se guardará sin mínimo.',
      );
    }

    int? stock;
    final stockRaw = g('stock');
    if (stockRaw.isNotEmpty) {
      final v = parseNum(stockRaw);
      if (v == null) {
        err('stock', 'Cantidad inválida ("$stockRaw").');
      } else if (v < 0) {
        err('stock', 'La cantidad no puede ser negativa.');
      } else if (v != v.roundToDouble()) {
        err('stock', 'La cantidad debe ser un número entero.');
      } else {
        stock = v.round();
      }
    }

    bool? usesLots;
    final lotsRaw = normalizeKey(g('usa_lotes'));
    if (lotsRaw.isNotEmpty) {
      if (const ['si', 's', '1', 'true', 'yes', 'y'].contains(lotsRaw)) {
        usesLots = true;
      } else if (const ['no', 'n', '0', 'false'].contains(lotsRaw)) {
        usesLots = false;
      } else {
        err('usa_lotes', 'Use "si" o "no" (recibido "${g('usa_lotes')}").');
      }
    }

    final lot = g('lote');
    final expiryRaw = g('vencimiento');
    DateTime? expiry;
    if (expiryRaw.isNotEmpty) {
      expiry = parseDate(expiryRaw);
      if (expiry == null) {
        err('vencimiento', 'Fecha inválida. Use AAAA-MM-DD o DD/MM/AAAA.');
      } else {
        final today = DateTime.now();
        if (expiry.isBefore(DateTime(today.year, today.month, today.day))) {
          warn('vencimiento', 'La fecha de vencimiento ya pasó.');
        }
      }
    }
    // Si trae lote/vencimiento pero no dice usa_lotes → se infiere que sí.
    usesLots ??= (lot.isNotEmpty || expiryRaw.isNotEmpty) ? true : null;

    return ImportRow(
      line: line,
      productName: name,
      brand: g('marca'),
      category: g('categoria'),
      variantName: g('variante'),
      sku: g('sku'),
      description: g('descripcion'),
      imageUrl: g('imagen_url'),
      components: g('componentes'),
      lotCode: lot,
      expiryRaw: expiryRaw,
      expiry: expiry,
      cost: cost,
      salePrice: sale,
      wholesalePrice: wholesale,
      wholesaleMinQty: minQty,
      stock: stock,
      usesLotsRaw: usesLots,
      issues: issues,
    );
  }

  /// Limpia y convierte texto a número (soporta formatos con coma y punto)
  static double? parseNum(String raw) {
    var s = raw.replaceAll(RegExp(r'[^\d,.\-]'), '');
    if (s.contains(',') && s.contains('.')) {
      s = s.replaceAll(',', ''); // 1,234.50
    } else if (s.contains(',')) {
      s = s.replaceAll(',', '.'); // 10,50
    }
    return double.tryParse(s);
  }

  /// Parsea formatos de fecha AAAA-MM-DD o DD/MM/AAAA
  static DateTime? parseDate(String s) {
    DateTime? mk(int y, int m, int d) {
      if (m < 1 || m > 12 || d < 1 || d > 31) return null;
      final dt = DateTime(y, m, d);
      return dt.month == m ? dt : null;
    }

    var m = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(s);
    if (m != null) {
      return mk(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    m = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$').firstMatch(s);
    if (m != null) {
      return mk(
        int.parse(m.group(3)!),
        int.parse(m.group(2)!),
        int.parse(m.group(1)!),
      );
    }
    return null;
  }

  /// Clasifica filas contra las variantes existentes en la BD
  static void classify({
    required List<ImportRow> rows,
    required List<ExistingVariant> existing,
    required String? selectedWarehouseId,
  }) {
    final bySku = <String, ExistingVariant>{
      for (final e in existing)
        if (e.sku.isNotEmpty) normalizeKey(e.sku): e,
    };
    final byProductVariant = <String, ExistingVariant>{
      for (final e in existing)
        '${e.productKey}|${normalizeKey(e.variantName)}': e,
    };
    final existingProducts = <String, ExistingVariant>{
      for (final e in existing) e.productKey: e,
    };

    // Consistencia a nivel de producto (usa_lotes / categoría / componentes)
    final byProduct = <String, List<ImportRow>>{};
    for (final r in rows) {
      byProduct.putIfAbsent(r.productKey, () => []).add(r);
    }
    final productLots = <String, bool>{};
    byProduct.forEach((key, list) {
      final set = list.map((r) => r.usesLotsRaw).whereType<bool>().toSet();
      if (set.length > 1) {
        for (final r in list) {
          r.error(
            'usa_lotes',
            'Las filas de este producto mezclan "si" y "no" en usa_lotes.',
          );
        }
      }
      productLots[key] = set.contains(true);

      String? cat;
      String? comp;
      for (final r in list) {
        if (r.category.isNotEmpty) {
          cat ??= r.category;
          if (normalizeKey(cat) != normalizeKey(r.category)) {
            r.warn(
              'categoria',
              'Categoría distinta dentro del mismo producto; se usará "$cat".',
            );
          }
        }
        if (r.components.isNotEmpty) {
          comp ??= r.components;
          if (normalizeKey(comp) != normalizeKey(r.components)) {
            r.warn(
              'componentes',
              'Componentes distintos dentro del mismo producto; se usarán los de la primera fila.',
            );
          }
        }
      }
    });

    final seen = <String, int>{}; // variantKey|lote → línea
    final seenVariants = <String>{}; // variantes ya vistas en el archivo
    final skuOwner = <String, String>{}; // sku → productKey

    for (final r in rows) {
      if (r.productName.isEmpty) continue;

      // Producto/variante existente
      ExistingVariant? ex;
      if (r.sku.isNotEmpty) {
        ex = bySku[normalizeKey(r.sku)];
        if (ex != null && ex.productKey != r.productKey) {
          r.error(
            'sku',
            'El SKU ya pertenece a otro producto: "${ex.productName}"${ex.brandName.isEmpty ? '' : ' (${ex.brandName})'}.',
          );
          ex = null;
        } else if (ex == null) {
          final sameName =
              byProductVariant['${r.productKey}|${normalizeKey(r.variantName)}'];
          if (sameName != null) {
            r.error(
              'sku',
              'Esa variante ya existe con otro SKU (${sameName.sku.isEmpty ? 'sin SKU' : sameName.sku}). Usa ese SKU o cambia la variante.',
            );
          }
        }
        // SKU repetido en el archivo con productos distintos
        final owner = skuOwner[normalizeKey(r.sku)];
        if (owner != null && owner != r.productKey) {
          r.error('sku', 'El SKU se repite en otro producto del archivo.');
        } else {
          skuOwner[normalizeKey(r.sku)] = r.productKey;
        }
      } else {
        ex = byProductVariant['${r.productKey}|${normalizeKey(r.variantName)}'];
      }

      r.existing = ex;
      if (ex != null) {
        r.action = ImportRowAction.updateVariant;
      } else if (existingProducts.containsKey(r.productKey)) {
        r.action = ImportRowAction.addVariant;
      } else {
        r.action = ImportRowAction.createProduct;
      }

      // Lotes efectivos
      final lots =
          existingProducts[r.productKey]?.usesLots ??
          productLots[r.productKey] ??
          false;
      r.effectiveUsesLots = lots;
      final qty = r.stock ?? 0;
      if (lots) {
        if (qty > 0) {
          if (r.lotCode.isEmpty) {
            r.error('lote', 'El producto usa lotes: indica el código de lote.');
          }
          if (r.expiryRaw.isEmpty) {
            r.error(
              'vencimiento',
              'El producto usa lotes: indica el vencimiento.',
            );
          }
        }
      } else if (r.lotCode.isNotEmpty || r.expiryRaw.isNotEmpty) {
        r.warn(
          'lote',
          'El producto no maneja lotes; se ignorarán lote y vencimiento.',
        );
      }

      // Stock sin almacén
      if (qty > 0 && selectedWarehouseId == null) {
        r.error(
          'stock',
          'No hay almacén creado para cargar stock. Crea uno primero.',
        );
      }

      // Misma variante con otro lote → no es una variante/producto nuevo
      r.isExtraLot = !seenVariants.add(r.variantKey) && lots;

      // Duplicados dentro del archivo
      final dupKey = '${r.variantKey}|${lots ? normalizeKey(r.lotCode) : ''}';
      final first = seen[dupKey];
      if (first != null) {
        r.error(
          'nombre',
          'Duplicado de la fila $first${lots ? ' (mismo lote)' : ''}. Cada variante${lots ? '/lote' : ''} debe aparecer una sola vez.',
        );
      } else {
        seen[dupKey] = r.line;
      }
    }
  }

  /// Calcula el resumen cuantitativo de la importación
  static ImportSummary summarize({
    required List<ImportRow> rows,
    required List<String> brandNames,
    required List<String> categoryNames,
  }) {
    final valid = rows.where((r) => !r.hasError).toList();
    final brands = {for (final b in brandNames) normalizeKey(b)};
    final cats = {for (final c in categoryNames) normalizeKey(c)};
    final newBrands = <String>{};
    final newCats = <String>{};
    for (final r in valid.where(
      (r) => r.action == ImportRowAction.createProduct,
    )) {
      if (r.brand.isNotEmpty && !brands.contains(normalizeKey(r.brand))) {
        newBrands.add(normalizeKey(r.brand));
      }
      if (r.category.isNotEmpty && !cats.contains(normalizeKey(r.category))) {
        newCats.add(normalizeKey(r.category));
      }
    }
    return ImportSummary(
      totalRows: rows.length,
      validRows: valid.length,
      errorRows: rows.length - valid.length,
      warningRows: valid.where((r) => r.hasWarning).length,
      newProducts:
          valid
              .where((r) => r.action == ImportRowAction.createProduct)
              .map((r) => r.productKey)
              .toSet()
              .length,
      newVariants:
          valid
              .where((r) => r.action != ImportRowAction.updateVariant)
              .map((r) => r.variantKey)
              .toSet()
              .length,
      updatedVariants:
          valid
              .where((r) => r.action == ImportRowAction.updateVariant)
              .map((r) => r.variantKey)
              .toSet()
              .length,
      units: valid.fold<int>(0, (a, r) => a + (r.stock ?? 0)),
      lots:
          valid.where((r) => r.effectiveUsesLots && (r.stock ?? 0) > 0).length,
      newBrands: newBrands.length,
      newCategories: newCats.length,
    );
  }

  /// Construye el payload optimizado agrupado por producto y variante para el RPC
  static List<Map<String, dynamic>> buildPayload({
    required List<ImportRow> valid,
    required ImportStockMode stockMode,
  }) {
    final replace = stockMode == ImportStockMode.replace;
    final products = <String, Map<String, dynamic>>{};

    for (final r in valid) {
      final p = products.putIfAbsent(
        r.productKey,
        () => {
          'product_id': r.existing?.productId,
          'name': r.productName,
          'brand_name': r.brand,
          'category_name': r.category,
          'description': r.description,
          'components': r.components,
          'uses_lots': r.effectiveUsesLots,
          'variants': <String, Map<String, dynamic>>{},
        },
      );
      // Datos a nivel de producto: primera fila que los traiga
      if ((p['category_name'] as String).isEmpty && r.category.isNotEmpty) {
        p['category_name'] = r.category;
      }
      if ((p['components'] as String).isEmpty && r.components.isNotEmpty) {
        p['components'] = r.components;
      }
      if ((p['description'] as String).isEmpty && r.description.isNotEmpty) {
        p['description'] = r.description;
      }
      p['product_id'] ??= r.existing?.productId;

      final variants = p['variants'] as Map<String, Map<String, dynamic>>;
      final v = variants.putIfAbsent(
        r.variantKey,
        () => {
          'variant_id': r.existing?.variantId,
          'sku': r.sku.isEmpty ? null : r.sku,
          'variant_name': r.variantName.isEmpty ? null : r.variantName,
          'unit_cost': r.cost,
          'sale_price': r.salePrice,
          'wholesale_price': r.wholesalePrice,
          'wholesale_min_quantity': r.wholesaleMinQty,
          'image_url': r.imageUrl.isEmpty ? null : r.imageUrl,
          'stock_entries': <Map<String, dynamic>>[],
        },
      );

      final qty = r.stock;
      final isExisting = r.existing != null;
      if (qty != null && (qty > 0 || (replace && isExisting))) {
        (v['stock_entries'] as List<Map<String, dynamic>>).add({
          'quantity': qty,
          'lot_code': r.effectiveUsesLots ? r.lotCode : null,
          'expiry_date':
              r.effectiveUsesLots && r.expiry != null
                  ? formatDate(r.expiry!)
                  : null,
        });
      }
    }

    return [
      for (final p in products.values)
        {
          ...p,
          'variants':
              (p['variants'] as Map<String, Map<String, dynamic>>).values
                  .toList(),
        },
    ];
  }

  /// Formatea fechas a AAAA-MM-DD
  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
