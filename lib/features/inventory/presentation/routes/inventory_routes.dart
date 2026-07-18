import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entries_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exits_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/kardex_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/warehouses_management_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: 'inventory-entries',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryEntriesCubit>()..init(),
            child: const InventoryEntriesScreen(),
          ),
    ),
    GoRoute(
      path: 'inventory-entry-form',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return BlocProvider(
          create: (_) => sl<InventoryEntryFormCubit>(),
          child: InventoryEntryFormScreen(
            purchaseOrderId:
                args['purchaseOrderId'] ??
                state.uri.queryParameters['purchaseOrderId'],
          ),
        );
      },
    ),
    GoRoute(
      path: 'inventory-exit-form',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryExitFormCubit>(),
            child: const InventoryExitFormScreen(),
          ),
    ),
    GoRoute(
      path: 'inventory-exits',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryExitsCubit>()..initLoad(),
            child: const InventoryExitsScreen(),
          ),
    ),
    GoRoute(
      path: 'inventory',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryCubit>(),
            child: const AdminLayout(
              title: 'Inventario',
              showBackButton: true,
              body: InventoryScreen(),
            ),
          ),
    ),
    GoRoute(
      path: 'kardex',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<KardexCubit>(),
            child: const AdminLayout(
              title: 'Kardex',
              showBackButton: true,
              body: KardexScreen(),
            ),
          ),
    ),
    GoRoute(
      path: 'warehouses',
      builder:
          (context, state) => const AdminLayout(
            title: 'Almacenes',
            showBackButton: true,
            body: WarehousesManagementScreen(),
          ),
    ),
  ];
}
