import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/roles/presentation/screens/roles_management_screen.dart';

class RolesRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/roles',
      builder: (context, state) => const RolesManagementScreen(),
    ),
  ];
}
