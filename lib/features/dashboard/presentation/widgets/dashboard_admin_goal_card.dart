import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/admin_goal_dialog.dart';
import 'package:inventory_store_app/features/dashboard/presentation/widgets/dashboard_radial_goal_card.dart';

/// Modal auxiliar o bottom sheet para configurar la meta del admin
class AdminGoalHelper {
  static void openGoalDialog(
    BuildContext context,
    double currentAmount,
    double targetAmount,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    if (isDesktop) {
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            elevation: 12,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AdminGoalDialog(
                currentAmount: currentAmount,
                targetAmount: targetAmount,
              ),
            ),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkBorder
                              : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AdminGoalDialog(
                    currentAmount: currentAmount,
                    targetAmount: targetAmount,
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}

/// Widget que conecta con AppConfigCubit para renderizar la meta radial del administrador.
class DashboardAdminGoalCard extends StatelessWidget {
  const DashboardAdminGoalCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<AppConfigCubit, AppConfigState, (double, double)>(
      selector: (_) {
        final config = context.read<AppConfigCubit>();
        return (
          config.getDouble('admin_goal_current', 0.0),
          config.getDouble('admin_goal_target', 2600.0),
        );
      },
      builder: (context, goal) {
        return DashboardRadialGoalCard(
          currentAmount: goal.$1,
          targetAmount: goal.$2,
          onConfigure:
              () => AdminGoalHelper.openGoalDialog(context, goal.$1, goal.$2),
        );
      },
    );
  }
}
