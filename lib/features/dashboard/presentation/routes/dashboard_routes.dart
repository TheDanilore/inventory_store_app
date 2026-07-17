import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/dashboard/presentation/screens/dashboard_screen.dart';

class DashboardRoutes {
  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
      ];
}
