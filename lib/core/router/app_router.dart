import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/router/go_router_refresh_stream.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/app_back_handler.dart';
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
import 'package:inventory_store_app/features/roles/presentation/routes/roles_routes.dart';
import 'package:inventory_store_app/features/users/presentation/routes/users_routes.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/admin_catalog_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';
import 'package:inventory_store_app/features/dashboard/presentation/screens/dashboard_screen.dart';

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

/// Contenedor de branches con transición direccional "Seamless Morph & Slide" (Opción 1)
/// y montaje perezoso (Lazy) por branch.
///
/// Características:
/// - Branch 0 (ERP) se monta inmediatamente al iniciar la app.
/// - Branch 1 (POS) solo se monta cuando el usuario navega a /pos por primera vez.
/// - Transición direccional fluida y coordinada (280ms, Curves.easeInOutCubic):
///   * De ERP a POS (0 -> 1): ERP se desliza sutilmente a la izquierda (-6%) y se desvanece;
///     POS entra desde la derecha (+8%) y se ilumina.
///   * De POS a ERP (1 -> 0): POS se desliza hacia la derecha (+8%) y se desvanece;
///     ERP reaparece regresando desde la izquierda (-6%).
/// - Cero solapamientos ni transparencias fantasma: ambos branches cuentan con fondos sólidos opacos
///   y ClipRect estricto, previniendo artefactos visuales o doble exposición.
/// - Retención de estado completa: los branches inactivos se preservan intactos mediante Offstage.
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

class _LazyBranchContainerState extends State<_LazyBranchContainer>
    with SingleTickerProviderStateMixin {
  late final List<bool> _activated;
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _previousIndex = 0;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _activated = List.generate(
      widget.children.length,
      (i) => i == widget.currentIndex,
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _isTransitioning = false;
            _previousIndex = widget.currentIndex;
          });
        }
      }
    });
  }

  @override
  void didUpdateWidget(_LazyBranchContainer old) {
    super.didUpdateWidget(old);
    if (!_activated[widget.currentIndex]) {
      setState(() => _activated[widget.currentIndex] = true);
    }

    if (widget.currentIndex != old.currentIndex) {
      _previousIndex = old.currentIndex;
      _isTransitioning = true;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.bg(context);
    final bool goingToPos = widget.currentIndex > _previousIndex;

    return ClipRect(
      child: ColoredBox(
        color: bgColor,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            final t = _isTransitioning ? _animation.value : 1.0;

            // Vistas en reposo (sin animación activa)
            if (!_isTransitioning) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  for (int i = 0; i < widget.children.length; i++)
                    if (_activated[i])
                      Offstage(
                        offstage: i != widget.currentIndex,
                        child: ColoredBox(
                          color: bgColor,
                          child: widget.children[i],
                        ),
                      ),
                ],
              );
            }

            // Cálculo direccional:
            // Saliente (se va):
            final double outgoingOpacity = (1.0 - t).clamp(0.0, 1.0);
            final Offset outgoingSlide =
                goingToPos
                    ? Offset(-0.06 * t, 0.0) // ERP se desliza a la izquierda
                    : Offset(0.08 * t, 0.0); // POS se desliza a la derecha

            // Entrante (aparece):
            final double incomingOpacity = t.clamp(0.0, 1.0);
            final Offset incomingSlide =
                goingToPos
                    ? Offset(
                      0.08 * (1.0 - t),
                      0.0,
                    ) // POS entra desde la derecha
                    : Offset(
                      -0.06 * (1.0 - t),
                      0.0,
                    ); // ERP regresa desde la izquierda

            return Stack(
              fit: StackFit.expand,
              children: [
                // 1. Branches completamente inactivos (preservan estado en Offstage)
                for (int i = 0; i < widget.children.length; i++)
                  if (_activated[i] &&
                      i != widget.currentIndex &&
                      i != _previousIndex)
                    Offstage(offstage: true, child: widget.children[i]),

                // 2. Branch saliente (en el fondo, ignorando toques)
                if (_activated[_previousIndex])
                  IgnorePointer(
                    ignoring: true,
                    child: SlideTransition(
                      position: AlwaysStoppedAnimation(outgoingSlide),
                      child: Opacity(
                        opacity: outgoingOpacity,
                        child: ColoredBox(
                          color: bgColor,
                          child: widget.children[_previousIndex],
                        ),
                      ),
                    ),
                  ),

                // 3. Branch entrante (en el frente, con opacidad suave)
                if (_activated[widget.currentIndex])
                  SlideTransition(
                    position: AlwaysStoppedAnimation(incomingSlide),
                    child: Opacity(
                      opacity: incomingOpacity,
                      child: ColoredBox(
                        color: bgColor,
                        child: widget.children[widget.currentIndex],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
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
    final router = GoRouter(
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
        final isResetPassword = currentPath == '/reset-password';

        if (isResetPassword) return null;

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

        final user = authState.currentUser;
        if (user == null) {
          return isLogin ? null : '/login';
        }

        // Si es usuario exclusivo de POS (sin acceso al ERP administrativo):
        if (user.isPosOnly) {
          if (isSplash ||
              isLogin ||
              (!currentPath.startsWith('/pos') && currentPath != '/login')) {
            return '/pos';
          }
          return null;
        }

        // Si el usuario intenta entrar a /pos pero no tiene permisos para el POS:
        if (!user.canAccessPos && currentPath.startsWith('/pos')) {
          return '/';
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
          // Fade de entrada del panel tras el login (reveal sobre el vidrio blanco).
          pageBuilder:
              (context, state, navigationShell) => CustomTransitionPage<void>(
                key: state.pageKey,
                transitionDuration: const Duration(milliseconds: 450),
                transitionsBuilder: (
                  context,
                  animation,
                  secondaryAnimation,
                  child,
                ) {
                  final isDark =
                      Theme.of(context).brightness == Brightness.dark;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Respaldo opaco: evita ver el fondo mientras el login se desvanece
                      if (!isDark) const ColoredBox(color: Colors.white),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        ),
                        child: ColoredBox(
                          color: AppColors.bg(context),
                          child: child,
                        ),
                      ),
                    ],
                  );
                },
                child: MultiBlocProvider(
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
                    BlocProvider(
                      create: (_) => sl<NotificationsCubit>()..start(),
                    ),
                  ],
                  child: AppPopScope(child: navigationShell),
                ),
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
                      (context, state, child) => AdminShellLayout(child: child),
                  routes: [
                    GoRoute(
                      path: '/',
                      pageBuilder:
                          (context, state) => CustomTransitionPage<void>(
                            key: state.pageKey,
                            child: const DashboardScreen(),
                            transitionDuration: const Duration(
                              milliseconds: 400,
                            ),
                            transitionsBuilder: (
                              context,
                              animation,
                              secondaryAnimation,
                              child,
                            ) {
                              return FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                ),
                                child: ColoredBox(
                                  color: AppColors.bg(context),
                                  child: child,
                                ),
                              );
                            },
                          ),
                    ),
                    GoRoute(
                      path: '/catalog',
                      builder:
                          (context, state) => AdminCatalogScreen(
                            floatingActionButton: const PosCartFab(),
                            onProfileAvatarTap: () {
                              final auth = context.read<AuthCubit>();
                              if (auth.state.currentUser == null) {
                                context.go('/login');
                              } else {
                                context.go('/profile');
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
                    ...RolesRoutes.adminRoutes,
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

    try {
      sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == sb.AuthChangeEvent.passwordRecovery) {
          LoggerService.i(
            'AuthChangeEvent.passwordRecovery detectado -> Redirigiendo a /reset-password',
            tag: 'AppRouter',
          );
          router.go('/reset-password');
        }
      });
    } catch (e) {
      LoggerService.w(
        'No se pudo registrar listener de recuperación de contraseña: $e',
        tag: 'AppRouter',
      );
    }

    return router;
  }
}
