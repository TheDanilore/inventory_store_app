import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/features/app_config/domain/entities/system_diagnostics_entity.dart';
import 'package:inventory_store_app/features/app_config/domain/repositories/system_diagnostics_repository.dart';
import 'package:inventory_store_app/features/app_config/domain/usecases/get_system_diagnostics_uc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/system_diagnostics_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/screens/admin_help_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';

class _FakeDiagnosticsRepo implements SystemDiagnosticsRepository {
  SystemDiagnosticsEntity? l1;
  SystemDiagnosticsEntity? l2;
  int pingCount = 0;
  int pkgCount = 0;
  bool throwOnPing = false;
  Completer<({int? latencyMs, bool isReachable})>? pendingPing;

  @override
  SystemDiagnosticsEntity? getCachedL1() => l1;

  @override
  Future<SystemDiagnosticsEntity?> getCachedL2() async => l2;

  @override
  Future<void> saveCache(SystemDiagnosticsEntity entity) async {
    l1 = entity;
    l2 = entity;
  }

  @override
  Future<({String version, String buildNumber})> getPackageInfo() async {
    pkgCount++;
    return (version: '2.1.0', buildNumber: '42');
  }

  @override
  Future<({int? latencyMs, bool isReachable})> pingBackend({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    pingCount++;
    if (pendingPing != null) {
      return pendingPing!.future;
    }
    if (throwOnPing) {
      throw const NetworkException(message: 'Sin conexión a Supabase');
    }
    return (latencyMs: 38, isReachable: true);
  }
}

class _FakeNetworkCubit extends Cubit<NetworkState> implements NetworkCubit {
  _FakeNetworkCubit([super.initialState = const NetworkConnected()]);

  @override
  bool get isOnline => state is NetworkConnected;
}

Widget _wrapScreen({
  required SystemDiagnosticsCubit diagnosticsCubit,
  required NetworkCubit networkCubit,
}) {
  final headerNotifier = ValueNotifier(
    const AdminHeaderConfig(title: 'Ayuda y Soporte'),
  );
  return MultiBlocProvider(
    providers: [BlocProvider<NetworkCubit>.value(value: networkCubit)],
    child: MaterialApp(
      home: AdminShellScope(
        headerNotifier: headerNotifier,
        isDesktop: true,
        updateHeader: (_) {},
        child: AdminHelpScreen(diagnosticsCubit: diagnosticsCubit),
      ),
    ),
  );
}

void main() {
  group('SystemDiagnosticsCubit Zero-Shimmer & Resilience', () {
    test(
      'retorna de inmediato dentro del TTL sin re-medir ni emitir Loading',
      () async {
        final repo = _FakeDiagnosticsRepo();
        final uc = GetSystemDiagnosticsUseCase(repo);
        final cubit = SystemDiagnosticsCubit(uc);

        final emitted = <SystemDiagnosticsState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.loadDiagnostics();
        await Future<void>.delayed(Duration.zero);
        expect(repo.pingCount, 1);
        expect(cubit.state, isA<SystemDiagnosticsLoaded>());
        expect(cubit.state.diagnostics?.appVersion, '2.1.0');
        expect(cubit.state.diagnostics?.latencyMs, 38);

        final countAfterFirstLoad = emitted.length;
        await cubit.loadDiagnostics();
        await Future<void>.delayed(Duration.zero);

        expect(repo.pingCount, 1);
        expect(emitted.length, countAfterFirstLoad);

        await sub.cancel();
        await cubit.close();
      },
    );

    test(
      'hidrata caché L2 sin emitir SystemDiagnosticsLoading (Zero-Shimmer)',
      () async {
        final repo =
            _FakeDiagnosticsRepo()
              ..l2 = SystemDiagnosticsEntity(
                appVersion: '2.0.0',
                buildNumber: '10',
                latencyMs: 55,
                isBackendReachable: true,
                measuredAt: DateTime.now().subtract(
                  const Duration(minutes: 10),
                ),
              );
        final uc = GetSystemDiagnosticsUseCase(repo);
        final cubit = SystemDiagnosticsCubit(uc);

        final emitted = <SystemDiagnosticsState>[];
        final sub = cubit.stream.listen(emitted.add);

        await cubit.loadDiagnostics();

        expect(emitted.whereType<SystemDiagnosticsLoading>(), isEmpty);
        expect(emitted.first, isA<SystemDiagnosticsLoaded>());
        expect(cubit.state.diagnostics?.latencyMs, 38);
        expect(repo.pingCount, 1);

        await sub.cancel();
        await cubit.close();
      },
    );

    test('deduplica llamadas concurrentes in-flight', () async {
      final repo =
          _FakeDiagnosticsRepo()
            ..pendingPing = Completer<({int? latencyMs, bool isReachable})>();
      final uc = GetSystemDiagnosticsUseCase(repo);
      final cubit = SystemDiagnosticsCubit(uc);

      final f1 = cubit.loadDiagnostics();
      final f2 = cubit.loadDiagnostics();
      repo.pendingPing!.complete((latencyMs: 42, isReachable: true));

      await Future.wait([f1, f2]);
      expect(repo.pingCount, 1);
      expect(cubit.state.diagnostics?.latencyMs, 42);

      await cubit.close();
    });

    test(
      'limpia latencyMs a null y conserva versión al fallar pingBackend',
      () async {
        final repo = _FakeDiagnosticsRepo();
        final uc = GetSystemDiagnosticsUseCase(repo);
        final cubit = SystemDiagnosticsCubit(uc);

        await cubit.loadDiagnostics();
        expect(cubit.state.diagnostics?.latencyMs, 38);

        repo.throwOnPing = true;
        await cubit.measureLatency();

        expect(cubit.state, isA<SystemDiagnosticsError>());
        expect(cubit.state.diagnostics?.appVersion, '2.1.0');
        expect(cubit.state.diagnostics?.latencyMs, isNull);
        expect(cubit.state.diagnostics?.isBackendReachable, isFalse);

        await cubit.close();
      },
    );
  });

  group('AdminHelpScreen Widget', () {
    testWidgets(
      'renderiza sin ProviderNotFoundException, filtra búsqueda y preserva caché al reentrar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repo = _FakeDiagnosticsRepo();
        final cubit = SystemDiagnosticsCubit(GetSystemDiagnosticsUseCase(repo));
        final networkCubit = _FakeNetworkCubit();

        await tester.pumpWidget(
          _wrapScreen(diagnosticsCubit: cubit, networkCubit: networkCubit),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Centro de Ayuda, Documentación y Operaciones'),
          findsOneWidget,
        );
        expect(find.text('Cajas y Mostradores'), findsOneWidget);
        expect(find.text('Diagnóstico & Cloud'), findsOneWidget);
        expect(repo.pingCount, 1);

        // Probar búsqueda con debounce (150ms) y limpiar búsqueda.
        await tester.enterText(find.byType(TextField), 'yape');
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.textContaining('para “yape”'), findsOneWidget);

        await tester.tap(find.text('Limpiar'));
        await tester.pumpAndSettle();

        // Cambiar a la pestaña de Diagnóstico haciendo visible su tab scrollable.
        await tester.ensureVisible(find.text('Diagnóstico & Cloud'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Diagnóstico & Cloud'));
        await tester.pumpAndSettle();
        expect(find.text('DANILORE ONE ERP v2.1.0 (Build 42)'), findsOneWidget);
        expect(find.text('38 ms (Excelente)'), findsOneWidget);

        // Salir de la pantalla y volver a montarla: Zero-Shimmer, 0 peticiones extra.
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpWidget(
          _wrapScreen(diagnosticsCubit: cubit, networkCubit: networkCubit),
        );
        await tester.pump();
        await tester.ensureVisible(find.text('Diagnóstico & Cloud'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Diagnóstico & Cloud'));
        await tester.pumpAndSettle();

        expect(repo.pingCount, 1);
        expect(find.text('DANILORE ONE ERP v2.1.0 (Build 42)'), findsOneWidget);

        await cubit.close();
        await networkCubit.close();
      },
    );
  });
}
