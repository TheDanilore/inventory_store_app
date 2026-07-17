import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_order_form/purchase_order_form_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credit_movements/supplier_credit_movements_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/purchase_order_form_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/purchase_orders_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/supplier_credit_movements_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/supplier_credits_screen.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/suppliers_screen.dart';

class PurchasesRoutes {
  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'purchase-order-form',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<PurchaseOrderFormCubit>(),
            child: const PurchaseOrderFormScreen(),
          ),
        ),
        GoRoute(
          path: 'purchase-orders',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<PurchaseOrdersCubit>(),
            child: const AdminLayout(
              title: 'Órdenes de Compra',
              showBackButton: true,
              body: PurchaseOrdersScreen(),
            ),
          ),
        ),
        GoRoute(
          path: 'supplier-credit-movements/:creditId',
          builder: (context, state) {
            final creditId = state.pathParameters['creditId'] ?? '';
            final args = state.extra as Map<String, dynamic>? ?? {};
            final supplierName = args['supplierName'] ??
                state.uri.queryParameters['name'] ??
                '';
            return BlocProvider(
              create: (_) => sl<SupplierCreditMovementsCubit>(
                param1: creditId,
                param2: supplierName,
              ),
              child: SupplierCreditMovementsScreen(
                creditId: creditId,
                supplierName: supplierName,
                currentDebt: args['currentDebt'] ??
                    double.tryParse(state.uri.queryParameters['debt'] ?? '0') ??
                    0.0,
                creditLimit: args['creditLimit'] ??
                    double.tryParse(state.uri.queryParameters['limit'] ?? '0') ??
                    0.0,
              ),
            );
          },
        ),
        GoRoute(
          path: 'supplier-credits',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<SupplierCreditsCubit>(),
            child: const AdminLayout(
              title: 'Cuentas por Pagar',
              showBackButton: true,
              body: SupplierCreditsScreen(),
            ),
          ),
        ),
        GoRoute(
          path: 'suppliers',
          builder: (context, state) => BlocProvider(
            create: (_) => sl<SuppliersCubit>(),
            child: const AdminLayout(
              title: 'Directorio de Proveedores',
              showBackButton: true,
              body: SuppliersScreen(),
            ),
          ),
        ),
      ];
}
