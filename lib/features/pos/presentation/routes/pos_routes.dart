import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/admin_pos_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/all_cash_shifts_screen.dart';
import 'package:inventory_store_app/features/pos/presentation/screens/pos_checkout_screen.dart';

class PosRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/admin/pos',
      builder: (context, state) => const AdminPosScreen(),
    ),
    GoRoute(
      path: '/admin/pos-checkout',
      builder: (context, state) => const PosCheckoutScreen(),
    ),
    GoRoute(
      path: '/admin/all-cash-shifts',
      builder: (context, state) => const AllCashShiftsScreen(),
    ),
  ];
}
