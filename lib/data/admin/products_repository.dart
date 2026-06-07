import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductsRepository {
  ProductsRepository({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

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

  // 👇 1. Agregamos el parámetro isAdmin (por defecto false para proteger al cliente)
  Future<List<ProductModel>> fetchProducts({
    String? categoryId,
    String? searchTerm,
    bool isAdmin = false,
  }) async {
    var query = _supabase.from('products').select('*, product_images(*)');

    // 👇 2. LA MAGIA: Si NO es administrador, filtramos solo los activos.
    // Si ES administrador, esta regla se ignora y trae absolutamente todo.
    if (!isAdmin) {
      query = query.eq('is_active', true);
    }

    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
    }

    final normalizedSearch = searchTerm?.trim() ?? '';
    if (normalizedSearch.isNotEmpty) {
      query = query.ilike('name', '%$normalizedSearch%');
    }

    final response = await query.order('name');

    return List<Map<String, dynamic>>.from(
      response,
    ).map(ProductModel.fromJson).toList(growable: false);
  }

  Future<Map<String, int>> fetchProductStock() async {
    // Aprovechamos la nueva columna product_id para evitar hacer un JOIN con variantes.
    // Esto hace la consulta muchísimo más rápida y ligera.
    final response = await _supabase
        .from('warehouse_stock_batches')
        .select('product_id, available_quantity');

    final stockByProduct = <String, int>{};
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final productId = row['product_id'] as String?;
      if (productId == null) continue;

      final currentStock = (row['available_quantity'] as num?)?.toInt() ?? 0;

      // Sumamos el stock de todos los lotes que pertenezcan al mismo producto
      stockByProduct[productId] =
          (stockByProduct[productId] ?? 0) + currentStock;
    }

    return stockByProduct;
  }

  Future<Map<String, List<ProductVariantModel>>> fetchVariantsByProductIds(
    List<String> productIds,
  ) async {
    if (productIds.isEmpty) return {};

    final response = await _supabase
        .from('product_variants')
        .select(
          'id, product_id, sku, attributes, product_images(*), sale_price, wholesale_price, wholesale_min_quantity, reorder_point, is_active',
        )
        .inFilter('product_id', productIds)
        .order('created_at', ascending: true);

    final variants = List<Map<String, dynamic>>.from(
      response,
    ).map(ProductVariantModel.fromJson).toList(growable: false);

    final grouped = <String, List<ProductVariantModel>>{};
    for (final variant in variants) {
      grouped.putIfAbsent(variant.productId, () => []);
      grouped[variant.productId]!.add(variant);
    }

    return grouped;
  }

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
      // Sumamos la cantidad porque ahora pueden existir múltiples lotes por variante
      stockByVariant[variantId] = (stockByVariant[variantId] ?? 0) + stock;
    }

    return stockByVariant;
  }

  Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) {
    return _supabase
        .from('products')
        .update({'is_active': isActive})
        .eq('id', productId);
  }
}
