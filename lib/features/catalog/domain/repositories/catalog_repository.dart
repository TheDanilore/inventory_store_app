import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
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
  Future<Either<Failure, CategoryEntity>> createCategory({required String name, String? description, required bool isActive});
  Future<Either<Failure, void>> updateCategory({required String id, required String name, String? description, required bool isActive});
  Future<Either<Failure, void>> deleteCategory(String id);
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
  Future<Either<Failure, void>> setProductActive({required String productId, required bool isActive});

  
  // Variantes (Lectura)
  Future<Either<Failure, ProductVariantEntity?>> getVariantById(String variantId);
  Future<Either<Failure, Map<String, int>>> getStockByVariant(String productId);
  Future<Either<Failure, List<VariantDraftModel>>> getVariantsDrafts(String productId);
  
  // Atributos y Componentes Activos
  Future<Either<Failure, Map<String, dynamic>>> createAttribute(String name);
  Future<Either<Failure, void>> updateAttribute(String id, String name);
  Future<Either<Failure, void>> deleteAttribute(String id);
  Future<Either<Failure, Map<String, dynamic>>> createAttributeValue(String attributeId, String value);
  Future<Either<Failure, void>> updateAttributeValue(String valueId, String value);
  Future<Either<Failure, void>> deleteAttributeValue(String valueId);
  Future<Either<Failure, List<Map<String, dynamic>>>> getAttributes();
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductIngredients(String productId);
  Future<Either<Failure, List<ActiveIngredientEntity>>> searchIngredients(String term);
  Future<Either<Failure, ActiveIngredientEntity>> createIngredient(String name);
  Future<Either<Failure, void>> updateIngredient(String id, String name);
  Future<Either<Failure, void>> deleteIngredient(String id);
  Future<Either<Failure, List<ActiveIngredientEntity>>> getIngredients({String? searchQuery, int limit = 20, int offset = 0});

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
  
  
  // Mutaciones complejas
  Future<Either<Failure, String>> saveProductMaster(ProductEntity product, String? profileId);
  Future<Either<Failure, String>> saveVariant({required String productId, required Map<String, dynamic> variantData, String? variantId});
  Future<Either<Failure, void>> saveVariantAttributes(String variantId, List<String> attributeValueIds);
  Future<Either<Failure, String?>> getFirstVariantId(String productId);
  
  Future<Either<Failure, String?>> fetchCurrentProfileId();
  Future<Either<Failure, bool>> toggleWishlist(String productId, String profileId, bool currentState);
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAdminFinancialData(String productId);
  Future<Either<Failure, ({List<Map<String, dynamic>> stocks, List<Map<String, dynamic>> batches, List<ProductImageModel> images, List<ProductVariantModel> variants, List<Map<String, dynamic>> reviews, List<Map<String, dynamic>> ingredients})>> fetchProductExtraData(String productId);

  
  Future<Either<Failure, Map<String, int>>> loadStockByVariant(String productId);
  Future<Either<Failure, List<Map<String, dynamic>>>> loadActiveVariants(String productId);
  Future<Either<Failure, Map<String, List<ProductVariantModel>>>> fetchVariantsByProductIds(List<String> productIds);
  Future<Either<Failure, Map<String, int>>> fetchVariantStockByVariantIds(List<String> variantIds);

  // Misc
  Future<Either<Failure, bool>> checkWishlistState(String productId, String profileId);
  Future<Either<Failure, void>> clearCache();
}
