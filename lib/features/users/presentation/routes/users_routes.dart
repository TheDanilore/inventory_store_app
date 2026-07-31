import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/screens/user_form_screen.dart';
import 'package:inventory_store_app/features/users/presentation/screens/users_management_screen.dart';

class UsersRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/users',
      builder: (context, state) => const UsersManagementScreen(),
    ),
    GoRoute(
      path: '/admin/users/form',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return UserFormScreen(
          existingUser:
              args['userToEdit'] is UserEntity ? args['userToEdit'] : null,
        );
      },
    ),
  ];
}
