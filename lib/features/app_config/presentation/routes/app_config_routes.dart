import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/screens/business_info_screen.dart';

class AppConfigRoutes {
  static List<RouteBase> get adminRoutes => [
        GoRoute(
          path: 'business-info',
          builder: (context, state) => const BusinessInfoScreen(),
        ),
      ];
}
