import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/router/go_router_refresh_stream.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/app_config/presentation/routes/app_config_routes.dart';
import 'package:inventory_store_app/features/auth/presentation/routes/auth_routes.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/routes/catalog_routes.dart';
import 'package:inventory_store_app/features/customers/presentation/routes/customers_routes.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_cart_fab.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/dashboard/presentation/routes/dashboard_routes.dart';
import 'package:inventory_store_app/features/financial/presentation/routes/financial_routes.dart';
import 'package:inventory_store_app/features/inventory/presentation/routes/inventory_routes.dart';
import 'package:inventory_store_app/features/loyalty/presentation/routes/loyalty_routes.dart';
import 'package:inventory_store_app/features/orders/presentation/routes/orders_routes.dart';
import 'package:inventory_store_app/features/pos/presentation/routes/pos_routes.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/routes/purchases_routes.dart';
import 'package:inventory_store_app/features/users/presentation/routes/users_routes.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

class AppRouter {
  static String? _pendingDeepLink;

  static void captureInitialRoute() {
    try {
      final uri = Uri.base;
      final path = uri.path;
      // Filtramos rutas internas o espurias (como comandos /goal)
      if (path.isNotEmpty &&
          path != '/' &&
          path != '/splash' &&
          path != '/login' &&
          !path.startsWith('/goal')) {
        _pendingDeepLink = path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
        LoggerService.i(
          'Deep link inicial capturado -> $_pendingDeepLink',
          tag: 'AppRouter',
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error capturando initial route',
        tag: 'AppRouter',
        error: e,
        stackTrace: st,
      );
    }
  }

  static GoRouter createRouter(AuthCubit authCubit) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      restorationScopeId: 'router',
      initialLocation: '/splash',
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
                    icon: const Icon(Icons.dashboard_rounded),
                    label: const Text('Ir al Panel de Administración'),
                  ),
                ],
              ),
            ),
          ),
      redirect: (context, state) {
        final authState = authCubit.state;
        final currentPath = state.uri.path;
        final isSplash = currentPath == '/splash';
        final isLogin = currentPath == '/login';

        LoggerService.d(
          'Evaluando redirección: path=$currentPath, status=${authState.authStatus}',
          tag: 'AppRouter',
        );

        if (authState.authStatus == AuthStatus.initial ||
            authState.authStatus == AuthStatus.error) {
          return isSplash ? null : '/splash';
        }

        // Si no está autenticado: si ya está en /login se queda, si está en /splash u otra ruta privada va a /login
        if (authState.authStatus == AuthStatus.unauthenticated) {
          return isLogin ? null : '/login';
        }

        if (authState.authStatus == AuthStatus.authenticated &&
            _pendingDeepLink != null) {
          final link = _pendingDeepLink!;
          _pendingDeepLink = null;
          if (!link.startsWith('/goal') && link != '/splash' && link != '/login') {
            return link;
          }
          return '/';
        }

        final role = authState.currentUser?.role;
        if (role == null) {
          return isLogin ? null : '/login';
        }

        // Si ya está autenticado y accede a splash o login, dirigir a raíz '/'
        if (isSplash || isLogin) {
          return '/';
        }

        return null;
      },
      routes: [
        ...AuthRoutes.topLevelRoutes,
        ...CatalogRoutes.topLevelRoutes(authCubit),

        // ADMIN ROUTES
        ShellRoute(
          builder:
              (context, state, child) => MultiBlocProvider(
                providers: [
                  BlocProvider(create: (_) => sl<SidebarBadgeCubit>()),
                  BlocProvider(
                    create: (_) => sl<AdminCatalogCubit>()..loadInitialData(),
                  ),
                  BlocProvider(
                    create: (_) => sl<CartCubit>()..initCart(cartType: 'pos'),
                  ),
                  BlocProvider(create: (_) => sl<PosCubit>()),
                  BlocProvider(create: (_) => sl<CashShiftsCubit>()),
                ],
                child: child,
              ),
          routes: [
            GoRoute(
              path: '/',
              builder:
                  (context, state) => AdminCatalogScreen(
                    floatingActionButton: const PosCartFab(),
                    onProfileAvatarTap: () {
                      final auth = context.read<AuthCubit>();
                      if (auth.state.currentUser == null) {
                        context.go('/login');
                      } else {
                        context.push('/profile');
                      }
                    },
                  ),
            ),
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
    );
  }
}
