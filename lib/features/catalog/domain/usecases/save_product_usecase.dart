import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

class SaveProductPayload {
  final ProductEntity product;
  final String? profileId;
  final bool isUpdating;
  final double? baseSalePrice;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQuantity;

  // Images
  final List<ImagePayload> images;

  // Variants
  final List<String> removedVariantIds;
  final List<VariantPayload> variants;

  // Ingredients
  final bool ingredientsEnabled;
  final List<IngredientPayload> ingredients;

  SaveProductPayload({
    required this.product,
    this.profileId,
    required this.isUpdating,
    this.baseSalePrice,
    this.baseWholesalePrice,
    this.baseWholesaleMinQuantity = 3,
    required this.images,
    required this.removedVariantIds,
    required this.variants,
    required this.ingredientsEnabled,
    required this.ingredients,
  });
}

class ImagePayload {
  final String? existingId;
  final String? existingUrl;
  final Uint8List? newBytes;

  ImagePayload({this.existingId, this.existingUrl, this.newBytes});
}

class VariantPayload {
  final String? id;
  final String? sku;
  final double unitCost;
  final double? salePrice;
  final double? wholesalePrice;
  final int? wholesaleMinQuantity;
  final int? reorderPoint;
  final bool isActive;
  final List<String> attributeValueIds;
  final bool clearImages;
  final Uint8List? newImageBytes;

  VariantPayload({
    this.id,
    this.sku,
    required this.unitCost,
    this.salePrice,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
    this.reorderPoint,
    required this.isActive,
    required this.attributeValueIds,
    required this.clearImages,
    this.newImageBytes,
  });
}

class IngredientPayload {
  final String ingredientId;
  final double? concentration;
  final String? unit;

  IngredientPayload({
    required this.ingredientId,
    this.concentration,
    this.unit,
  });
}

@lazySingleton
class SaveProductUseCase {
  final ProductsRepository repository;
  final IngredientsRepository ingredientsRepository;

  SaveProductUseCase(this.repository, this.ingredientsRepository);

  Future<T> _unwrap<T>(Future<Either<Failure, T>> future) async {
    final res = await future;
    return res.fold((f) => throw Exception(f.message), (r) => r);
  }

  Future<Either<Failure, void>> call(SaveProductPayload payload) async {
    try {
      // 1. Subir imágenes del producto
      final productImagesJson = <Map<String, dynamic>>[];
      for (var i = 0; i < payload.images.length; i++) {
        final item = payload.images[i];
        final isMain = (i == 0);

        if (item.existingId != null) {
          productImagesJson.add({
            'id': item.existingId,
            'image_url': item.existingUrl,
            'display_order': i,
            'is_main': isMain,
          });
        } else if (item.newBytes != null) {
          final url = await _unwrap(
            repository.uploadImageToStorage(item.newBytes!, 'productos'),
          );
          if (url != null) {
            productImagesJson.add({
              'image_url': url,
              'display_order': i,
              'is_main': isMain,
            });
          }
        }
      }

      // 2. Subir imágenes de las variantes y preparar JSON de variantes
      final variantsJson = <Map<String, dynamic>>[];
      for (final draft in payload.variants) {
        String? newImageUrl;
        if (draft.newImageBytes != null) {
          newImageUrl = await _unwrap(
            repository.uploadImageToStorage(draft.newImageBytes!, 'variantes'),
          );
        }

        variantsJson.add({
          'id': draft.id,
          'sku': draft.sku,
          'unit_cost': draft.unitCost,
          'sale_price': draft.salePrice ?? payload.baseSalePrice,
          'wholesale_price': draft.wholesalePrice ?? payload.baseWholesalePrice,
          'wholesale_min_quantity':
              draft.wholesaleMinQuantity ?? payload.baseWholesaleMinQuantity,
          'reorder_point': draft.reorderPoint ?? 3,
          'is_active': draft.isActive,
          'clear_images': draft.clearImages,
          'new_image_url': newImageUrl,
          'attribute_value_ids': draft.attributeValueIds,
        });
      }

      // Si no hay variantes, crear una por defecto
      if (variantsJson.isEmpty) {
        variantsJson.add({
          'is_active': true,
          'sale_price': payload.baseSalePrice,
          'wholesale_price': payload.baseWholesalePrice,
          'wholesale_min_quantity': payload.baseWholesaleMinQuantity,
          'unit_cost': 0.0,
          'attribute_value_ids': [],
        });
      }

      // 3. Preparar JSON de ingredientes
      final ingredientsJson = <Map<String, dynamic>>[];
      if (payload.ingredientsEnabled) {
        for (final ing in payload.ingredients) {
          ingredientsJson.add({
            'ingredient_id': ing.ingredientId,
            'concentration': ing.concentration,
            'unit': ing.unit,
          });
        }
      }

      // 4. Armar Payload final JSON
      final jsonPayload = {
        'is_updating': payload.isUpdating,
        'profile_id': payload.profileId,
        'product': {
          'id': payload.product.id,
          'name': payload.product.name,
          'description': payload.product.description,
          'category_id': payload.product.categoryId,
          'is_active': payload.product.isActive,
          'details': payload.product.details,
          'product_type': payload.product.productType,
          'stock_control': payload.product.stockControl,
          'uses_batches': payload.product.usesBatches,
        },
        'removed_variant_ids': payload.removedVariantIds,
        'images': productImagesJson,
        'variants': variantsJson,
        'ingredients_enabled': payload.ingredientsEnabled,
        'ingredients': ingredientsJson,
      };

      // 5. Enviar JSON al RPC atómico
      await _unwrap(repository.saveProductComplete(jsonPayload));

      return right(null);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
