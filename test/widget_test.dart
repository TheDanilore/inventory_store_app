import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/main.dart';

/// Implementación manual simulada de AuthCubit para pruebas nativas rápidas.
class FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  // Instanciamos el estado real usando sus valores por defecto (AuthStatus.initial).
  FakeAuthCubit() : super(const AuthState());

  @override
  Future<void> checkSession() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Prueba inicial de inicialización de la aplicacion', (
    WidgetTester tester,
  ) async {
    final fakeAuthCubit = FakeAuthCubit();

    // Creamos una configuración de enrutamiento básica para el árbol de prueba.
    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox.shrink()),
        ),
      ],
    );

    // Inicializamos la UI inyectando los parámetros requeridos por el constructor de MyApp.
    await tester.pumpWidget(
      MyApp(authCubit: fakeAuthCubit, router: testRouter),
    );

    // Confirmación atómica de compilación y montaje exitoso en el árbol de widgets.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
