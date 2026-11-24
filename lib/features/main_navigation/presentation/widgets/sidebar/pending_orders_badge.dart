import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/sidebar_badge/sidebar_badge_state.dart';

/// Badge reactivo de pedidos pendientes compartido entre [AdminSidebar] y [AppDrawer].
///
/// Usa [BlocSelector] y conserva el conteo cacheado (Zero-Shimmer) durante
/// recargas o fallos transitorios de red.
class PendingOrdersBadge extends StatelessWidget {
  final bool compact;

  const PendingOrdersBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SidebarBadgeCubit,
      SidebarBadgeState,
      ({int count, bool showErrorIcon})
    >(
      selector: (state) {
        final count =
            state is SidebarBadgeLoaded
                ? state.count
                : (state.cachedCount ?? 0);
        final showError =
            state is SidebarBadgeError &&
            state.cachedCount == null &&
            count == 0;
        return (count: count, showErrorIcon: showError);
      },
      builder: (context, data) {
        if (data.count > 0) {
          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 8,
              vertical: compact ? 2 : 3,
            ),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(compact ? 10 : 999),
            ),
            child: Text(
              data.count > 99 ? '99+' : '${data.count}',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (data.showErrorIcon) {
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
