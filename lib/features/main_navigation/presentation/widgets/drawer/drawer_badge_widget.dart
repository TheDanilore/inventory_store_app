import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';

/// Badge reactivo de pedidos pendientes con soporte Zero-Shimmer (retiene caché).
class DrawerBadgeWidget extends StatelessWidget {
  const DrawerBadgeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SidebarBadgeCubit, SidebarBadgeState>(
      builder: (context, state) {
        final count =
            state is SidebarBadgeLoaded
                ? state.count
                : (state.cachedCount ?? 0);

        if (count > 0) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (state is SidebarBadgeError && state.cachedCount == null) {
          return const Icon(
            Icons.warning_rounded,
            color: AppColors.error,
            size: 14,
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
