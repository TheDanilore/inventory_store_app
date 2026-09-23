import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_form_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/delete_product_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/export_catalog_pdf_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_brands_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_stock_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';

class MockGetProductsUC implements GetProductsUC {
  int callCount = 0;
  List<ProductEntity> returnProducts = [];

  @override
  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>> call({
    String? searchQuery,
    String? categoryId,
    String? brandId,
    bool? isActive,
    bool searchByIngredient = false,
    bool forCustomer = false,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = false,
    CatalogStockFilter? stockFilter = CatalogStockFilter.all,
    CatalogSortOption? sortOption = CatalogSortOption.recent,
  }) async {
    callCount++;
    return Right((products: returnProducts, totalCount: returnProducts.length));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSetProductActiveUC implements SetProductActiveUC {
  int callCount = 0;
  @override
  Future<Either<Failure, void>> call(String productId, bool isActive) async {
    callCount++;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockDeleteProductUC implements DeleteProductUC {
  int callCount = 0;
  @override
  Future<Either<Failure, void>> call(String id) async {
    callCount++;
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyGetCategoriesUC implements GetCategoriesUC {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyGetBrandsUC implements GetBrandsUC {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyClearCatalogCacheUC implements ClearCatalogCacheUC {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyExportCatalogPdfUC implements ExportCatalogPdfUseCase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class DummyGetProductStockUC implements GetProductStockUC {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProductEntity _createDummyProduct(String id, String name, {bool isActive = true}) {
  return ProductEntity(
    id: id,
    name: name,
    isActive: isActive,
    stockControl: true,
    usesBatches: false,
    productType: 'STANDARD',
    details: {},
    images: [],
    totalStock: 10,
    productVariants: [],
    warehouseStockBatches: [],
  );
}

void main() {
  late MockGetProductsUC mockGetProductsUC;
  late MockSetProductActiveUC mockSetActiveUC;
  late MockDeleteProductUC mockDeleteProductUC;
  late AdminCatalogCubit cubit;

  setUp(() {
    mockGetProductsUC = MockGetProductsUC();
    mockSetActiveUC = MockSetProductActiveUC();
    mockDeleteProductUC = MockDeleteProductUC();

    mockGetProductsUC.returnProducts = [
      _createDummyProduct('p-1', 'Paracetamol 500mg'),
      _createDummyProduct('p-2', 'Ibuprofeno 400mg'),
    ];

    cubit = AdminCatalogCubit(
      getCategoriesUC: DummyGetCategoriesUC(),
      getBrandsUC: DummyGetBrandsUC(),
      getProductsUC: mockGetProductsUC,
      setProductActiveUC: mockSetActiveUC,
      deleteProductUC: mockDeleteProductUC,
      clearCatalogCacheUC: DummyClearCatalogCacheUC(),
      exportCatalogPdfUC: DummyExportCatalogPdfUC(),
      getProductStockUC: DummyGetProductStockUC(),
    );
  });

  tearDown(() {
    cubit.close();
  });

  test('L1 cache avoids repeated network calls for identical queries and pages', () async {
    // 1st fetch: Cache MISS -> calls usecase
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 1);
    expect(cubit.state.products.length, 2);

    // 2nd fetch with same state: Cache HIT -> does NOT call usecase
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 1); // Still 1!
    expect(cubit.state.products.length, 2);
  });

  test('refreshProducts(forceRefresh: true) invalidates L1 cache and re-queries', () async {
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 1);

    // Force refresh clears cache
    await cubit.refreshProducts(forceRefresh: true);
    expect(mockGetProductsUC.callCount, 2);
  });

  test('toggleProductActive invalidates cache and updates local product state', () async {
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 1);

    final product = cubit.state.products.first;
    final toggled = await cubit.toggleProductActive(product);
    expect(toggled, true);
    expect(mockSetActiveUC.callCount, 1);
    expect(cubit.state.products.first.isActive, false);

    // Subsequent refresh queries again because cache was invalidated
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 2);
  });

  test('deleteProduct invalidates cache and removes product from local state', () async {
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 1);
    expect(cubit.state.products.length, 2);

    final deleted = await cubit.deleteProduct('p-1');
    expect(deleted, true);
    expect(mockDeleteProductUC.callCount, 1);
    expect(cubit.state.products.length, 1);
    expect(cubit.state.products.first.id, 'p-2');

    // Subsequent refresh queries again because cache was invalidated
    await cubit.refreshProducts();
    expect(mockGetProductsUC.callCount, 2);
  });
}
