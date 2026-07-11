import 'dart:async';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

// Proveedores
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';

// Pantallas Comunes
import 'package:inventory_store_app/features/auth/presentation/screens/splash_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/login_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/product_detail_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_detail/full_screen_gallery.dart';

// Pantallas Cliente
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/customer_catalog_screen.dart';

import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_cart_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/location_management_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/customer_orders_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/points_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/wishlist_screen.dart';
import 'package:inventory_store_app/features/auth/presentation/screens/profile_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';

// Pantallas Admin
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/admin_pos_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/all_cash_shifts_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/active_ingredients_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/attributes_management_screen.dart';
import 'package:inventory_store_app/features/app_config/presentation/screens/business_info_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/categories_management_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_credits_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customer_detail_screen.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/customers_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/top_customers_screen.dart';
import 'package:inventory_store_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:inventory_store_app/features/financial/presentation/screens/financial_accounts_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entries_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exits_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/kardex_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/orders_screen.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/orders_provider.dart';
import 'package:inventory_store_app/features/orders/data/repositories/orders_service.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/orders/order_detail_sheet.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/admin/points_settings_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/pos_checkout_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/product_form_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/purchase_order_form_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/purchase_orders_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/supplier_credit_movements_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/supplier_credits_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/suppliers_screen.dart';
import 'package:inventory_store_app/features/users/presentation/screens/user_form_screen.dart';
import 'package:inventory_store_app/features/users/presentation/screens/users_management_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/warehouses_management_screen.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

// Juegos
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/claw_machine_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/coin_catcher_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/dodge_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/memorama_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/pinata_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/stack_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/super_salto_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

// Widget auxiliar: carga el producto por ID sin relanzar el Future en rebuilds
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
  late final Future<ProductEntity?> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<CatalogRepository>()
        .getProductById(widget.productId)
        .then((res) => res.fold((l) => null, (r) => r));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductEntity?>(
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
  // Preservación de Deep Link
  static String? _pendingDeepLink;

  /// Llamar desde main() ANTES de runApp() para capturar la ruta inicial.
  static void captureInitialRoute() {
    try {
      final uri = Uri.base;
      final path = uri.path;
      if (path.isNotEmpty && path != '/' && path != '/login') {
        _pendingDeepLink = path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
        debugPrint('AppRouter: deep link capturado Ã¢â€ â€™ $_pendingDeepLink');
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
  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      restorationScopeId: 'router',
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
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
        final isSessionReady = authCubit.state.authStatus != AuthStatus.initial;
        final role = authCubit.state.currentUser?.role;

        final currentPath = state.matchedLocation;
        final isSplash = currentPath == '/';
        final isLogin = currentPath == '/login';

        // Paso 1: Sesión aún cargando -> mostrar splash siempre
        if (!isSessionReady) {
          if (!isSplash && _pendingDeepLink == null) {
            final uri = state.uri.toString();
            if (uri != '/login') {
              _pendingDeepLink = uri;
            }
          }
          return isSplash ? null : '/';
        }

        // Paso 2: Sesión lista - restaurar deep link pendiente
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

        // Rutas públicas de /customer
        final isPublicCustomerRoute =
            currentPath == '/customer' ||
            currentPath.startsWith('/customer/product/');

        // Paso 3: Sin sesión
        if (role == null) {
          if (isSplash) return '/customer';
          if (isLogin) return null;
          if (isPublicCustomerRoute) return null;
          return '/login';
        }

        // Paso 4: Con sesión, en pantalla de auth
        if (isSplash || isLogin) {
          return role == AppRoles.admin ? '/admin' : '/customer';
        }

        // Paso 5: Proteger rutas de admin
        if (currentPath.startsWith('/admin') && role != AppRoles.admin) {
          return '/customer';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder:
              (context, state) => SplashScreen(
                onInitialize: (ctx) async {
                  final configProvider = ctx.read<AppConfigCubit>();
                  await Future.wait([
                    configProvider.loadConfig(),
                    configProvider.loadBusinessInfo(),
                  ]).timeout(const Duration(seconds: 5));
                },
              ),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),

        // ADMIN ROUTES
        ShellRoute(
          builder:
              (context, state, child) => BlocProvider(
                create: (_) => sl<AdminCatalogCubit>()..loadInitialData(),
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/admin',
              builder:
                  (context, state) => AdminLayout(
                    title: 'Catálogo',
                    showAppBar: false,
                    body: AdminCatalogScreen(
                      onProfileAvatarTap: () {
                        final auth = context.read<AuthCubit>();
                        if (auth.state.currentUser == null) {
                          context.go('/login');
                        } else {
                          context.push('/admin/profile');
                        }
                      },
                    ),
                  ),
              routes: [
                GoRoute(
                  path: 'profile',
                  builder:
                      (context, state) =>
                          const ProfileScreen(openedFromAdmin: true),
                ),
                GoRoute(
                  path: 'active-ingredients',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Componentes Químicos',
                        showBackButton: true,
                        body: ActiveIngredientsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'attributes',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Atributos de Variantes',
                        showBackButton: true,
                        body: AttributesManagementScreen(),
                      ),
                ),
                GoRoute(
                  path: 'business-info',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Información del Negocio',
                        showBackButton: true,
                        body: BusinessInfoScreen(),
                      ),
                ),
                GoRoute(
                  path: 'categories',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Categorías',
                        showBackButton: true,
                        body: CategoriesManagementScreen(),
                      ),
                ),
                GoRoute(
                  path: 'customer-credit-movements/:creditId',
                  builder: (context, state) {
                    final creditId = state.pathParameters['creditId'] ?? '';
                    final args = state.extra as Map<String, dynamic>? ?? {};
                    return AdminLayout(
                      title: 'Movimientos de Crédito',
                      body: CustomerCreditMovementsScreen(
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
                        onOpenOrder: (orderId) async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          );
                          final order = await OrdersService().getOrderById(
                            orderId,
                          );
                          if (context.mounted) {
                            Navigator.pop(context); // Cerrar loading dialog
                            if (order != null) {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                useRootNavigator: true,
                                backgroundColor: Colors.transparent,
                                builder:
                                    (ctx) => OrderDetailSheet(order: order),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No se pudo cargar el pedido. Es posible que haya sido eliminado.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'customer-credits',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Cuentas por Cobrar',
                        body: CustomerCreditsScreen(),
                      ),
                ),
                GoRoute(
                  path: 'customer-detail/:id',
                  builder: (context, state) {
                    final customer = state.extra;
                    final customerId = state.pathParameters['id'] ?? '';
                    if (customer == null && customerId.isEmpty) {
                      return Scaffold(
                        appBar: AppBar(title: const Text('Error')),
                        body: const Center(
                          child: Text('Cliente no encontrado.'),
                        ),
                      );
                    }
                    return AdminLayout(
                      title:
                          (customer as dynamic)?.fullName ??
                          'Detalle de Cliente',
                      showBackButton: true,
                      body: CustomerDetailScreen(
                        customer: customer as dynamic,
                        onViewAllOrders: () {
                          // Delegado al router global para evitar acoplamiento en features/customers
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ChangeNotifierProvider(
                                    create:
                                        (_) => OrdersProvider(
                                          customerIdFilter: customerId,
                                        ),
                                    child: OrdersScreen(
                                      customTitle:
                                          'Pedidos de ${(customer as dynamic)?.fullName ?? ''}',
                                    ),
                                  ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'customers',
                  builder: (context, state) {
                    return MultiBlocProvider(
                      providers: [
                        BlocProvider(
                          create:
                              (_) =>
                                  sl<CustomersCubit>()
                                    ..fetchCustomers(reset: true),
                        ),
                        BlocProvider(
                          create: (_) => sl<CustomersStatsCubit>()..loadStats(),
                        ),
                        BlocProvider(
                          create:
                              (_) =>
                                  sl<TopCustomersCubit>()..loadTopCustomers(),
                        ),
                      ],
                      child: Builder(
                        builder:
                            (innerContext) => AdminLayout(
                              title: 'Clientes',
                              showBackButton: true,
                              settingsActions: const [
                                PopupMenuItem(
                                  value: 'export',
                                  child: Text('Exportar a PDF'),
                                ),
                              ],
                              onSettingsSelected: (value) {
                                if (value == 'export') {
                                  innerContext
                                      .read<CustomersCubit>()
                                      .exportPdf();
                                }
                              },
                              body: const CustomersScreen(),
                            ),
                      ),
                    );
                  },
                ),
                GoRoute(
                  path: 'top-customers',
                  builder: (context, state) => const TopCustomersScreen(),
                ),
                GoRoute(
                  path: 'dashboard',
                  builder:
                      (context, state) => const AdminLayout(
                        title: 'Dashboard Financiero',
                        showBackButton: true,
                        body: DashboardScreen(),
                      ),
                ),
                GoRoute(
                  path: 'financial-accounts',
                  builder: (context, state) => const FinancialAccountsScreen(),
                ),
                GoRoute(
                  path: 'all-cash-shifts',
                  builder: (context, state) => const AllCashShiftsScreen(),
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
                  path: 'pos',
                  builder: (context, state) => const AdminPosScreen(),
                ),
                GoRoute(
                  path: 'product-form',
                  builder: (context, state) {
                    final args = state.extra as Map<String, dynamic>? ?? {};
                    return AdminLayout(
                      title:
                          args['productToEdit'] != null
                              ? 'Editar Producto'
                              : 'Nuevo Producto',
                      showBackButton: true,
                      showProfileButton: false,
                      showDrawerButton: false,
                      body: ProductFormScreen(
                        productToEdit:
                            args['productToEdit'] is ProductEntity
                                ? args['productToEdit'] as ProductEntity?
                                : (args['productToEdit'] as ProductModel?)
                                    ?.toEntity(),
                      ),
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
                  builder:
                      (context, state) => const WarehousesManagementScreen(),
                ),
                GoRoute(
                  path: 'product/:id',
                  builder: (context, state) {
                    final productId = state.pathParameters['id'];
                    final variantId = state.uri.queryParameters['variantId'];
                    final product = state.extra as ProductModel?;
                    if (product != null) {
                      return ProductDetailScreen(
                        product: product.toEntity(),
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
          ],
        ),

        // CUSTOMER ROUTES
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => navigationShell,
          branches: [
            // Rama 0: Catálogo
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer',
                  builder: (context, state) {
                    final config = context.watch<AppConfigCubit>();
                    return BlocProvider(
                      create:
                          (_) => sl<CustomerCatalogCubit>()..loadInitialData(),
                      child: CustomerCatalogScreen(
                        businessName: config.businessName,
                        businessAddress: config.businessAddress,
                      ),
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'product/:id',
                      builder: (context, state) {
                        final productId = state.pathParameters['id'];
                        final variantId =
                            state.uri.queryParameters['variantId'];
                        final product = state.extra as ProductModel?;
                        if (product != null) {
                          return ProductDetailScreen(
                            product: product.toEntity(),
                            isAdmin: false,
                            initialVariantId: variantId,
                          );
                        }
                        if (productId == null) {
                          return const Scaffold(
                            body: Center(child: Text('Error')),
                          );
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
              ],
            ),
            // Rama 1: Carrito
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer/cart',
                  builder: (context, state) => const CustomerCartScreen(),
                ),
              ],
            ),
            // Rama 2: Perfil y otras rutas
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer/profile',
                  builder:
                      (context, state) =>
                          const ProfileScreen(openedFromAdmin: false),
                ),
                GoRoute(
                  path: '/customer/locations',
                  builder: (context, state) {
                    final customerId =
                        context.read<AuthCubit>().state.currentUser?.id ?? '';
                    return LocationManagementScreen(customerId: customerId);
                  },
                ),
                GoRoute(
                  path: '/customer/orders',
                  builder: (context, state) => const CustomerOrdersScreen(),
                ),
                GoRoute(
                  path: '/customer/points',
                  builder: (context, state) => const PointsScreen(),
                ),
                GoRoute(
                  path: '/customer/wishlist',
                  builder:
                      (context, state) => WishlistScreen(
                        onAddToCart: (ctx, product) {
                          showModalBottomSheet(
                            context: ctx,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder:
                                (bCtx) => CartVariantPickerSheet(
                                  cart: bCtx.read<CartProvider>(),
                                  product: product,
                                ),
                          );
                        },
                      ),
                ),
                // GAMES
                GoRoute(
                  path: '/customer/games/claw-machine/:profileId',
                  builder:
                      (context, state) => ClawMachineScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/coin-catcher/:profileId',
                  builder:
                      (context, state) => CoinCatcherGameScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/dodge/:profileId',
                  builder:
                      (context, state) => DodgeGameScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/memorama/:profileId',
                  builder:
                      (context, state) => MemoramaGameScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/pinata/:profileId',
                  builder:
                      (context, state) => PinataGameScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/stack/:profileId',
                  builder:
                      (context, state) => StackGameScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
                GoRoute(
                  path: '/customer/games/super-salto/:profileId',
                  builder:
                      (context, state) => SuperSaltoScreen(
                        profileId: state.pathParameters['profileId'] ?? '',
                      ),
                ),
              ],
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
            final role = authCubit.state.currentUser?.role;
            final isAdmin = role == AppRoles.admin;

            if (product != null) {
              return ProductDetailScreen(
                product: product.toEntity(),
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

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
      (dynamic _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
