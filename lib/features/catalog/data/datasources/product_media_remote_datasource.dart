import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';

class ProductMediaRemoteDataSource {
  final SupabaseClient _supabase;

  ProductMediaRemoteDataSource(this._supabase);

  Future<List<ProductImageEntity>> getProductImages(String productId) async {
    final response = await _supabase
        .from('product_images')
        .select('id, product_id, image_url, is_main, display_order')
        .eq('product_id', productId)
        .order('display_order');
    final models =
        List<Map<String, dynamic>>.from(
          response,
        ).map(ProductImageModel.fromJson).toList();
    return models.map((m) => m.toEntity()).toList();
  }

  Future<String?> uploadImageToStorage(Uint8List bytes, String folder) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$folder/$fileName';
    await _supabase.storage
        .from('products')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return _supabase.storage.from('products').getPublicUrl(path);
  }

  Future<void> deleteProductImage(String id, String imageUrl) async {
    await _supabase.from('product_images').delete().eq('id', id);
    final uri = Uri.tryParse(imageUrl);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final pathIdx = uri.pathSegments.indexOf('products');
      if (pathIdx != -1 && pathIdx + 1 < uri.pathSegments.length) {
        final filePath = uri.pathSegments.sublist(pathIdx + 1).join('/');
        await _supabase.storage.from('products').remove([filePath]);
      }
    }
  }

  Future<void> syncProductImages(List<Map<String, dynamic>> payload) async {
    await _supabase.from('product_images').upsert(payload, onConflict: 'id');
  }

  Future<void> deleteImagesFromUrls(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return;
    final paths =
        imageUrls.map((url) {
          if (url.contains('/storage/v1/object/public/products/')) {
            return url.split('/storage/v1/object/public/products/').last;
          }
          return url;
        }).toList();
    await _supabase.storage.from('products').remove(paths);
  }
}
