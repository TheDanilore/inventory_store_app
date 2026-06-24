import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';

// Proveedores
import 'package:inventory_store_app/providers/auth_provider.dart';

// Pantallas Comunes
import 'package:inventory_store_app/screens/splash_screen.dart';
import 'package:inventory_store_app/screens/auth/login_screen.dart';
import 'package:inventory_store_app/screens/shared/product_detail_screen.dart';
import 'package:inventory_store_app/screens/shared/widgets/full_screen_gallery.dart';

// Pantallas Cliente
import 'package:inventory_store_app/screens/customer/customer_main_screen.dart';
import 'package:inventory_store_app/screens/customer/customer_cart_screen.dart';
import 'package:inventory_store_app/screens/customer/address_management_screen.dart';
import 'package:inventory_store_app/screens/customer/address_config_screen.dart';
import 'package:inventory_store_app/screens/customer/customer_orders_screen.dart';
import 'package:inventory_store_app/screens/customer/points_screen.dart';
import 'package:inventory_store_app/screens/customer/wishlist_screen.dart';
import 'package:inventory_store_app/screens/auth/profile_screen.dart';

// Pantallas Admin
import 'package:inventory_store_app/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/screens/admin/active_ingredients_screen.dart';
import 'package:inventory_store_app/screens/admin/attributes_management_screen.dart';
import 'package:inventory_store_app/screens/admin/business_info_screen.dart';
import 'package:inventory_store_app/screens/admin/categories_management_screen.dart';
import 'package:inventory_store_app/screens/admin/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/screens/admin/customer_credits_screen.dart';
import 'package:inventory_store_app/screens/admin/customer_detail_screen.dart';
import 'package:inventory_store_app/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/screens/admin/dashboard_screen.dart';
import 'package:inventory_store_app/screens/admin/financial_accounts_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_entries_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_exits_screen.dart';
import 'package:inventory_store_app/screens/admin/inventory_screen.dart';
import 'package:inventory_store_app/screens/admin/kardex_screen.dart';
import 'package:inventory_store_app/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/screens/admin/points_settings_screen.dart';
import 'package:inventory_store_app/screens/admin/pos_checkout_screen.dart';
import 'package:inventory_store_app/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/screens/admin/purchase_order_form_screen.dart';
import 'package:inventory_store_app/screens/admin/purchase_orders_screen.dart';
import 'package:inventory_store_app/screens/admin/supplier_credit_movements_screen.dart';
import 'package:inventory_store_app/screens/admin/supplier_credits_screen.dart';
import 'package:inventory_store_app/screens/admin/suppliers_screen.dart';
import 'package:inventory_store_app/screens/admin/user_form_screen.dart';
import 'package:inventory_store_app/screens/admin/users_management_screen.dart';
import 'package:inventory_store_app/screens/admin/warehouses_management_screen.dart';
import 'package:inventory_store_app/shared/constants/app_roles.dart';

// Juegos
import 'package:inventory_store_app/screens/customer/games/claw_machine_screen.dart';
import 'package:inventory_store_app/screens/customer/games/coin_catcher_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/dodge_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/memorama_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/pinata_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/stack_game_screen.dart';
import 'package:inventory_store_app/screens/customer/games/super_salto_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

// ─────────────────────────────────────────────────────────────────────────────
// Widget auxiliar: carga el producto por ID sin relanzar el Future en rebuilds
// ─────────────────────────────────────────────────────────────────────────────
class _ProductLoader extends StatefulWidget {
  final String productId;
  final bool isAdmin;
  final String? initialVariantId;
  const _ProductLoader({
    required this.productId,
    required this.isAdmin,
    this.initialVariantId,
  });

  @override
  State<_ProductLoader> createState() => _ProductLoaderState();
}

class _ProductLoaderState extends State<_ProductLoader> {
  late final Future<ProductModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = CatalogService().getProductById(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Producto no encontrado')),
            body: const Center(
              child: Text('El producto no existe o fue eliminado.'),
            ),
          );
        }
        return ProductDetailScreen(
          product: snapshot.data!,
          isAdmin: widget.isAdmin,
          initialVariantId: widget.initialVariantId,
        );
      },
    );
  }
}

class AppRouter {
  // ── Deep link preservation ───────────────────────────────────────────────
  static String? _pendingDeepLink;

  /// Llamar desde main() ANTES de runApp() para capturar la ruta inicial.
  static void captureInitialRoute() {
    try {
      final uri = Uri.base;
      final path = uri.path;
      if (path.isNotEmpty && path != '/' && path != '/login') {
        _pendingDeepLink = path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
        debugPrint('AppRouter: deep link capturado → $_pendingDeepLink');
      }
    } catch (_) {
      // En móvil Uri.base no existe; simplemente ignoramos
    }
  }

  /// Crea el GoRouter recibiendo el [AuthProvider] directamente.
  ///
  /// IMPORTANTE: Esta firma reemplaza la anterior `createRouter(BuildContext context)`.
  /// El provider se pasa como parámetro para que el router pueda crearse
  /// FUERA del árbol de widgets (en main(), antes de runApp()), eliminando
  /// así el crash "DartError: Assertion failed" causado por la recreación
  /// del GoRouter en rebuilds de MyApp.
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      restorationScopeId: 'router',
      initialLocation: '/',
      refreshListenable: authProvider,
      errorBuilder:
          (context, state) => Scaffold(
            appBar: AppBar(title: const Text('Página no encontrada')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.link_off_rounded,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Esta página no existe',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.matchedLocation,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Volver al inicio'),
                  ),
                ],
              ),
            ),
          ),
      redirect: (context, state) {
        final isSessionReady = authProvider.isSessionReady;
        final role = authProvider.currentUserRole;

        final currentPath = state.matchedLocation;
        final isSplash = currentPath == '/';
        final isLogin = currentPath == '/login';

        // ── Paso 1: Sesión aún cargando -> mostrar splash siempre ─────────
        if (!isSessionReady) {
          if (!isSplash && _pendingDeepLink == null) {
            final uri = state.uri.toString();
            if (uri != '/login') {
              _pendingDeepLink = uri;
            }
          }
          return isSplash ? null : '/';
        }

        // ── Paso 2: Sesión lista → restaurar deep link pendiente ──────────
        if (isSplash && _pendingDeepLink != null) {
          final target = _pendingDeepLink!;
          _pendingDeepLink = null;

          if (target.startsWith('/admin') && role == AppRoles.admin) {
            return target;
          }
          if (target.startsWith('/customer')) {
            return target;
          }
        }

        // ── Rutas públicas de /customer ───────────────────────────────────
        final isPublicCustomerRoute =
            currentPath == '/customer' ||
            currentPath.startsWith('/customer/product/');

        // ── Paso 3: Sin sesión ───────────────────────────────────────────
        if (role == null) {
          if (isSplash) return '/customer';
          if (isLogin) return null;
          if (isPublicCustomerRoute) return null;
          return '/login';
        }

        // ── Paso 4: Con sesión, en pantalla de auth ──────────────────────
        if (isSplash || isLogin) {
          return role == AppRoles.admin ? '/admin' : '/customer';
        }

        // ── Paso 5: Proteger rutas de admin ──────────────────────────────
        if (currentPath.startsWith('/admin') && role != AppRoles.admin) {
          return '/customer';
        }

        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // ADMIN ROUTES
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminCatalogScreen(),
          routes: [
            GoRoute(
              path: 'profile',
              builder:
                  (context, state) =>
                      const ProfileScreen(openedFromAdmin: true),
            ),
            GoRoute(
              path: 'active-ingredients',
              builder: (context, state) => const ActiveIngredientsScreen(),
            ),
            GoRoute(
              path: 'attributes',
              builder: (context, state) => const AttributesManagementScreen(),
            ),
            GoRoute(
              path: 'business-info',
              builder: (context, state) => const BusinessInfoScreen(),
            ),
            GoRoute(
              path: 'categories',
              builder: (context, state) => const CategoriesManagementScreen(),
            ),
            GoRoute(
              path: 'customer-credit-movements/:creditId',
              builder: (context, state) {
                final creditId = state.pathParameters['creditId'] ?? '';
                final args = state.extra as Map<String, dynamic>? ?? {};
                return CustomerCreditMovementsScreen(
                  creditId: creditId,
                  customerName:
                      args['customerName'] ??
                      state.uri.queryParameters['name'] ??
                      '',
                  currentDebt:
                      args['currentDebt'] ??
                      double.tryParse(
                        state.uri.queryParameters['debt'] ?? '0',
                      ) ??
                      0.0,
                  creditLimit:
                      args['creditLimit'] ??
                      double.tryParse(
                        state.uri.queryParameters['limit'] ?? '0',
                      ) ??
                      0.0,
                );
              },
            ),
            GoRoute(
              path: 'customer-credits',
              builder: (context, state) => const CustomerCreditsScreen(),
            ),
            GoRoute(
              path: 'customer-detail/:id',
              builder: (context, state) {
                final customer = state.extra;
                final customerId = state.pathParameters['id'] ?? '';
                if (customer == null && customerId.isEmpty) {
                  return Scaffold(
                    appBar: AppBar(title: const Text('Error')),
                    body: const Center(child: Text('Cliente no encontrado.')),
                  );
                }
                return CustomerDetailScreen(customer: customer as dynamic);
              },
            ),
            GoRoute(
              path: 'customers',
              builder: (context, state) => const CustomersScreen(),
            ),
            GoRoute(
              path: 'dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: 'financial-accounts',
              builder: (context, state) => const FinancialAccountsScreen(),
            ),
            GoRoute(
              path: 'inventory-entries',
              builder: (context, state) => const InventoryEntriesScreen(),
            ),
            GoRoute(
              path: 'inventory-entry-form',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return InventoryEntryFormScreen(
                  purchaseOrderId:
                      args['purchaseOrderId'] ??
                      state.uri.queryParameters['purchaseOrderId'],
                  prefillItems: args['prefillItems'],
                  prefillSupplierId: args['prefillSupplierId'],
                  prefillSupplierName: args['prefillSupplierName'],
                  prefillDocumentType: args['prefillDocumentType'],
                  prefillDocumentNumber: args['prefillDocumentNumber'],
                  prefillDocumentDate: args['prefillDocumentDate'],
                );
              },
            ),
            GoRoute(
              path: 'inventory-exit-form',
              builder: (context, state) => const InventoryExitFormScreen(),
            ),
            GoRoute(
              path: 'inventory-exits',
              builder: (context, state) => const InventoryExitsScreen(),
            ),
            GoRoute(
              path: 'inventory',
              builder: (context, state) => const InventoryScreen(),
            ),
            GoRoute(
              path: 'kardex',
              builder: (context, state) => const KardexScreen(),
            ),
            GoRoute(
              path: 'orders',
              builder: (context, state) => const OrdersScreen(),
            ),
            GoRoute(
              path: 'points-settings',
              builder: (context, state) => const PointsSettingsScreen(),
            ),
            GoRoute(
              path: 'pos-checkout',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return PosCheckoutScreen(
                  onSaleCompleted: args['onSaleCompleted'],
                );
              },
            ),
            GoRoute(
              path: 'product-form',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>? ?? {};
                return ProductFormScreen(
                  productToEdit: args['productToEdit'] as ProductModel?,
                );
              },
            ),
            GoRoute(
              path: 'purchase-order-form',
              builder: (context, state) => const PurchaseOrderFormScreen(),
            ),
            GoRoute(
              path: 'purchase-orders',
              builder: (context, state) => const PurchaseOrdersScreen(),
            ),
            GoRoute(
              path: 'supplier-credit-movements/:creditId',
              builder: (context, state) {
                final creditId = state.pathParameters['creditId'] ?? '';
                final args = state.extra as Map<String, dynamic>? ?? {};
                return SupplierCreditMovementsScreen(
                  creditId: creditId,
                  supplierName:
                      args['supplierName'] ??
                      state.uri.queryParameters['name'] ??
                      '',
                  currentDebt:
                      args['currentDebt'] ??
                      double.tryParse(
                        state.uri.queryParameters['debt'] ?? '0',
                      ) ??
                      0.0,
                  creditLimit:
                      args['creditLimit'] ??
                      double.tryParse(
                        state.uri.queryParameters['limit'] ?? '0',
                      ) ??
                      0.0,
                );
              },
            ),
            GoRoute(
              path: 'supplier-credits',
              builder: (context, state) => const SupplierCreditsScreen(),
            ),
            GoRoute(
              path: 'suppliers',
              builder: (context, state) => const SuppliersScreen(),
            ),
            GoRoute(
              path: 'user-form',
              builder: (context, state) {
                final args = state.extra as Map<String, dynamic>?;
                if (args == null) {
                  return const UsersManagementScreen();
                }
                return UserFormScreen(
                  initialRole: args['initialRole'],
                  existingUser: args['existingUser'] as dynamic,
                );
              },
            ),
            GoRoute(
              path: 'users',
              builder: (context, state) => const UsersManagementScreen(),
            ),
            GoRoute(
              path: 'warehouses',
              builder: (context, state) => const WarehousesManagementScreen(),
            ),
            GoRoute(
              path: 'product/:id',
              builder: (context, state) {
                final productId = state.pathParameters['id'];
                final variantId = state.uri.queryParameters['variantId'];
                final product = state.extra as ProductModel?;
                if (product != null) {
                  return ProductDetailScreen(
                    product: product,
                    isAdmin: true,
                    initialVariantId: variantId,
                  );
                }
                if (productId == null) {
                  return const Scaffold(body: Center(child: Text('Error')));
                }
                return _ProductLoader(
                  productId: productId,
                  isAdmin: true,
                  initialVariantId: variantId,
                );
              },
            ),
          ],
        ),

        // CUSTOMER ROUTES
        GoRoute(
          path: '/customer',
          builder: (context, state) => const CustomerMainScreen(),
          routes: [
            GoRoute(
              path: 'profile',
              builder:
                  (context, state) =>
                      const ProfileScreen(openedFromAdmin: false),
            ),
            GoRoute(
              path: 'cart',
              builder: (context, state) => const CustomerCartScreen(),
            ),
            GoRoute(
              path: 'address',
              builder: (context, state) => const AddressManagementScreen(),
            ),
            GoRoute(
              path: 'orders',
              builder: (context, state) => const CustomerOrdersScreen(),
            ),
            GoRoute(
              path: 'points',
              builder: (context, state) => const PointsScreen(),
            ),
            GoRoute(
              path: 'wishlist',
              builder: (context, state) => const WishlistScreen(),
            ),
            GoRoute(
              path: 'address/config',
              builder:
                  (context, state) => AddressConfigScreen(
                    initialAddress: state.uri.queryParameters['initialAddress'],
                  ),
            ),
            // GAMES
            GoRoute(
              path: 'games/claw-machine/:profileId',
              builder:
                  (context, state) => ClawMachineScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/coin-catcher/:profileId',
              builder:
                  (context, state) => CoinCatcherGameScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/dodge/:profileId',
              builder:
                  (context, state) => DodgeGameScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/memorama/:profileId',
              builder:
                  (context, state) => MemoramaGameScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/pinata/:profileId',
              builder:
                  (context, state) => PinataGameScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/stack/:profileId',
              builder:
                  (context, state) => StackGameScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'games/super-salto/:profileId',
              builder:
                  (context, state) => SuperSaltoScreen(
                    profileId: state.pathParameters['profileId'] ?? '',
                  ),
            ),
            GoRoute(
              path: 'product/:id',
              builder: (context, state) {
                final productId = state.pathParameters['id'];
                final variantId = state.uri.queryParameters['variantId'];
                final product = state.extra as ProductModel?;
                if (product != null) {
                  return ProductDetailScreen(
                    product: product,
                    isAdmin: false,
                    initialVariantId: variantId,
                  );
                }
                if (productId == null) {
                  return const Scaffold(body: Center(child: Text('Error')));
                }
                return _ProductLoader(
                  productId: productId,
                  isAdmin: false,
                  initialVariantId: variantId,
                );
              },
            ),
          ],
        ),

        // SHARED ROUTES
        GoRoute(
          path: '/product/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id'];
            final variantId = state.uri.queryParameters['variantId'];
            final product = state.extra as ProductModel?;
            // Usamos el authProvider capturado en el closure (no context.read)
            // para evitar dependencia del contexto en rutas compartidas.
            final role = authProvider.currentUserRole;
            final isAdmin = role == AppRoles.admin;

            if (product != null) {
              return ProductDetailScreen(
                product: product,
                isAdmin: isAdmin,
                initialVariantId: variantId,
              );
            }

            if (productId == null || productId.isEmpty) {
              return const Scaffold(
                body: Center(
                  child: Text('Error: ID de producto no proporcionado.'),
                ),
              );
            }

            return _ProductLoader(
              productId: productId,
              isAdmin: isAdmin,
              initialVariantId: variantId,
            );
          },
        ),
        GoRoute(
          path: '/gallery',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            final imageUrls = args['imageUrls'] as List<String>? ?? [];
            final initialIndex = args['initialIndex'] as int? ?? 0;
            return FullScreenGallery(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
            );
          },
        ),
      ],
    );
  }
}
