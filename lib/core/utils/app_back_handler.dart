import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// Gestor centralizado del comportamiento de retroceso del Sistema Operativo
/// (Botón físico de Android / Gesto de navegación lateral).
///
/// Implementa las directrices de Google Android Navigation Component:
/// 1. Cierra Overlays activos (Drawers, BottomSheets, Diálogos).
/// 2. Ejecuta callbacks personalizados de pantalla (`onCustomBack`) si existen.
/// 3. Resuelve rutas secundarias hacia su módulo padre (`/customers/detail` -> `/customers`).
/// 4. Resuelve módulos de primer nivel hacia el inicio (`/dashboard` -> `/`).
/// 5. En el inicio (`/`), activa el mecanismo "Double-Tap to Exit" con debounce de 2 segundos.
class AppBackHandler {
  static DateTime? _lastBackPressTime;
  static const Duration _exitThreshold = Duration(seconds: 2);
  static final List<String> _routeHistory = [];

  /// Registra la ruta visitada para permitir retroceso exacto de historial
  static void recordRoute(String path) {
    if (path.isEmpty || path == '/splash' || path == '/login') return;
    if (_routeHistory.isNotEmpty && _routeHistory.last == path) return;
    _routeHistory.add(path);
    if (_routeHistory.length > 30) {
      _routeHistory.removeAt(0);
    }
  }

  /// Retorna la ruta inmediatamente anterior y limpia el tope del historial
  static String? getPreviousRoute() {
    if (_routeHistory.length > 1) {
      _routeHistory.removeLast(); // remover la ruta actual
      return _routeHistory.removeLast(); // retornar la anterior
    }
    return null;
  }

  /// Despacha el retroceso para el [BuildContext] actual de forma jerárquica y segura.
  static void handleBack(BuildContext context, {VoidCallback? onCustomBack}) {
    // 1. Callback explícito de la pantalla (ej. validación de descarte en formularios)
    if (onCustomBack != null) {
      LoggerService.d(
        'AppBackHandler: Ejecutando onCustomBack',
        tag: 'Navigation',
      );
      onCustomBack();
      return;
    }

    // 2. Si GoRouter tiene rutas en su historial de push
    if (context.canPop()) {
      LoggerService.d(
        'AppBackHandler: context.canPop() ejecutado',
        tag: 'Navigation',
      );
      context.pop();
      return;
    }

    // 3. Si el Navigator tiene rutas emergentes activas (Drawer, Dialog, BottomSheet)
    if (Navigator.of(context).canPop()) {
      LoggerService.d(
        'AppBackHandler: Navigator.canPop() ejecutado',
        tag: 'Navigation',
      );
      Navigator.of(context).pop();
      return;
    }

    try {
      final currentUri = GoRouterState.of(context).uri;
      final currentPath = currentUri.path;
      final segments = currentUri.pathSegments;

      // 4. Si ya estamos en la raíz del ERP ('/'): Doble toque para salir
      if (currentPath == '/') {
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > _exitThreshold) {
          _lastBackPressTime = now;
          LoggerService.d(
            'AppBackHandler: Primer toque en raíz, mostrando advertencia de confirmación',
            tag: 'Navigation',
          );
          AppSnackbar.show(
            context,
            message: 'Presiona atrás nuevamente para salir de la aplicación.',
            type: SnackbarType.info,
            duration: _exitThreshold,
          );
        } else {
          _lastBackPressTime = null;
          LoggerService.i(
            'AppBackHandler: Segundo toque en raíz confirmado, saliendo ordenadamente al SO',
            tag: 'Navigation',
          );
          SystemNavigator.pop();
        }
        return;
      }

      // 5. Intentar retroceder según el historial en memoria a donde estaba antes
      final previous = getPreviousRoute();
      if (previous != null && previous != currentPath) {
        LoggerService.d(
          'AppBackHandler: Retrocediendo a la ruta previa en memoria $previous',
          tag: 'Navigation',
        );
        context.go(previous);
        return;
      }

      // 6. Mapeo explícito a módulo padre de vistas conocidas
      const parentRouteMap = {
        '/purchase-orders/form': '/purchase-orders',
        '/inventory-entries/form': '/inventory-entries',
        '/inventory-exits/form': '/inventory-exits',
        '/products/product-form': '/products',
        '/catalog/product-detail': '/catalog',
        '/customers/customer-detail': '/customers',
        '/customer-credits': '/customers',
        '/customer-credit-movements': '/customer-credits',
        '/supplier-credits': '/suppliers',
        '/supplier-credit-movements': '/supplier-credits',
        '/users/form': '/users',
        '/points-settings': '/dashboard',
        '/all-cash-shifts': '/pos',
        '/bulk-import': '/products',
        '/top-customers': '/dashboard',
        '/profile': '/dashboard',
      };

      if (parentRouteMap.containsKey(currentPath)) {
        final parent = parentRouteMap[currentPath]!;
        LoggerService.d(
          'AppBackHandler: Navegando a módulo padre mapeado $parent',
          tag: 'Navigation',
        );
        context.go(parent);
        return;
      }

      // 7. Si la ruta es jerárquica con más de 1 segmento (ej. /customers/customer-detail -> /customers)
      if (segments.length > 1) {
        final parentPath =
            '/${segments.sublist(0, segments.length - 1).join('/')}';
        LoggerService.d(
          'AppBackHandler: Navegando al módulo padre $parentPath',
          tag: 'Navigation',
        );
        context.go(parentPath);
        return;
      }

      // 8. Si estamos en un módulo de primer nivel hermano, retornamos al inicio ('/')
      LoggerService.d(
        'AppBackHandler: Módulo hermano, retornando a inicio /',
        tag: 'Navigation',
      );
      context.go('/');
    } catch (e, st) {
      LoggerService.w(
        'AppBackHandler: Fallo al resolver retroceso por GoRouterState, ejecutando fallback a /',
        error: e,
        stackTrace: st,
        tag: 'Navigation',
      );
      context.go('/');
    }
  }
}

/// Widget reutilizable que intercepta el evento de retroceso del SO mediante [PopScope]
/// y lo canaliza a través de [AppBackHandler.handleBack].
class AppPopScope extends StatelessWidget {
  final Widget child;
  final VoidCallback? onCustomBack;
  final bool enabled;

  const AppPopScope({
    super.key,
    required this.child,
    this.onCustomBack,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        AppBackHandler.handleBack(context, onCustomBack: onCustomBack);
      },
      child: child,
    );
  }
}
