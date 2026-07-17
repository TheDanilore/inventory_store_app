import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/screens/financial_accounts_screen.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class FinancialRoutes {
  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'financial-accounts',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => sl<FinancialAccountsCubit>(),
              ),
              BlocProvider(
                create: (_) => sl<AccountMovementsCubit>(),
              ),
            ],
            child: const AdminLayout(
              title: 'Cuentas y Bancos',
              showBackButton: true,
              body: FinancialAccountsScreen(),
            ),
          ),
        ),
      ];
}
