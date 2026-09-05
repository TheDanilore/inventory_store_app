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
        final extra = state.extra;
        UserEntity? user;
        String? role = state.uri.queryParameters['role'];

        if (extra is UserEntity) {
          user = extra;
          role ??= user.role;
        } else if (extra is Map<String, dynamic>) {
          if (extra['existingUser'] is UserEntity) {
            user = extra['existingUser'] as UserEntity;
          } else if (extra['userToEdit'] is UserEntity) {
            user = extra['userToEdit'] as UserEntity;
          }
          if (extra['initialRole'] is String) {
            role = extra['initialRole'] as String;
          } else if (user != null) {
            role ??= user.role;
          }
        }

        return UserFormScreen(
          existingUser: user,
          initialRole: role,
        );
      },
    ),
  ];
}
