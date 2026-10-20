import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/roles/presentation/bloc/roles_cubit.dart';
import 'package:inventory_store_app/features/roles/presentation/screens/roles_management_screen.dart';

class RolesRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/roles',
      builder: (context, state) {
        return BlocProvider(
          create: (_) => sl<RolesCubit>(),
          child: const RolesManagementScreen(),
        );
      },
    ),
  ];
}
