import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/inventory_stock_models.dart';

class InventoryService {
  final _supabase = Supabase.instance.client;

  /// Retorna las métricas globales para Stock (Stock total, Variantes, Low stock)
  /// Usamos head: true para no descargar datos, o una query agrupada simple.
  /// Dado que el reorder point está a nivel de variante y requiere contar lotes,
  /// podríamos hacer una query a variants + batches.
  /// Para no sobrecargar, usaremos un enfoque mixto o rpc si existiera.
  /// Por ahora traemos la suma si es posible, o mantenemos un query ligero.
  Future<Map<String, dynamic>> getGeneralStockMetrics() async {
    // Esto podría optimizarse en un Edge Function o RPC en el futuro.
    // Traeremos solo lo esencial para calcular.
    final response = await _supabase
        .from('product_variants')
        .select('''
      id, reorder_point, unit_cost,
      products!inner(stock_control, is_active, unit_cost),
      warehouse_stock_batches(available_quantity)
    ''')
        .eq('is_active', true)
        .eq('products.is_active', true);

    int totalStock = 0;
    int lowStockCount = 0;
    double totalCost = 0.0;
    int totalVariants = (response as List).length;

    for (final raw in response) {
      final stockControl = raw['products']['stock_control'] as bool? ?? true;
      final reorderPoint = raw['reorder_point'] as int? ?? 3;

      final double pUnitCost = (raw['products']['unit_cost'] as num?)?.toDouble() ?? 0.0;
      final double vUnitCost = (raw['unit_cost'] as num?)?.toDouble() ?? 0.0;
      final double finalCost = vUnitCost > 0 ? vUnitCost : pUnitCost;

      int variantStock = 0;
      final batches = raw['warehouse_stock_batches'] as List? ?? [];
      for (final b in batches) {
        variantStock += (b['available_quantity'] as num?)?.toInt() ?? 0;
      }

      if (stockControl) {
        totalStock += variantStock;
        totalCost += variantStock * finalCost;
        if (variantStock <= reorderPoint && variantStock > 0) {
          lowStockCount++; 
        } else if (variantStock <= 0) {
          lowStockCount++;
        }
      }
    }

    return {
      'totalVariants': totalVariants,
      'totalStock': totalStock,
      'lowStockCount': lowStockCount,
      'totalCost': totalCost,
    };
  }

  /// Retorna las categorías activas para el filtro
  Future<List<String>> getCategories() async {
    final response = await _supabase.from('categories').select('name');
    final cats = (response as List).map((e) => e['name'].toString()).toList();
    cats.sort();
    return ['Todos', ...cats];
  }

  /// Pagina las variantes de producto aplicando filtros en la DB.
  Future<List<InventoryStockItem>> getGeneralStockPaginated({
    required int page,
    required int pageSize,
    String search = '',
    String categoryName = 'Todos',
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _supabase
        .from('product_variants')
        .select('''
      id, sku, sale_price, unit_cost, wholesale_price, wholesale_min_quantity, reorder_point,
      variant_attribute_values(attribute_values(value)),
      products!inner(
        id, name, product_type, uses_batches, stock_control, unit_cost, sale_price, wholesale_price, wholesale_min_quantity,
        categories(name),
        product_images(image_url, is_main, variant_id)
      ),
      warehouse_stock_batches(
        id, batch_number, expiry_date, available_quantity, warehouse_id, supplier_id,
        warehouses(name), suppliers(name)
      )
    ''')
        .eq('is_active', true)
        .eq('products.is_active', true);

    if (search.isNotEmpty) {
      final matchingProducts = await _supabase.from('products').select('id').ilike('name', '%$search%');
      final pIds = (matchingProducts as List).map((e) => e['id']).toList();
      
      final orConditions = ['sku.ilike.%$search%'];
      if (pIds.isNotEmpty) {
        orConditions.add('product_id.in.(${pIds.join(',')})');
      }
      query = query.or(orConditions.join(','));
    }

    // Filtrar por categoría. El !inner ya está en products. Pero categories no tiene !inner aquí a menos que lo agreguemos.
    // Como PostgREST no soporta filtros anidados profundos fácilmente en el OR,
    // lo haremos trayendo todo lo que coincida con category si se seleccionó una.
    // NOTA: Para filtrar por categoría nativamente, necesitamos un RPC o usar products.categories.name.
    // Vamos a intentar filtrar después en el cliente si no hay un endpoint limpio.
    // O mejor, traeremos sin filtro de categoría en DB y lo aplicaremos en Dart si no hay muchas,
    // pero eso rompe la paginación.
    // En Supabase: .eq('products.categories.name', categoryName) -> Puede fallar si la relación no es directa.
    // Dado que products tiene category_id, podríamos buscar la categoría primero.

    String? catId;
    if (categoryName != 'Todos') {
      final catRes =
          await _supabase
              .from('categories')
              .select('id')
              .eq('name', categoryName)
              .maybeSingle();
      if (catRes != null) {
        catId = catRes['id'] as String;
      }
    }

    if (catId != null) {
      query = query.eq('products.category_id', catId);
    }

    final response = await query
        .range(from, to)
        .order('created_at', ascending: false);

    final List<InventoryStockItem> result = [];

    for (final rawVariant in (response as List)) {
      final variant = rawVariant as Map<String, dynamic>;
      final prod = variant['products'] as Map<String, dynamic>;

      final variantId = variant['id'] as String;
      final usesBatches = prod['uses_batches'] as bool? ?? false;
      final stockControl = prod['stock_control'] as bool? ?? true;
      final catName =
          (prod['categories'] as Map?)?['name'] as String? ?? 'Sin categoría';

      // Precios
      final double unitCost = (prod['unit_cost'] as num).toDouble();
      final double prodSalePrice = (prod['sale_price'] as num).toDouble();
      final double? prodWholesalePrice =
          (prod['wholesale_price'] as num?)?.toDouble();
      final int prodWholesaleMinQty =
          (prod['wholesale_min_quantity'] as int?) ?? 1;

      final double variantUnitCost =
          ((variant['unit_cost'] as num?)?.toDouble() ?? 0) > 0
              ? (variant['unit_cost'] as num).toDouble()
              : unitCost;
      final double variantSalePrice =
          (variant['sale_price'] as num?)?.toDouble() ?? prodSalePrice;
      final double? variantWholesalePrice =
          (variant['wholesale_price'] as num?)?.toDouble() ??
          prodWholesalePrice;
      final int variantWholesaleMinQty =
          (variant['wholesale_min_quantity'] as int?) ?? prodWholesaleMinQty;

      // Atributos
      final vavList =
          variant['variant_attribute_values'] as List<dynamic>? ?? [];
      final List<String> attrValues = [];
      for (var vav in vavList) {
        final av = vav['attribute_values'] as Map<String, dynamic>?;
        if (av != null && av['value'] != null) {
          attrValues.add(av['value'].toString());
        }
      }
      final attrsText = attrValues.join(' · ');

      // Imágenes
      final imagesList = prod['product_images'] as List<dynamic>? ?? [];
      String? finalImageUrl;
      if (imagesList.isNotEmpty) {
        final variantImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['variant_id'] == variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
          finalImageUrl = variantImage['image_url'] as String;
        } else {
          final mainImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
            (img) => img['is_main'] == true,
            orElse:
                () =>
                    imagesList.isNotEmpty
                        ? imagesList.first as Map<String, dynamic>
                        : <String, dynamic>{},
          );
          finalImageUrl = mainImage['image_url'] as String?;
        }
      }

      // Lotes
      final batchesRaw = variant['warehouse_stock_batches'] as List? ?? [];
      final batches =
          batchesRaw.map((b) {
            final m = Map<String, dynamic>.from(b as Map);
            final wh = m['warehouses'] as Map<String, dynamic>?;
            final sup = m['suppliers'] as Map<String, dynamic>?;
            return InventoryBatchItem(
              id: m['id'] as String,
              batchNumber: m['batch_number'] as String? ?? 'DEFAULT',
              expiryDate: m['expiry_date'] as String?,
              availableQuantity:
                  (m['available_quantity'] as num?)?.toInt() ?? 0,
              warehouseId: m['warehouse_id'] as String,
              warehouseName: wh?['name'] as String?,
              supplierId: m['supplier_id'] as String?,
              supplierName: sup?['name'] as String?,
              variantId: variantId,
              productId: prod['id'] as String,
              productName: prod['name'] as String,
              variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
              sku: variant['sku'] as String?,
              usesBatches: usesBatches,
              imageUrl: finalImageUrl,
            );
          }).toList();

      int stock = 0;
      if (stockControl) {
        stock = batches.fold(0, (s, b) => s + b.availableQuantity);
      }

      final reorderPoint = (variant['reorder_point'] as int?) ?? 3;

      result.add(
        InventoryStockItem(
          productId: prod['id'] as String,
          productName: prod['name'] as String,
          category: catName,
          productType: prod['product_type'] as String? ?? 'good',
          usesBatches: usesBatches,
          stockControl: stockControl,
          unitCost: variantUnitCost,
          salePrice: variantSalePrice,
          wholesalePrice: variantWholesalePrice,
          wholesaleMinQty: variantWholesaleMinQty,
          variantId: variantId,
          sku: variant['sku'] as String?,
          attrsText: attrsText.isNotEmpty ? attrsText : 'Única',
          imageUrl: finalImageUrl,
          reorderPoint: reorderPoint,
          stock: stock,
          batches: batches,
          isLowStock: stockControl && stock <= reorderPoint,
        ),
      );
    }

    return result;
  }

  /// Pagina lotes aplicando filtros desde Supabase
  Future<List<InventoryBatchItem>> getBatchesPaginated({
    required int page,
    required int pageSize,
    String search = '',
    String statusFilter = 'Todos',
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _supabase
        .from('warehouse_stock_batches')
        .select('''
      id, batch_number, expiry_date, available_quantity,
      variant_id, warehouse_id, product_id, supplier_id,
      products!inner(id, name, uses_batches, product_images(image_url, is_main, variant_id)),
      product_variants(id, sku, variant_attribute_values(attribute_values(value))),
      warehouses(name),
      suppliers(name)
    ''')
        .gt('available_quantity', 0)
        .eq('products.uses_batches', true);

    if (search.isNotEmpty) {
      final matchingProducts = await _supabase.from('products').select('id').ilike('name', '%$search%');
      final pIds = (matchingProducts as List).map((e) => e['id']).toList();
      
      final matchingVariants = await _supabase.from('product_variants').select('id').ilike('sku', '%$search%');
      final vIds = (matchingVariants as List).map((e) => e['id']).toList();
      
      final orConditions = ['batch_number.ilike.%$search%'];
      if (pIds.isNotEmpty) {
        orConditions.add('product_id.in.(${pIds.join(',')})');
      }
      if (vIds.isNotEmpty) {
        orConditions.add('variant_id.in.(${vIds.join(',')})');
      }
      query = query.or(orConditions.join(','));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final plus30 =
        DateTime(now.year, now.month, now.day + 30).toIso8601String();
    final plus90 =
        DateTime(now.year, now.month, now.day + 90).toIso8601String();

    if (statusFilter == 'Vencido') {
      query = query.lt('expiry_date', today);
    } else if (statusFilter == 'Crítico') {
      query = query.gte('expiry_date', today).lte('expiry_date', plus30);
    } else if (statusFilter == 'Próximo') {
      query = query.gt('expiry_date', plus30).lte('expiry_date', plus90);
    } else if (statusFilter == 'Normal') {
      query = query.gt('expiry_date', plus90);
    }

    final response = await query
        .order('expiry_date', ascending: true, nullsFirst: false)
        .range(from, to);

    final List<InventoryBatchItem> result = [];

    for (final b in (response as List)) {
      final m = Map<String, dynamic>.from(b as Map);
      final prod = m['products'] as Map<String, dynamic>?;
      final variant = m['product_variants'] as Map<String, dynamic>?;
      final variantId = m['variant_id'] as String;

      String? finalImageUrl;
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (imagesList.isNotEmpty) {
        final variantImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['variant_id'] == variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
          finalImageUrl = variantImage['image_url'] as String;
        } else {
          final mainImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
            (img) => img['is_main'] == true,
            orElse:
                () =>
                    imagesList.isNotEmpty
                        ? imagesList.first as Map<String, dynamic>
                        : <String, dynamic>{},
          );
          finalImageUrl = mainImage['image_url'] as String?;
        }
      }

      final vavList =
          variant?['variant_attribute_values'] as List<dynamic>? ?? [];
      final List<String> attrValues = [];
      for (var vav in vavList) {
        final av = vav['attribute_values'] as Map<String, dynamic>?;
        if (av != null && av['value'] != null) {
          attrValues.add(av['value'].toString());
        }
      }
      final attrsText = attrValues.join(' · ');

      final wh = m['warehouses'] as Map<String, dynamic>?;
      final sup = m['suppliers'] as Map<String, dynamic>?;

      result.add(
        InventoryBatchItem(
          id: m['id'] as String,
          batchNumber: m['batch_number'] as String? ?? 'DEFAULT',
          expiryDate: m['expiry_date'] as String?,
          availableQuantity: (m['available_quantity'] as num?)?.toInt() ?? 0,
          warehouseId: m['warehouse_id'] as String,
          warehouseName: wh?['name'] as String?,
          supplierId: m['supplier_id'] as String?,
          supplierName: sup?['name'] as String?,
          variantId: variantId,
          productId: m['product_id'] as String,
          productName: prod?['name'] as String?,
          variantAttrs: attrsText.isNotEmpty ? attrsText : 'Única',
          sku: variant?['sku'] as String?,
          usesBatches: true,
          imageUrl: finalImageUrl,
        ),
      );
    }

    return result;
  }

  /// Retorna conteos globales para los estados de lotes, respetando la búsqueda actual.
  Future<Map<String, int>> getBatchMetrics({String search = ''}) async {
    var query = _supabase
        .from('warehouse_stock_batches')
        .select('''
      expiry_date,
      products!inner(uses_batches)
    ''')
        .gt('available_quantity', 0)
        .eq('products.uses_batches', true);

    if (search.isNotEmpty) {
      final matchingProducts = await _supabase.from('products').select('id').ilike('name', '%$search%');
      final pIds = (matchingProducts as List).map((e) => e['id']).toList();
      
      final matchingVariants = await _supabase.from('product_variants').select('id').ilike('sku', '%$search%');
      final vIds = (matchingVariants as List).map((e) => e['id']).toList();
      
      final orConditions = ['batch_number.ilike.%$search%'];
      if (pIds.isNotEmpty) {
        orConditions.add('product_id.in.(${pIds.join(',')})');
      }
      if (vIds.isNotEmpty) {
        orConditions.add('variant_id.in.(${vIds.join(',')})');
      }
      query = query.or(orConditions.join(','));
    }

    final response = await query;

    int countVencido = 0;
    int countCritico = 0;
    int countProximo = 0;
    int countNormal = 0;

    final now = DateTime.now();

    for (final raw in (response as List)) {
      final ed = raw['expiry_date'] as String?;
      if (ed == null) continue;

      final expiry = DateTime.tryParse(ed);
      if (expiry == null) continue;

      final diff = expiry.difference(now).inDays;
      if (diff < 0) {
        countVencido++;
      } else if (diff <= 30) {
        countCritico++;
      } else if (diff <= 90) {
        countProximo++;
      } else {
        countNormal++;
      }
    }

    return {
      'vencido': countVencido,
      'critico': countCritico,
      'proximo': countProximo,
      'normal': countNormal,
    };
  }

  Future<int> getTotalGeneralStockCount({
    String search = '',
    String categoryName = 'Todos',
  }) async {
    var query = _supabase
        .from('product_variants')
        .select('''
      id,
      products!inner(id, name, category_id, is_active)
    ''')
        .eq('is_active', true)
        .eq('products.is_active', true);

    if (search.isNotEmpty) {
      final matchingProducts = await _supabase.from('products').select('id').ilike('name', '%$search%');
      final pIds = (matchingProducts as List).map((e) => e['id']).toList();
      
      final orConditions = ['sku.ilike.%$search%'];
      if (pIds.isNotEmpty) {
        orConditions.add('product_id.in.(${pIds.join(',')})');
      }
      query = query.or(orConditions.join(','));
    }

    String? catId;
    if (categoryName != 'Todos') {
      final catRes =
          await _supabase
              .from('categories')
              .select('id')
              .eq('name', categoryName)
              .maybeSingle();
      if (catRes != null) {
        catId = catRes['id'] as String;
      }
    }

    if (catId != null) {
      query = query.eq('products.category_id', catId);
    }

    final response = await query;
    return (response as List).length;
  }

  Future<int> getTotalBatchesCount({
    String search = '',
    String statusFilter = 'Todos',
  }) async {
    var query = _supabase
        .from('warehouse_stock_batches')
        .select('''
      id,
      products!inner(uses_batches)
    ''')
        .gt('available_quantity', 0)
        .eq('products.uses_batches', true);

    if (search.isNotEmpty) {
      final matchingProducts = await _supabase.from('products').select('id').ilike('name', '%$search%');
      final pIds = (matchingProducts as List).map((e) => e['id']).toList();
      
      final matchingVariants = await _supabase.from('product_variants').select('id').ilike('sku', '%$search%');
      final vIds = (matchingVariants as List).map((e) => e['id']).toList();
      
      final orConditions = ['batch_number.ilike.%$search%'];
      if (pIds.isNotEmpty) {
        orConditions.add('product_id.in.(${pIds.join(',')})');
      }
      if (vIds.isNotEmpty) {
        orConditions.add('variant_id.in.(${vIds.join(',')})');
      }
      query = query.or(orConditions.join(','));
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).toIso8601String();
    final plus30 =
        DateTime(now.year, now.month, now.day + 30).toIso8601String();
    final plus90 =
        DateTime(now.year, now.month, now.day + 90).toIso8601String();

    if (statusFilter == 'Vencido') {
      query = query.lt('expiry_date', today);
    } else if (statusFilter == 'Crítico') {
      query = query.gte('expiry_date', today).lte('expiry_date', plus30);
    } else if (statusFilter == 'Próximo') {
      query = query.gt('expiry_date', plus30).lte('expiry_date', plus90);
    } else if (statusFilter == 'Normal') {
      query = query.gt('expiry_date', plus90);
    }

    final response = await query;
    return (response as List).length;
  }
}
