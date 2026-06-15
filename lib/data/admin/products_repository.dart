import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsRepository {
  ProductsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  // ── Queries de selección ──────────────────────────────────────────────────

  /// Campos completos de variante incluyendo:
  /// - [unit_cost], [barcode] (nuevos campos en la BD)
  /// - [variant_attribute_values] con join a [attribute_values] y [attributes]
  ///   para soporte de la nueva estructura de atributos
  static const String _variantSelect = '''
    id,
    product_id,
    sku,
    barcode,
    unit_cost,
    sale_price,
    wholesale_price,
    wholesale_min_quantity,
    reorder_point,
    is_active,
    created_at,
    created_by,
    updated_by,
    product_images(*),
    variant_attribute_values(
      attribute_value_id,
      attribute_values(
        id,
        value,
        attributes(
          id,
          name
        )
      )
    )
  ''';

  // ── Categorías ────────────────────────────────────────────────────────────

  Future<List<CategoryModel>> fetchActiveCategories() async {
    final response = await _supabase
        .from('categories')
        .select('id, name, description, is_active')
        .eq('is_active', true)
        .order('name');

    return List<Map<String, dynamic>>.from(
      response,
    ).map(CategoryModel.fromJson).toList(growable: false);
  }

  // ── Productos ─────────────────────────────────────────────────────────────

  Future<List<ProductModel>> fetchProducts({
    String? categoryId,
    String? searchTerm,
    bool isAdmin = false,
  }) async {
    var query = _supabase.from('products').select(
      'id, name, unit_cost, sale_price, wholesale_price, wholesale_min_quantity, is_active, description, category_id, details, created_at, updated_at, stock_control, uses_batches, product_type, product_images(*)',
    );

    if (!isAdmin) {
      query = query.eq('is_active', true);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final normalized = searchTerm?.trim() ?? '';
    if (normalized.isNotEmpty) {
      query = query.ilike('name', '%$normalized%');
    }

    final response = await query.order('name');

    return List<Map<String, dynamic>>.from(
      response,
    ).map(ProductModel.fromJson).toList(growable: false);
  }

  /// Busca productos basándose en ingredientes activos
  Future<({List<ProductModel> products, Map<String, String> matches})>
  fetchProductsByIngredient({
    required String searchTerm,
    String? categoryId,
    bool isAdmin = false,
  }) async {
    // 1. RPC: buscar ingredient_ids.
    final List<dynamic> aiResp = await _supabase.rpc(
      'search_ingredients_unaccent',
      params: {'search_term': searchTerm},
    );

    final ingredientIds =
        (aiResp)
            .map((r) => (r as Map<String, dynamic>)['id']?.toString())
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();

    if (ingredientIds.isEmpty) {
      return (products: <ProductModel>[], matches: <String, String>{});
    }

    // 2. Buscar product_ids y los datos reales de los ingredientes
    final ingResp = await _supabase
        .from('product_active_ingredients')
        .select('product_id, concentration, unit, active_ingredients(name)')
        .inFilter('ingredient_id', ingredientIds);

    final productIds = <String>[];
    final newMatches = <String, String>{};

    for (final e in ingResp as List) {
      final row = e as Map<String, dynamic>;
      final pId = row['product_id']?.toString();
      if (pId == null || pId.isEmpty) continue;

      productIds.add(pId);

      final aiMap = row['active_ingredients'] as Map<String, dynamic>?;
      final name = aiMap?['name']?.toString() ?? 'Desconocido';
      final conc = row['concentration'];
      final unit = row['unit']?.toString().trim();

      String label = name;
      if (conc != null) {
        final concStr =
            (conc is num && conc == conc.toInt())
                ? conc.toInt().toString()
                : conc.toString();
        label += ' $concStr';
      }
      if (unit != null && unit.isNotEmpty) {
        if (unit.startsWith('%')) {
          label += unit;
        } else {
          label += ' $unit';
        }
      }

      if (newMatches.containsKey(pId)) {
        newMatches[pId] = '${newMatches[pId]} + $label';
      } else {
        newMatches[pId] = label;
      }
    }

    final uniqueProductIds = productIds.toSet().toList();
    if (uniqueProductIds.isEmpty) {
      return (products: <ProductModel>[], matches: <String, String>{});
    }

    var query = _supabase
        .from('products')
        .select('''
          id, name, unit_cost, sale_price, wholesale_price,
          wholesale_min_quantity, is_active, description,
          category_id, details, created_at, updated_at,
          stock_control, uses_batches, product_type,
          categories(name),
          product_images(*)
        ''')
        .inFilter('id', uniqueProductIds);

    if (!isAdmin) {
      query = query.eq('is_active', true);
    }
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final resp = await query.order('name');

    final productsList = <ProductModel>[];
    for (final e in resp as List) {
      try {
        final row = Map<String, dynamic>.from(e as Map);
        if (row['id'] == null || row['name'] == null) continue;
        productsList.add(ProductModel.fromJson(row));
      } catch (_) {}
    }

    return (products: productsList, matches: newMatches);
  }

  // ── Stock de productos ────────────────────────────────────────────────────

  /// Suma el stock de todos los lotes por producto.
  /// Si se proveen [productIds], filtra solo esos productos para reducir el egress.
  Future<Map<String, int>> fetchProductStock({List<String>? productIds}) async {
    var query = _supabase
        .from('warehouse_stock_batches')
        .select('product_id, available_quantity');

    if (productIds != null && productIds.isNotEmpty) {
      query = query.inFilter('product_id', productIds);
    }

    final response = await query;

    final stockByProduct = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;
      final qty = (row['available_quantity'] as num?)?.toInt() ?? 0;
      stockByProduct[productId] = (stockByProduct[productId] ?? 0) + qty;
    }
    return stockByProduct;
  }

  // ── Variantes ─────────────────────────────────────────────────────────────

  /// Obtiene variantes por lista de productIds con todos los campos necesarios,
  /// incluyendo los atributos estructurados de las nuevas tablas.
  Future<Map<String, List<ProductVariantModel>>> fetchVariantsByProductIds(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    final response = await _supabase
        .from('product_variants')
        .select(_variantSelect)
        .inFilter('product_id', productIds)
        .order('created_at', ascending: true);

    final variants = List<Map<String, dynamic>>.from(
      response,
    ).map(ProductVariantModel.fromJson).toList(growable: false);

    final grouped = <String, List<ProductVariantModel>>{};
    for (final v in variants) {
      grouped.putIfAbsent(v.productId, () => []).add(v);
    }
    return grouped;
  }

  /// Obtiene UNA variante por id con todos sus campos, incluyendo atributos.
  Future<ProductVariantModel?> fetchVariantById(String variantId) async {
    final response =
        await _supabase
            .from('product_variants')
            .select(_variantSelect)
            .eq('id', variantId)
            .maybeSingle();

    if (response == null) return null;
    return ProductVariantModel.fromJson(Map<String, dynamic>.from(response));
  }

  // ── Stock por variante ────────────────────────────────────────────────────

  /// Suma el stock de todos los lotes por variantId.
  Future<Map<String, int>> fetchVariantStockByVariantIds(
    List<String> variantIds,
  ) async {
    if (variantIds.isEmpty) return {};

    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('variant_id, available_quantity')
        .inFilter('variant_id', variantIds);

    final stockByVariant = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final variantId = row['variant_id'] as String?;
      if (variantId == null) continue;
      final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
      stockByVariant[variantId] = (stockByVariant[variantId] ?? 0) + stock;
    }
    return stockByVariant;
  }

  // ── Atributos ────────────────────────────────────────────────────────────

  /// Trae todos los tipos de atributos disponibles para el form de variante.
  Future<List<Map<String, dynamic>>> fetchAttributes() async {
    final response = await _supabase
        .from('attributes')
        .select('id, name, attribute_values(id, value)')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Guarda los atributos de una variante en [variant_attribute_values].
  /// Primero elimina los existentes, luego inserta los nuevos.
  Future<void> saveVariantAttributeValues(
    String variantId,
    List<String> attributeValueIds,
  ) async {
    // Eliminar existentes
    await _supabase
        .from('variant_attribute_values')
        .delete()
        .eq('variant_id', variantId);

    if (attributeValueIds.isEmpty) return;

    // Insertar nuevos
    final rows =
        attributeValueIds
            .map(
              (avId) => {'variant_id': variantId, 'attribute_value_id': avId},
            )
            .toList();

    await _supabase.from('variant_attribute_values').insert(rows);
  }

  // ── Utilidades de producto ────────────────────────────────────────────────

  Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) => _supabase
      .from('products')
      .update({'is_active': isActive})
      .eq('id', productId);
}
