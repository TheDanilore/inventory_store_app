import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/router/go_router_refresh_stream.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/routes/app_config_routes.dart';
import 'package:inventory_store_app/features/auth/presentation/routes/auth_routes.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/routes/catalog_routes.dart';
import 'package:inventory_store_app/features/customers/presentation/routes/customers_routes.dart';
import 'package:inventory_store_app/features/dashboard/presentation/routes/dashboard_routes.dart';
import 'package:inventory_store_app/features/financial/presentation/routes/financial_routes.dart';
import 'package:inventory_store_app/features/inventory/presentation/routes/inventory_routes.dart';
import 'package:inventory_store_app/features/loyalty/presentation/routes/loyalty_routes.dart';
import 'package:inventory_store_app/features/orders/presentation/routes/orders_routes.dart';
import 'package:inventory_store_app/features/pos/presentation/routes/pos_routes.dart';
import 'package:inventory_store_app/features/purchases/presentation/routes/purchases_routes.dart';
import 'package:inventory_store_app/features/users/presentation/routes/users_routes.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/customer/customer_catalog_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/customer_layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

class AppRouter {
  static String? _pendingDeepLink;

  static void captureInitialRoute() {
    try {
      final uri = Uri.base;
      final path = uri.path;
      if (path.isNotEmpty && path != '/' && path != '/login') {
        _pendingDeepLink = path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
        debugPrint('AppRouter: deep link capturado -> $_pendingDeepLink');
      }
    } catch (_) {}
  }

  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      restorationScopeId: 'router',
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(authCubit.stream),
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Página no encontrada')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link_off_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Esta página no existe',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(state.matchedLocation,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Ir al Inicio'),
              ),
            ],
          ),
        ),
      ),
      redirect: (context, state) {
        final authState = authCubit.state;
        final currentPath = state.uri.path;
        final isSplash = currentPath == '/';
        final isLogin = currentPath == '/login';
        final isGallery = currentPath == '/gallery';

        if (authState.authStatus == AuthStatus.initial) {
          return isSplash ? null : '/';
        }

        if (authState.authStatus == AuthStatus.unauthenticated) {
          if (isGallery) return null;
          if (currentPath.startsWith('/product/')) return null;
          return isLogin ? null : '/login';
        }

        if (authState.authStatus == AuthStatus.authenticated &&
            _pendingDeepLink != null) {
          final link = _pendingDeepLink!;
          _pendingDeepLink = null;
          return link;
        }

        final role = authState.currentUser?.role;
        if (role == null) {
          return '/login';
        }

        if (isSplash || isLogin) {
          return role == AppRoles.admin ? '/admin' : '/customer';
        }

        if (currentPath.startsWith('/admin') && role != AppRoles.admin) {
          return '/customer';
        }

        return null;
      },
      routes: [
        ...AuthRoutes.topLevelRoutes,
        ...CatalogRoutes.topLevelRoutes(authCubit),

        // ADMIN ROUTES
        ShellRoute(
          builder: (context, state, child) => BlocProvider(
            create: (_) => sl<AdminCatalogCubit>()..loadInitialData(),
            child: child,
          ),
          routes: [
            GoRoute(
              path: '/admin',
              builder: (context, state) => AdminLayout(
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
                ...AuthRoutes.adminRoutes,
                ...AppConfigRoutes.adminRoutes,
                ...CatalogRoutes.adminRoutes,
                ...CustomersRoutes.adminRoutes,
                ...DashboardRoutes.adminRoutes,
                ...FinancialRoutes.adminRoutes,
                ...InventoryRoutes.adminRoutes,
                ...LoyaltyRoutes.adminRoutes,
                ...OrdersRoutes.adminRoutes,
                ...PosRoutes.adminRoutes,
                ...PurchasesRoutes.adminRoutes,
                ...UsersRoutes.adminRoutes,
              ],
            ),
          ],
        ),

        // CUSTOMER ROUTES
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => CustomerLayout(
            title: '',
            body: navigationShell,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/customer',
                  builder: (context, state) {
                    final config = context.watch<AppConfigCubit>();
                    return BlocProvider(
                      create: (_) => sl<CustomerCatalogCubit>()..loadInitialData(),
                      child: CustomerCatalogScreen(
                        businessName: config.businessName,
                        businessAddress: config.businessAddress,
                      ),
                    );
                  },
                  routes: CatalogRoutes.customerRoutes,
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                OrdersRoutes.customerRoutes.firstWhere(
                    (route) => (route as GoRoute).path == '/customer/cart'),
              ],
            ),
            StatefulShellBranch(
              routes: [
                ...CustomersRoutes.customerRoutes,
                ...LoyaltyRoutes.customerRoutes,
                ...OrdersRoutes.customerRoutes.where(
                    (route) => (route as GoRoute).path != '/customer/cart'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
