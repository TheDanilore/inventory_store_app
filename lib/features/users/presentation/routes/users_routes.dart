import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/presentation/screens/user_form_screen.dart';
import 'package:inventory_store_app/features/users/presentation/screens/users_management_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class UsersRoutes {
  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'users',
          builder: (context, state) => const AdminLayout(
            title: 'Usuarios',
            showBackButton: true,
            body: UsersManagementScreen(),
          ),
        ),
        GoRoute(
          path: 'user-form',
          builder: (context, state) {
            final args = state.extra as Map<String, dynamic>? ?? {};
            return AdminLayout(
              title: args['userToEdit'] != null
                  ? 'Editar Usuario'
                  : 'Nuevo Usuario',
              showBackButton: true,
              body: UserFormScreen(
                existingUser: args['userToEdit'] is UserEntity
                    ? args['userToEdit']
                    : null,
              ),
            );
          },
        ),
      ];
}
