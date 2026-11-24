import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_sidebar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/app_drawer.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/admin_menu_builder.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/watch_pending_orders_count_uc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOrdersRepo implements OrdersRepository {
  final StreamController<Either<Failure, int>> controller =
      StreamController<Either<Failure, int>>.broadcast();

  @override
  Stream<Either<Failure, int>> watchPendingOrdersCount() => controller.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAppConfigCubit extends Cubit<AppConfigState>
    implements AppConfigCubit {
  _FakeAppConfigCubit() : super(const AppConfigState());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthUserEntity _collaboratorUser() => const AuthUserEntity(
  id: 'user-2',
  authUserId: 'auth-2',
  email: 'colab@danilore.test',
  role: 'employee',
  fullName: 'Colaborador Ventas',
  phone: '999888777',
  documentType: 'DNI',
  documentNumber: '87654321',
  isActive: true,
  roles: ['employee'],
  permissions: {AppPermissions.posSale, AppPermissions.productsView},
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SidebarBadgeCubit.clearMemoryCache();
    SidebarNavigationMemory.reset();
    DrawerNavigationMemory.reset();
  });

  group('SidebarBadgeCubit Zero-Shimmer & Lifecycle', () {
    test(
      'hidrata L1/L2 Zero-Shimmer, conserva cachedCount en error y permite recrear tras close()',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeOrdersRepo();
        final uc = WatchPendingOrdersCountUc(repo);

        final cubit1 = SidebarBadgeCubit(uc, prefs: prefs);
        expect(cubit1.state, isA<SidebarBadgeLoading>());

        repo.controller.add(const Right(7));
        await Future<void>.delayed(Duration.zero);

        expect(cubit1.state, isA<SidebarBadgeLoaded>());
        expect((cubit1.state as SidebarBadgeLoaded).count, 7);

        // Simular fallo de stream: debe preservar cachedCount = 7.
        repo.controller.add(const Left(ServerFailure(message: 'Timeout')));
        await Future<void>.delayed(Duration.zero);
        expect(cubit1.state, isA<SidebarBadgeError>());
        expect(cubit1.state.cachedCount, 7);

        // Simular logout (close) y re-login (nueva instancia factory): Frame 0 Loaded(7).
        await cubit1.close();
        final cubit2 = SidebarBadgeCubit(uc, prefs: prefs);
        expect(cubit2.state, isA<SidebarBadgeLoaded>());
        expect((cubit2.state as SidebarBadgeLoaded).count, 7);

        await cubit2.close();
        await repo.controller.close();
      },
    );
  });

  group('AdminMenuBuilder RBAC', () {
    test(
      'respeta permisos estrictos de colaborador no-admin y loyaltyEnabled',
      () {
        final menu = AdminMenuBuilder.buildMenu(
          isAdmin: false,
          permissions: const {
            AppPermissions.productsView,
            AppPermissions.posSale,
          },
          loyaltyEnabled: true,
        );

        expect(menu.canViewCatalog, isTrue);
        expect(menu.canViewOrders, isTrue);
        expect(menu.canViewSettings, isFalse);
        expect(menu.inventoryChildren.map((e) => e.routePath), ['/products']);
        expect(menu.purchasesChildren, isEmpty);
        expect(menu.systemChildren, isEmpty);

        final adminMenu = AdminMenuBuilder.buildMenu(
          isAdmin: true,
          permissions: const {},
          loyaltyEnabled: true,
        );
        expect(
          adminMenu.systemChildren.any(
            (e) => e.routePath == '/points-settings',
          ),
          isTrue,
        );
      },
    );
  });

  group('AdminSidebar & AppDrawer Widgets', () {
    testWidgets(
      'AdminSidebar muestra badge cacheado durante Error (Zero-Shimmer) y soporta colapso sin controllers pesados',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeOrdersRepo();
        final badgeCubit = SidebarBadgeCubit(
          WatchPendingOrdersCountUc(repo),
          prefs: prefs,
        );
        repo.controller.add(const Right(12));
        await tester.pump();
        // Emite error después de haber cargado: el badge debe seguir mostrando 12.
        repo.controller.add(const Left(ServerFailure(message: 'Sin red')));
        await tester.pump();

        final authCubit = _FakeAuthCubit(
          AuthState(
            authStatus: AuthStatus.authenticated,
            currentUser: _collaboratorUser(),
          ),
        );
        final appConfigCubit = _FakeAppConfigCubit();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<SidebarBadgeCubit>.value(value: badgeCubit),
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    AdminSidebar(isCollapsed: false, onToggleCollapse: () {}),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pedidos'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        // Colaborador sin permisos de compras/roles no debe ver Compras.
        expect(find.text('Compras'), findsNothing);
        // Sub-items de Inventario cerrados no están montados en el árbol.
        expect(find.text('Productos'), findsNothing);

        // Colapsar sidebar: oculta etiquetas liberando widgets de texto.
        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<SidebarBadgeCubit>.value(value: badgeCubit),
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Row(
                  children: [
                    AdminSidebar(isCollapsed: true, onToggleCollapse: () {}),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pedidos'), findsNothing);

        await badgeCubit.close();
        await repo.controller.close();
        await authCubit.close();
        await appConfigCubit.close();
      },
    );

    testWidgets(
      'AppDrawer(isAdmin: true) no escala privilegios de colaborador no-admin y no monta grupos cerrados',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final repo = _FakeOrdersRepo();
        final badgeCubit = SidebarBadgeCubit(
          WatchPendingOrdersCountUc(repo),
          prefs: prefs,
        );
        repo.controller.add(const Right(4));
        await tester.pump();

        final authCubit = _FakeAuthCubit(
          AuthState(
            authStatus: AuthStatus.authenticated,
            currentUser: _collaboratorUser(),
          ),
        );
        final appConfigCubit = _FakeAppConfigCubit();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<SidebarBadgeCubit>.value(value: badgeCubit),
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<AppConfigCubit>.value(value: appConfigCubit),
            ],
            child: const MaterialApp(
              home: Scaffold(body: AppDrawer(isAdmin: true)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Colaborador'), findsOneWidget);
        expect(find.text('Pedidos'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('Compras'), findsNothing);
        expect(find.text('Configuración del Sistema'), findsNothing);
        // Grupo Inventario cerrado no monta su hijo Productos.
        expect(find.text('Productos'), findsNothing);

        // Abrir grupo Inventario: ahora sí se monta Productos.
        await tester.tap(find.text('Inventario'));
        await tester.pumpAndSettle();
        expect(find.text('Productos'), findsOneWidget);

        await badgeCubit.close();
        await repo.controller.close();
        await authCubit.close();
        await appConfigCubit.close();
      },
    );
  });
}
