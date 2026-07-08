import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/points_provider.dart';
import 'package:inventory_store_app/features/orders/presentation/providers/cart_checkout_provider.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';
import 'package:inventory_store_app/features/users/presentation/providers/users_provider.dart';

class AppProviders {
  /// Providers base que no dependen de la autenticación
  static final List<SingleChildWidget> providersExcludingAuth = [
    ChangeNotifierProvider(create: (_) => UsersProvider(role: '')),
    ChangeNotifierProvider(create: (_) => PointsProvider()),
    ChangeNotifierProvider(create: (_) => PosProvider()),
    ChangeNotifierProvider(create: (_) => CartCheckoutProvider()),
  ];
}
