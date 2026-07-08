import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/category_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart';

class ProductFormService {
  final SupabaseClient _supabase;

  ProductFormService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', true);
      return (response as List).map((e) => CategoryModel.fromJson(e)).toList();
    } catch (e) {
      debugPrint('Error fetchCategories: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchIngredients(String productId) async {
    try {
      final resp = await _supabase
          .from('product_active_ingredients')
          .select(
            'ingredient_id, concentration, unit, active_ingredients!inner(name)',
          )
          .eq('product_id', productId);
      return List<Map<String, dynamic>>.from(resp);
    } catch (e) {
      debugPrint('Error fetchIngredients: $e');
      return [];
    }
  }

  Future<List<ProductImageModel>> fetchProductImages(String productId) async {
    try {
      final response = await _supabase
          .from('product_images')
          .select('*')
          .eq('product_id', productId)
          .isFilter('variant_id', null)
          .order('display_order', ascending: true);

      return (response as List)
          .map((e) => ProductImageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('Error fetchProductImages: $e');
      return [];
    }
  }

  Future<List<VariantDraftModel>> fetchVariants(String productId) async {
    try {
      // Optimizamos usando la misma query que existía, pero limpiamos un poco
      final variantRows = await _supabase
          .from('product_variants')
          .select('*, product_images(*)')
          .eq('product_id', productId)
          .order('created_at', ascending: true);

      final variantIds =
          (variantRows as List).map((r) => r['id'] as String).toList();

      final attrRows =
          variantIds.isEmpty
              ? <dynamic>[]
              : await _supabase
                  .from('variant_attribute_values')
                  .select(
                    'variant_id, attribute_values!inner(id, value, attributes!inner(id, name))',
                  )
                  .inFilter('variant_id', variantIds);

      final attrsByVariant = <String, List<Map<String, dynamic>>>{};
      for (final row in attrRows) {
        final vid = row['variant_id'] as String;
        attrsByVariant
            .putIfAbsent(vid, () => [])
            .add(Map<String, dynamic>.from(row));
      }

      final drafts =
          variantRows.map((item) {
            final variantMap = Map<String, dynamic>.from(item as Map);
            variantMap['variant_attribute_values'] =
                attrsByVariant[variantMap['id']] ?? [];

            final variant = ProductVariantModel.fromJson(variantMap);
            final draft = VariantDraftModel.fromVariant(variant);
            final imagesData = (item['product_images'] as List?) ?? [];
            draft.urlsExistentes =
                imagesData.map((img) => img['image_url'] as String).toList();
            return draft;
          }).toList();

      return drafts;
    } catch (e) {
      debugPrint('Error fetchVariants: $e');
      throw Exception('No se pudieron cargar las variantes existentes.');
    }
  }

  Future<bool> hasVariantSales(String variantId) async {
    try {
      final response = await _supabase
          .from('order_items')
          .select('id')
          .eq('variant_id', variantId)
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error hasVariantSales: $e');
      return true; // Por seguridad bloqueamos
    }
  }

  Future<void> deleteVariant(String variantId) async {
    final oldImages = await _supabase
        .from('product_images')
        .select('image_url')
        .eq('variant_id', variantId);

    for (final oldImg in oldImages) {
      final url = oldImg['image_url'] as String;
      final parts = url.split('/public/productos/');
      if (parts.length > 1) {
        final pathToRemove = parts.last;
        await _supabase.storage.from('productos').remove([pathToRemove]);
      }
    }

    await _supabase
        .from('variant_attribute_values')
        .delete()
        .eq('variant_id', variantId);
    await _supabase.from('product_variants').delete().eq('id', variantId);
  }

  Future<void> deleteProductImage(String id, String imageUrl) async {
    final parts = imageUrl.split('/public/productos/');
    if (parts.length > 1) {
      final pathToRemove = parts.last;
      await _supabase.storage.from('productos').remove([pathToRemove]);
    }
    await _supabase.from('product_images').delete().eq('id', id);
  }

  Future<String?> uploadImageToStorage(Uint8List bytes, String folder) async {
    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${bytes.hashCode}.jpg';
      final path = '$folder/$fileName';
      await _supabase.storage.from('productos').uploadBinary(path, bytes);
      return _supabase.storage.from('productos').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error subiendo imagen: $e');
      return null;
    }
  }

  Future<String> saveProductMaster({
    required String? productId,
    required Map<String, dynamic> productData,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;

    if (authUserId != null) {
      final profileResp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (profileResp != null) {
        profileId = profileResp['id'] as String;
      }
    }

    final isUpdating = productId != null;

    final dataToSave = {
      ...productData,
      if (isUpdating && profileId != null) 'updated_by': profileId,
      if (!isUpdating && profileId != null) 'created_by': profileId,
    };

    if (isUpdating) {
      await _supabase.from('products').update(dataToSave).eq('id', productId);
      return productId;
    } else {
      final res =
          await _supabase
              .from('products')
              .insert(dataToSave)
              .select('id')
              .single();
      return res['id'] as String;
    }
  }

  Future<void> syncProductImages(List<Map<String, dynamic>> payload) async {
    if (payload.isEmpty) return;
    await _supabase.from('product_images').upsert(payload);
  }

  Future<void> deactivateVariant(String variantId) async {
    await _supabase
        .from('product_variants')
        .update({'is_active': false})
        .eq('id', variantId);
  }

  Future<String?> getFirstVariantId(String productId) async {
    final vResp =
        await _supabase
            .from('product_variants')
            .select('id')
            .eq('product_id', productId)
            .limit(1)
            .maybeSingle();
    return vResp?['id'] as String?;
  }

  Future<String> saveVariant({
    required String productId,
    required Map<String, dynamic> variantData,
    String? variantId,
  }) async {
    final authUserId = _supabase.auth.currentUser?.id;
    String? profileId;

    if (authUserId != null) {
      final profileResp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (profileResp != null) {
        profileId = profileResp['id'] as String;
      }
    }

    final payload = {
      ...variantData,
      'product_id': productId,
      if (variantId != null && profileId != null) 'updated_by': profileId,
      if (variantId == null && profileId != null) 'created_by': profileId,
    };

    if (variantId != null) {
      await _supabase
          .from('product_variants')
          .update(payload)
          .eq('id', variantId);
      return variantId;
    } else {
      final res =
          await _supabase
              .from('product_variants')
              .insert(payload)
              .select('id')
              .single();
      return res['id'] as String;
    }
  }

  Future<void> saveVariantAttributes(
    String variantId,
    List<String> attributeValueIds,
  ) async {
    await _supabase
        .from('variant_attribute_values')
        .delete()
        .eq('variant_id', variantId);

    if (attributeValueIds.isEmpty) return;

    await _supabase
        .from('variant_attribute_values')
        .insert(
          attributeValueIds
              .map(
                (valId) => {
                  'variant_id': variantId,
                  'attribute_value_id': valId,
                },
              )
              .toList(),
        );
  }

  Future<void> clearVariantImages(String variantId) async {
    final oldImages = await _supabase
        .from('product_images')
        .select('image_url')
        .eq('variant_id', variantId);
    for (final oldImg in oldImages) {
      final url = oldImg['image_url'] as String;
      final parts = url.split('/public/productos/');
      if (parts.length > 1) {
        final pathToRemove = parts.last;
        await _supabase.storage.from('productos').remove([pathToRemove]);
      }
    }
    await _supabase.from('product_images').delete().eq('variant_id', variantId);
  }

  Future<void> clearProductIngredients(String productId) async {
    await _supabase
        .from('product_active_ingredients')
        .delete()
        .eq('product_id', productId);
  }

  Future<void> insertProductIngredient(Map<String, dynamic> payload) async {
    await _supabase.from('product_active_ingredients').insert(payload);
  }

  Future<List<Map<String, dynamic>>> searchIngredients(String term) async {
    final resp = await _supabase
        .from('active_ingredients')
        .select('id, name')
        .ilike('name', '%$term%')
        .limit(10);
    return List<Map<String, dynamic>>.from(resp);
  }

  Future<Map<String, dynamic>> createIngredient(String name) async {
    final resp =
        await _supabase
            .from('active_ingredients')
            .insert({'name': name})
            .select('id, name')
            .single();
    return resp;
  }
}
