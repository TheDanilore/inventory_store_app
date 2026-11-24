import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/inventory_alert_rules.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_desktop_top_bar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/notifications/notification_bell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAlertSource implements InventoryAlertSource {
  int variantsCalls = 0;
  int lotsCalls = 0;
  bool throwOnFetch = false;
  Completer<List<StockVariantSnapshot>>? pendingVariants;

  List<StockVariantSnapshot> variants = const [
    StockVariantSnapshot(
      variantId: 'var-1',
      productName: 'Paracetamol 500mg',
      totalStock: 0,
    ),
  ];

  List<LotSnapshot> lots = const [];

  @override
  Future<List<StockVariantSnapshot>> fetchVariants() async {
    variantsCalls++;
    if (pendingVariants != null) {
      return pendingVariants!.future;
    }
    if (throwOnFetch) {
      throw const NetworkException(message: 'Sin conexión a Supabase');
    }
    return variants;
  }

  @override
  Future<List<LotSnapshot>> fetchLots() async {
    lotsCalls++;
    if (throwOnFetch) {
      throw const NetworkException(message: 'Sin conexión a Supabase');
    }
    return lots;
  }
}

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeThemeCubit extends Cubit<ThemeMode> implements ThemeCubit {
  _FakeThemeCubit() : super(ThemeMode.light);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AuthUserEntity _adminUser() => const AuthUserEntity(
  id: 'user-1',
  authUserId: 'auth-1',
  email: 'admin@danilore.test',
  role: 'admin',
  fullName: 'Danilo Admin',
  phone: '999999999',
  documentType: 'DNI',
  documentNumber: '12345678',
  isActive: true,
  roles: ['admin'],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationsCubit.clearMemoryCache();
  });

  group('NotificationsCubit Zero-Shimmer & Resilience', () {
    test('hidrata caché L1/L2 y respeta minFreshTtl sin re-fetching', () async {
      final prefs = await SharedPreferences.getInstance();
      final source = _FakeAlertSource();

      final cubit1 = NotificationsCubit(source: source, prefs: prefs);
      await cubit1.start();

      expect(source.variantsCalls, 1);
      expect(cubit1.state.items.length, 1);
      expect(cubit1.state.unreadCount, 1);
      await cubit1.markRead(cubit1.state.items.first.id);
      expect(cubit1.state.unreadCount, 0);
      await cubit1.close();

      // Nueva instancia: inicia en Frame 0 con L1 y no vuelve a consultar dentro del TTL.
      final cubit2 = NotificationsCubit(source: source, prefs: prefs);
      expect(cubit2.state.items.length, 1);
      expect(cubit2.state.unreadCount, 0);
      await cubit2.start();
      expect(source.variantsCalls, 1);
      await cubit2.close();
    });

    test('deduplica peticiones concurrentes in-flight', () async {
      final prefs = await SharedPreferences.getInstance();
      final source =
          _FakeAlertSource()
            ..pendingVariants = Completer<List<StockVariantSnapshot>>();
      final cubit = NotificationsCubit(source: source, prefs: prefs);

      final f1 = cubit.refresh(force: true);
      final f2 = cubit.refresh();
      source.pendingVariants!.complete(source.variants);
      await Future.wait([f1, f2]);

      expect(source.variantsCalls, 1);
      expect(cubit.state.items.length, 1);
      await cubit.close();
    });

    test('preserva alertas, leídas y descartadas ante fallo de red', () async {
      final prefs = await SharedPreferences.getInstance();
      final source = _FakeAlertSource();
      final cubit = NotificationsCubit(source: source, prefs: prefs);

      await cubit.start();
      final alertId = cubit.state.items.first.id;
      await cubit.markRead(alertId);

      source.throwOnFetch = true;
      await cubit.refresh(force: true);

      expect(cubit.state.items.length, 1);
      expect(cubit.state.readIds.contains(alertId), isTrue);
      expect(cubit.state.errorMessage, 'Sin conexión a Supabase');
      expect(cubit.state.loading, isFalse);
      await cubit.close();
    });
  });

  group('AdminDesktopTopBar Widget', () {
    testWidgets(
      'renderiza sin overflow a 1024px, filtra refresh, abre notificaciones cacheadas y command palette',
      (tester) async {
        tester.view.physicalSize = const Size(1024, 768);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prefs = await SharedPreferences.getInstance();
        final source = _FakeAlertSource();
        final notificationsCubit = NotificationsCubit(
          source: source,
          prefs: prefs,
        );
        await notificationsCubit.start();

        final authCubit = _FakeAuthCubit(
          AuthState(
            authStatus: AuthStatus.authenticated,
            currentUser: _adminUser(),
          ),
        );
        final themeCubit = _FakeThemeCubit();

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider<NotificationsCubit>.value(value: notificationsCubit),
              BlocProvider<AuthCubit>.value(value: authCubit),
              BlocProvider<ThemeCubit>.value(value: themeCubit),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: AdminDesktopTopBar(
                  isSidebarCollapsed: false,
                  onToggleSidebar: () {},
                  showBackButton: true,
                  title:
                      'Detalle de Movimiento de Crédito de Cliente Corporativo Muy Largo',
                  actions: [
                    IconButton(
                      tooltip: 'Actualizar',
                      onPressed: () {},
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    FilledButton(onPressed: () {}, child: const Text('Nuevo')),
                  ],
                  showSettingsButton: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Buscar en el ERP...'), findsOneWidget);
        expect(find.text('Nuevo'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsNothing);
        expect(find.byType(NotificationBell), findsOneWidget);
        expect(find.text('1'), findsOneWidget);

        // Abrir panel de notificaciones y validar datos cacheados sin shimmer.
        await tester.tap(find.byType(NotificationBell));
        await tester.pumpAndSettle();
        expect(find.text('Sin stock: Paracetamol 500mg'), findsOneWidget);

        // Cerrar panel de notificaciones.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Abrir Command Palette desde el buscador y buscar sin tildes.
        await tester.tap(find.text('Buscar en el ERP...'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'credito');
        await tester.pumpAndSettle();

        expect(find.text('Créditos de Clientes'), findsOneWidget);
        expect(find.text('Créditos de Proveedores'), findsOneWidget);

        await notificationsCubit.close();
        await authCubit.close();
        await themeCubit.close();
      },
    );
  });
}
