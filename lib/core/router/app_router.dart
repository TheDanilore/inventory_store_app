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
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// Navigator keys para los dos branches del StatefulShellRoute.
final GlobalKey<NavigatorState> _erpNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'erp_shell',
);
final GlobalKey<NavigatorState> _posNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'pos_shell',
);

/// IndexedStack con montaje LAZY por branch.
///
/// Garantías:
/// - Branch 0 (ERP) se monta inmediatamente al iniciar la app.
/// - Branch 1 (POS) solo se monta cuando el usuario navega a /pos por primera vez.
/// - A partir de la primera visita, ambos branches permanecen vivos (0ms en transiciones).
/// - Evita consultas Supabase innecesarias al arrancar (PosCubit no llama initPosData hasta visitar /pos).
class _LazyBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;

  const _LazyBranchContainer({
    required this.currentIndex,
    required this.children,
  });

  @override
  State<_LazyBranchContainer> createState() => _LazyBranchContainerState();
}

class _LazyBranchContainerState extends State<_LazyBranchContainer> {
  late final List<bool> _activated;

  @override
  void initState() {
    super.initState();
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.currentIndex,
    );
  }

  @override
  void didUpdateWidget(_LazyBranchContainer old) {
    super.didUpdateWidget(old);
    if (!_activated[widget.currentIndex]) {
      setState(() => _activated[widget.currentIndex] = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.currentIndex,
      children: [
        for (int i = 0; i < widget.children.length; i++)
          if (_activated[i]) widget.children[i] else const SizedBox.shrink(),
      ],
    );
  }
}

class AppRouter {
  static String? _pendingDeepLink;

  static void captureInitialRoute() {
    try {
      final uri = Uri.base;
      final path = uri.path;
      if (path.isNotEmpty &&
          path != '/' &&
          path != '/splash' &&
          path != '/login' &&
          !path.startsWith('/goal')) {
        _pendingDeepLink =
            path + (uri.query.isNotEmpty ? '?${uri.query}' : '');
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
                  const Icon(Icons.link_off_rounded, size: 64, color: Colors.grey),
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

        if (authState.authStatus == AuthStatus.unauthenticated) {
          return isLogin ? null : '/login';
        }

        if (authState.authStatus == AuthStatus.authenticated &&
            _pendingDeepLink != null) {
          final link = _pendingDeepLink!;
          _pendingDeepLink = null;
          if (!link.startsWith('/goal') &&
              link != '/splash' &&
              link != '/login') {
            return link;
          }
          return '/';
        }

        final role = authState.currentUser?.role;
        if (role == null) {
          return isLogin ? null : '/login';
        }

        if (isSplash || isLogin) {
          return '/';
        }

        return null;
      },
      routes: [
        ...AuthRoutes.topLevelRoutes,
        ...CatalogRoutes.topLevelRoutes(authCubit),

        // ── ADMIN ROUTES ──────────────────────────────────────────────────────
        //
        // StatefulShellRoute.indexedStack con lazy _LazyBranchContainer.
        //
        // Branch 0 – ERP: AdminShellLayout (sidebar + topbar) + todas las rutas admin.
        // Branch 1 – POS: AdminPosScreen en pantalla completa (sin sidebar ERP).
        //
        // Navegación ERP ↔ POS = swap de visibilidad de 0ms en IndexedStack.
        // Primer visita al POS: se monta el branch y PosDesktopSkeleton amortigua el frame 0.
        // Visitas posteriores: instantáneo, sin destrucción ni reconstrucción de widgets.
        //
        // BLoCs compartidos entre ambos branches (AdminCatalogCubit, CartCubit,
        // PosCubit, CashShiftsCubit) viven en el builder del StatefulShellRoute.
        StatefulShellRoute(
          builder:
              (context, state, navigationShell) => MultiBlocProvider(
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
                child: navigationShell,
              ),
          navigatorContainerBuilder:
              (context, navigationShell, children) => _LazyBranchContainer(
                currentIndex: navigationShell.currentIndex,
                children: children,
              ),
          branches: [
            // Branch 0 – ERP ───────────────────────────────────────────────
            StatefulShellBranch(
              navigatorKey: _erpNavigatorKey,
              routes: [
                ShellRoute(
                  builder:
                      (context, state, child) =>
                          AdminShellLayout(child: child),
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
                    ...PurchasesRoutes.adminRoutes,
                    ...UsersRoutes.adminRoutes,
                  ],
                ),
              ],
            ),

            // Branch 1 – POS (pantalla completa, sin sidebar ERP) ─────────
            StatefulShellBranch(
              navigatorKey: _posNavigatorKey,
              routes: PosRoutes.adminRoutes,
            ),
          ],
        ),
      ],
    );
  }
}
