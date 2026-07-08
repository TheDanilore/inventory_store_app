import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetProductImagesUC {
  final CatalogRepository repository;
  GetProductImagesUC(this.repository);
  Future<Either<Failure, List<ProductImageEntity>>> call(String productId) async {
    return await repository.getProductImages(productId);
  }
}

@lazySingleton
class UploadImageToStorageUC {
  final CatalogRepository repository;
  UploadImageToStorageUC(this.repository);
  Future<Either<Failure, String?>> call(Uint8List bytes, String folder) async {
    return await repository.uploadImageToStorage(bytes, folder);
  }
}

@lazySingleton
class DeleteProductImageUC {
  final CatalogRepository repository;
  DeleteProductImageUC(this.repository);
  Future<Either<Failure, void>> call(String id, String imageUrl) async {
    return await repository.deleteProductImage(id, imageUrl);
  }
}

@lazySingleton
class SyncProductImagesUC {
  final CatalogRepository repository;
  SyncProductImagesUC(this.repository);
  Future<Either<Failure, void>> call(List<Map<String, dynamic>> payload) async {
    return await repository.syncProductImages(payload);
  }
}

@lazySingleton
class ClearVariantImagesUC {
  final CatalogRepository repository;
  ClearVariantImagesUC(this.repository);
  Future<Either<Failure, void>> call(String variantId) async {
    return await repository.clearVariantImages(variantId);
  }
}
