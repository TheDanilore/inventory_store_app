import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_draft_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';

abstract class ProductsRepository {
  // Productos (Lectura)
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>>
  getProducts({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    bool searchByIngredient = false,
    bool forCustomer = false,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = true,
    CatalogStockFilter? stockFilter,
    CatalogSortOption? sortOption,
  });
  Future<Either<Failure, ProductEntity?>> getProductById(String id);
  Future<Either<Failure, Map<String, int>>> getProductStock({
    List<String>? productIds,
  });
  Future<Either<Failure, void>> setProductActive({
    required String productId,
    required bool isActive,
  });
  Future<Either<Failure, Map<String, dynamic>>> getActiveProductsAndVariants();

  // Variantes (Lectura)
  Future<Either<Failure, ProductVariantEntity?>> getVariantById(
    String variantId,
  );
  Future<Either<Failure, Map<String, int>>> getStockByVariant(String productId);
  Future<Either<Failure, List<VariantDraftEntity>>> getVariantsDrafts(
    String productId,
  );

  // Atributos
  Future<Either<Failure, AttributeEntity>> createAttribute(String name);
  Future<Either<Failure, void>> updateAttribute(String id, String name);
  Future<Either<Failure, void>> deleteAttribute(String id);
  Future<Either<Failure, AttributeValueEntity>> createAttributeValue(
    String attributeId,
    String value,
  );
  Future<Either<Failure, void>> updateAttributeValue(
    String valueId,
    String value,
  );
  Future<Either<Failure, void>> deleteAttributeValue(String valueId);

  // Búsqueda para el UI
  Future<Either<Failure, List<Map<String, dynamic>>>> searchAttributes(
    String term,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> searchAttributeValues(
    String attributeId,
    String term,
  );
  Future<Either<Failure, Map<String, dynamic>>> getOrCreateAttribute(
    String name,
  );
  Future<Either<Failure, Map<String, dynamic>>> getOrCreateAttributeValue(
    String attributeId,
    String value,
  );
  Future<Either<Failure, List<AttributeEntity>>> getAttributes();

  // Búsqueda Optimizada para Entradas
  Future<Either<Failure, List<Map<String, dynamic>>>> searchProductsForEntry(
    String term,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  );

  // Imágenes
  Future<Either<Failure, List<ProductImageEntity>>> getProductImages(
    String productId,
  );
  Future<Either<Failure, String?>> uploadImageToStorage(
    Uint8List bytes,
    String folder,
  );
  Future<Either<Failure, void>> deleteProductImage(String id, String imageUrl);
  Future<Either<Failure, void>> syncProductImages(
    List<Map<String, dynamic>> payload,
  );

  // Operaciones de Escritura / Mutación (Formulario)
  Future<Either<Failure, void>> deleteVariant(String variantId);
  Future<Either<Failure, void>> deactivateVariant(String variantId);
  Future<Either<Failure, bool>> hasVariantSales(String variantId);
  Future<Either<Failure, void>> clearVariantImages(String variantId);

  // Reviews
  Future<Either<Failure, bool>> checkCustomerPurchase(
    String productId,
    String profileId,
  );
  Future<Either<Failure, void>> addProductReview({
    required String productId,
    required String profileId,
    required String userName,
    required int rating,
    String? comment,
  });

  // Mutaciones complejas
  Future<Either<Failure, String>> saveProductMaster(
    ProductEntity product,
    String? profileId,
  );
  Future<Either<Failure, String>> saveVariant({
    required String productId,
    required Map<String, dynamic> variantData,
    String? variantId,
    String? profileId,
  });
  Future<Either<Failure, void>> saveVariantAttributes(
    String variantId,
    List<String> attributeValueIds,
  );
  Future<Either<Failure, String?>> getFirstVariantId(String productId);

  Future<Either<Failure, bool>> toggleWishlist(
    String productId,
    String profileId,
    bool currentState,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> fetchAdminFinancialData(
    String productId,
  );
  Future<
    Either<
      Failure,
      ({
        List<Map<String, dynamic>> stocks,
        List<Map<String, dynamic>> batches,
        List<ProductImageEntity> images,
        List<ProductVariantEntity> variants,
        List<Map<String, dynamic>> reviews,
        List<Map<String, dynamic>> ingredients,
      })
    >
  >
  fetchProductExtraData(String productId);

  Future<Either<Failure, Map<String, int>>> loadStockByVariant(
    String productId,
  );
  Future<Either<Failure, List<Map<String, dynamic>>>> loadActiveVariants(
    String productId,
  );
  Future<Either<Failure, Map<String, List<ProductVariantEntity>>>>
  fetchVariantsByProductIds(List<String> productIds);
  Future<Either<Failure, Map<String, int>>> fetchVariantStockByVariantIds(
    List<String> variantIds, {
    String? warehouseId,
  });

  // Misc
  Future<Either<Failure, bool>> checkWishlistState(
    String productId,
    String profileId,
  );
  Future<Either<Failure, void>> clearCache();

  // Guardado Atómico (RPC)
  Future<Either<Failure, void>> saveProductComplete(SaveProductPayload payload);
}

class SaveProductPayload {
  final ProductEntity product;
  final String? profileId;
  final bool isUpdating;
  final double? baseSalePrice;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQuantity;
  final List<ImagePayload> images;
  final List<String> removedVariantIds;
  final List<VariantPayload> variants;
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
