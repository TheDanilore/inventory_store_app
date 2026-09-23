import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/attributes/attributes_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/active_ingredients_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/admin_products_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/attributes_management_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/brands_management_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/categories_management_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/bulk_import_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_loader.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/full_screen_gallery.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/brands/brands_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/categories/categories_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/ingredients/ingredients_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';

class CatalogRoutes {
  static List<RouteBase> topLevelRoutes(AuthCubit authCubit) => [
    GoRoute(
      path: '/gallery',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final imageUrls =
            (extra?['imageUrls'] as List<dynamic>?)?.cast<String>() ?? [];
        final initialIndex = extra?['initialIndex'] as int? ?? 0;
        return FullScreenGallery(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        );
      },
    ),
  ];

  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/active-ingredients',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<IngredientsCubit>()..loadIngredients(),
            child: const ActiveIngredientsScreen(),
          ),
    ),
    GoRoute(
      path: '/attributes',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<AttributesCubit>()..loadAttributes(),
            child: const AttributesManagementScreen(),
          ),
    ),
    GoRoute(
      path: '/categories',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<CategoriesCubit>()..loadCategories(),
            child: const CategoriesManagementScreen(),
          ),
    ),
    GoRoute(
      path: '/brands',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<BrandsCubit>()..loadBrands(),
            child: const BrandsManagementScreen(),
          ),
    ),
    GoRoute(
      path: '/products',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<AdminCatalogCubit>()..loadInitialData(),
            child: const AdminProductsScreen(),
          ),
    ),
    GoRoute(
      path: '/products/bulk-import',
      builder:
          (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(create: (_) => sl<AdminCatalogCubit>()),
              BlocProvider(create: (_) => sl<BulkImportCubit>()),
            ],
            child: const BulkImportScreen(),
          ),
    ),
    GoRoute(
      path: '/products/product-form',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ProductFormScreen(
          productToEdit:
              args['productToEdit'] is ProductEntity
                  ? args['productToEdit']
                  : null,
        );
      },
    ),
    GoRoute(
      path: '/products/product-form/:id',
      builder: (context, state) {
        final productId = state.pathParameters['id'];
        final args = state.extra as Map<String, dynamic>? ?? {};
        final ProductEntity? productToEdit =
            args['productToEdit'] is ProductEntity
                ? args['productToEdit']
                : null;
        return ProductFormScreen(
          productId: productId,
          productToEdit: productToEdit,
        );
      },
    ),
    GoRoute(
      path: '/product/:id',
      builder: (context, state) {
        final productId = state.pathParameters['id'];
        final variantId = state.uri.queryParameters['variantId'];
        final extra = state.extra;
        final ProductEntity? product = extra is ProductEntity ? extra : null;

        if (product != null) {
          return ProductDetailScreen(
            product: product,
            initialVariantId: variantId,
          );
        }

        if (productId != null) {
          return ProductLoader(
            productId: productId,
            initialVariantId: variantId,
          );
        }

        return const Scaffold(
          body: Center(child: Text('Producto no encontrado')),
        );
      },
    ),
  ];

  static List<RouteBase> get customerRoutes => [];
}
