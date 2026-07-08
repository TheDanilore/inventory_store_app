import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/variant_draft_model.dart'; // Mantener Draft model por ahora si es necesario para el formulario

abstract class CatalogRepository {
  // Categorías
  Future<Either<Failure, List<CategoryEntity>>> getCategories({bool activeOnly = false});

  // Productos (Lectura)
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>> getProducts({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = true,
  });
  Future<Either<Failure, ProductEntity?>> getProductById(String id);
  Future<Either<Failure, Map<String, int>>> getProductStock({List<String>? productIds});
  
  // Variantes (Lectura)
  Future<Either<Failure, ProductVariantEntity?>> getVariantById(String variantId);
  Future<Either<Failure, Map<String, int>>> getStockByVariant(String productId);
  Future<Either<Failure, List<VariantDraftModel>>> getVariantsDrafts(String productId);
  
  // Atributos y Componentes Activos
  Future<Either<Failure, List<Map<String, dynamic>>>> getAttributes();
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductIngredients(String productId);
  Future<Either<Failure, List<ActiveIngredientEntity>>> searchIngredients(String term);
  Future<Either<Failure, ActiveIngredientEntity>> createIngredient(String name);

  // Imágenes
  Future<Either<Failure, List<ProductImageEntity>>> getProductImages(String productId);
  Future<Either<Failure, String?>> uploadImageToStorage(Uint8List bytes, String folder);
  Future<Either<Failure, void>> deleteProductImage(String id, String imageUrl);
  Future<Either<Failure, void>> syncProductImages(List<Map<String, dynamic>> payload);

  // Operaciones de Escritura / Mutación (Formulario)
  Future<Either<Failure, void>> deleteVariant(String variantId);
  Future<Either<Failure, void>> deactivateVariant(String variantId);
  Future<Either<Failure, bool>> hasVariantSales(String variantId);
  Future<Either<Failure, void>> clearVariantImages(String variantId);
  Future<Either<Failure, void>> clearProductIngredients(String productId);
  Future<Either<Failure, void>> insertProductIngredient(Map<String, dynamic> payload);
  
  // Misc
  Future<Either<Failure, bool>> checkWishlistState(String productId, String profileId);
  Future<Either<Failure, void>> clearCache();
}
