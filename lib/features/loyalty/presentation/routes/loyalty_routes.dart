import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/admin/points_settings_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/top_customers_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/points_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/claw_machine_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/coin_catcher_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/dodge_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/memorama_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/pinata_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/stack_game_screen.dart';
import 'package:inventory_store_app/features/loyalty/presentation/screens/games/super_salto_screen.dart';

class LoyaltyRoutes {
  static List<RouteBase> get adminRoutes => [
    GoRoute(
      path: 'top-customers',
      builder: (context, state) => const TopCustomersScreen(),
    ),
    GoRoute(
      path: 'points-settings',
      builder: (context, state) => const PointsSettingsScreen(),
    ),
  ];

  static List<RouteBase> get customerRoutes => [
    GoRoute(
      path: '/customer/points',
      builder: (context, state) => const PointsScreen(),
    ),
    GoRoute(
      path: '/customer/games/claw-machine/:profileId',
      builder:
          (context, state) => ClawMachineScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/coin-catcher/:profileId',
      builder:
          (context, state) => CoinCatcherGameScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/dodge/:profileId',
      builder:
          (context, state) => DodgeGameScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/memorama/:profileId',
      builder:
          (context, state) => MemoramaGameScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/pinata/:profileId',
      builder:
          (context, state) => PinataGameScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/stack/:profileId',
      builder:
          (context, state) => StackGameScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
    GoRoute(
      path: '/customer/games/super-salto/:profileId',
      builder:
          (context, state) => SuperSaltoScreen(
            profileId: state.pathParameters['profileId'] ?? '',
          ),
    ),
  ];
}
