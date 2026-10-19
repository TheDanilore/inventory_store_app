import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/screens/business_info_screen.dart';
import 'package:inventory_store_app/features/app_config/presentation/screens/admin_settings_screen.dart';

class AppConfigRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: '/business-info',
      builder: (context, state) => const BusinessInfoScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) {
        final tabStr = state.uri.queryParameters['tab'];
        final initialTab = int.tryParse(tabStr ?? '') ?? 0;
        return AdminSettingsScreen(initialTabIndex: initialTab);
      },
    ),
  ];
}
