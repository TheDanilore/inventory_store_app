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
  /// - [attributes] JSONB legacy (se eliminará al migrar la BD)
  static const String _variantSelect = '''
    id,
    product_id,
    sku,
    barcode,
    attributes,
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
    var query = _supabase.from('products').select('*, product_images(*)');

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

  // ── Stock de productos ────────────────────────────────────────────────────

  /// Suma el stock de todos los lotes por producto.
  Future<Map<String, int>> fetchProductStock() async {
    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('product_id, available_quantity');

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
