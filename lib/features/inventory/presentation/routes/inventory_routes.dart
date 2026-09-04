import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entries_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_entry_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exit_form_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_exits_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/kardex_screen.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/screens/warehouses_management_screen.dart';

class InventoryRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/inventory-entries',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryEntriesCubit>()..init(),
            child: const InventoryEntriesScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/inventory-entries/form',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        final poId =
            args['purchaseOrderId'] ??
            state.uri.queryParameters['purchaseOrderId'];
        return BlocProvider(
          create: (_) => sl<InventoryEntryFormCubit>(),
          child: InventoryEntryFormScreen(
            purchaseOrderId: poId,
            prefillSupplierId: args['prefillSupplierId'],
            prefillSupplierName: args['prefillSupplierName'],
            prefillWarehouseId: args['prefillWarehouseId'],
            prefillItems:
                args['prefillItems'] is List
                    ? (args['prefillItems'] as List)
                        .cast<InventoryEntryItemEntity>()
                    : null,
            prefillDocumentType: args['prefillDocumentType'],
            prefillDocumentNumber: args['prefillDocumentNumber'],
            prefillDocumentDate:
                args['prefillDocumentDate'] is DateTime
                    ? args['prefillDocumentDate'] as DateTime
                    : (args['prefillDocumentDate'] is String
                        ? DateTime.tryParse(args['prefillDocumentDate'])
                        : null),
          ),
        );
      },
    ),
    GoRoute(
      path: '/admin/inventory-exits/form',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryExitFormCubit>(),
            child: const InventoryExitFormScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/inventory-exits',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryExitsCubit>()..initLoad(),
            child: const InventoryExitsScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/inventory',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<InventoryCubit>(),
            child: const InventoryScreen(),
          ),
    ),
    GoRoute(
      path: '/admin/kardex',
      builder: (context, state) {
        final productId = state.uri.queryParameters['productId'];
        final productName = state.uri.queryParameters['productName'];
        final variantId = state.uri.queryParameters['variantId'];
        final variantName = state.uri.queryParameters['variantName'];
        return BlocProvider(
          create: (_) => sl<KardexCubit>(),
          child: KardexScreen(
            initialProductId: productId,
            initialProductName: productName,
            initialVariantId: variantId,
            initialVariantName: variantName,
          ),
        );
      },
    ),
    GoRoute(
      path: '/admin/warehouses',
      builder:
          (context, state) => BlocProvider(
            create: (_) => sl<WarehousesCubit>()..loadWarehouses(),
            child: const WarehousesManagementScreen(),
          ),
    ),
  ];
}
