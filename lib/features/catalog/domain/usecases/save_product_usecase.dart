import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

class SaveProductPayload {
  final ProductEntity product;
  final String? profileId;
  final bool isUpdating;

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
    required this.profileId,
    required this.isUpdating,
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
  final CatalogRepository repository;

  SaveProductUseCase(this.repository);

  Future<T> _unwrap<T>(Future<Either<Failure, T>> future) async {
    final res = await future;
    return res.fold((f) => throw Exception(f.message), (r) => r);
  }

  Future<Either<Failure, void>> call(SaveProductPayload payload) async {
    try {
      final String productId = await _unwrap(
        repository.saveProductMaster(payload.product, payload.profileId),
      );

      // Imágenes del Producto
      final imagesPayload = <Map<String, dynamic>>[];
      for (var i = 0; i < payload.images.length; i++) {
        final item = payload.images[i];
        final isMain = (i == 0);

        if (item.existingId != null) {
          imagesPayload.add({
            'id': item.existingId,
            'product_id': productId,
            'image_url': item.existingUrl,
            'display_order': i,
            'is_main': isMain,
          });
        } else if (item.newBytes != null) {
          final url = await _unwrap(
            repository.uploadImageToStorage(item.newBytes!, 'productos'),
          );
          if (url != null) {
            imagesPayload.add({
              'product_id': productId,
              'image_url': url,
              'display_order': i,
              'is_main': isMain,
            });
          }
        }
      }

      if (imagesPayload.isNotEmpty) {
        await _unwrap(repository.syncProductImages(imagesPayload));
      }

      // Variantes Eliminadas
      for (final variantId in payload.removedVariantIds) {
        await _unwrap(repository.deactivateVariant(variantId));
      }

      // Variantes
      String primaryVariantId = '';

      if (payload.variants.isEmpty) {
        if (payload.isUpdating) {
          final vid = await _unwrap(repository.getFirstVariantId(productId));
          if (vid != null) {
            primaryVariantId = vid;
            await _unwrap(
              repository.saveVariantAttributes(primaryVariantId, []),
            );
          }
        } else {
          final variantData = {
            'sale_price': payload.product.salePrice,
            'wholesale_price': payload.product.wholesalePrice,
            'wholesale_min_quantity': payload.product.wholesaleMinQuantity,
            'is_active': true,
          };
          primaryVariantId = await _unwrap(
            repository.saveVariant(
              productId: productId,
              variantData: variantData,
            ),
          );
          await _unwrap(repository.saveVariantAttributes(primaryVariantId, []));
        }
      } else {
        for (var i = 0; i < payload.variants.length; i++) {
          final draft = payload.variants[i];
          final variantData = {
            'sku': draft.sku,
            'unit_cost': draft.unitCost,
            'sale_price': draft.salePrice,
            'wholesale_price': draft.wholesalePrice,
            'wholesale_min_quantity': draft.wholesaleMinQuantity,
            'reorder_point': draft.reorderPoint,
            'is_active': draft.isActive,
          };

          final vId = await _unwrap(
            repository.saveVariant(
              productId: productId,
              variantData: variantData,
              variantId: draft.id,
            ),
          );

          if (i == 0) primaryVariantId = vId;
          await _unwrap(
            repository.saveVariantAttributes(vId, draft.attributeValueIds),
          );

          if (draft.id != null && draft.clearImages) {
            await _unwrap(repository.clearVariantImages(vId));
          }

          if (draft.newImageBytes != null) {
            final url = await _unwrap(
              repository.uploadImageToStorage(
                draft.newImageBytes!,
                'variantes',
              ),
            );
            if (url != null) {
              await _unwrap(
                repository.syncProductImages([
                  {
                    'product_id': productId,
                    'variant_id': vId,
                    'image_url': url,
                    'display_order': 0,
                    'is_main': false,
                  },
                ]),
              );
            }
          }
        }
      }

      // Ingredientes
      if (payload.ingredientsEnabled) {
        await _unwrap(repository.clearProductIngredients(productId));

        for (final ing in payload.ingredients) {
          final ingPayload = {
            'product_id': productId,
            'ingredient_id': ing.ingredientId,
            'concentration': ing.concentration,
            'unit': ing.unit,
          };
          await _unwrap(repository.insertProductIngredient(ingPayload));
        }
      } else {
        await _unwrap(repository.clearProductIngredients(productId));
      }

      return right(null);
    } catch (e) {
      return left(Failure.from(e));
    }
  }
}
