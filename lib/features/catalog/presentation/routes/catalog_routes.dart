import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/active_ingredients_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/attributes_management_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/categories_management_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_loader.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

class CatalogRoutes {
  static List<RouteBase> topLevelRoutes(AuthCubit authCubit) => [
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id'];
            final variantId = state.uri.queryParameters['variantId'];
            final extra = state.extra;
            final ProductEntity? product =
                extra is ProductEntity ? extra : null;

            final role = authCubit.state.currentUser?.role;
            final isAdmin = role == AppRoles.admin;

            if (product != null) {
              return ProductDetailScreen(
                product: product,
                isAdmin: isAdmin,
                initialVariantId: variantId,
              );
            }

            if (productId != null) {
              return ProductLoader(
                productId: productId,
                isAdmin: isAdmin,
                initialVariantId: variantId,
              );
            }

            return const Scaffold(
              body: Center(child: Text('Producto no encontrado')),
            );
          },
        ),
      ];

  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'active-ingredients',
          builder: (context, state) => const AdminLayout(
            title: 'Componentes Químicos',
            showBackButton: true,
            body: ActiveIngredientsScreen(),
          ),
        ),
        GoRoute(
          path: 'attributes',
          builder: (context, state) => const AdminLayout(
            title: 'Atributos de Variantes',
            showBackButton: true,
            body: AttributesManagementScreen(),
          ),
        ),
        GoRoute(
          path: 'categories',
          builder: (context, state) => const AdminLayout(
            title: 'Categorías',
            showBackButton: true,
            body: CategoriesManagementScreen(),
          ),
        ),
        GoRoute(
          path: 'product-form',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return AdminLayout(
              title: args['productToEdit'] != null
                  ? 'Editar Producto'
                  : 'Nuevo Producto',
              showBackButton: true,
              body: ProductFormScreen(
                productToEdit: args['productToEdit'] is ProductEntity
                    ? args['productToEdit']
                    : null,
              ),
            );
          },
        ),
        GoRoute(
          path: 'product/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id'];
            final variantId = state.uri.queryParameters['variantId'];
            final extra = state.extra;
            final ProductEntity? product =
                extra is ProductEntity ? extra : null;

            if (product != null) {
              return ProductDetailScreen(
                product: product,
                isAdmin: true,
                initialVariantId: variantId,
              );
            }

            if (productId != null) {
              return ProductLoader(
                productId: productId,
                isAdmin: true,
                initialVariantId: variantId,
              );
            }

            return const Scaffold(
              body: Center(child: Text('Producto no encontrado')),
            );
          },
        ),
      ];

  static List<RouteBase> get customerRoutes => [
        GoRoute(
          path: 'product/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id'];
            final variantId = state.uri.queryParameters['variantId'];
            final extra = state.extra;
            final ProductEntity? product =
                extra is ProductEntity ? extra : null;

            if (product != null) {
              return ProductDetailScreen(
                product: product,
                isAdmin: false,
                initialVariantId: variantId,
              );
            }

            if (productId != null) {
              return ProductLoader(
                productId: productId,
                isAdmin: false,
                initialVariantId: variantId,
              );
            }

            return const Scaffold(
              body: Center(child: Text('Producto no encontrado')),
            );
          },
        ),
      ];
}
