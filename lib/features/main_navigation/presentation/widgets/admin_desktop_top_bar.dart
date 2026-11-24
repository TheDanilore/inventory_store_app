import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_eclipse_button.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_pos_button.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_shell_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/notifications/notification_bell.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/top_bar/top_bar_action_utils.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/top_bar/top_bar_back_section.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/top_bar/top_bar_profile_menu.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/top_bar/top_bar_search_trigger.dart';

/// Barra superior persistente para escritorio del ERP Danilore One.
///
/// Orquesta subcomponentes aislados con [RepaintBoundary], layout flexible sin
/// desbordamientos a 1024px y filtrado único de acciones redundantes.
class AdminDesktopTopBar extends StatelessWidget {
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final bool showBackButton;
  final VoidCallback? onBack;
  final String title;
  final String? breadcrumbText;
  final List<Widget>? actions;
  final bool showSettingsButton;
  final List<PopupMenuEntry<String>>? settingsActions;
  final ValueChanged<String>? onSettingsSelected;

  const AdminDesktopTopBar({
    super.key,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    required this.showBackButton,
    this.onBack,
    required this.title,
    this.breadcrumbText = '',
    this.actions,
    required this.showSettingsButton,
    this.settingsActions,
    this.onSettingsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleActions = TopBarActionUtils.filterVisibleActions(actions);
    final hasSettingsMenu =
        showSettingsButton &&
        settingsActions != null &&
        settingsActions!.isNotEmpty;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBackButton) TopBarBackSection(title: title, onBack: onBack),

          const Flexible(child: TopBarSearchTrigger()),
          const Spacer(),

          if (visibleActions.isNotEmpty) ...[
            for (final action in visibleActions)
              SizedBox(height: 38, child: action),
            const SizedBox(width: 12),
          ],

          const AdminPosButton(),
          const SizedBox(width: 12),

          RepaintBoundary(
            child: ThemeEclipseButton(
              isDark: isDark,
              size: 38,
              tooltip: isDark ? 'Modo Claro' : 'Modo Oscuro',
              onTapWithOrigin: (origin) {
                ThemeCircularWave.switchTheme(context, origin: origin);
              },
            ),
          ),
          const SizedBox(width: 10),

          const RepaintBoundary(child: NotificationBell()),
          const SizedBox(width: 10),

          if (hasSettingsMenu) ...[
            AdminSettingsMenuButton(
              items: settingsActions!,
              onSelected: onSettingsSelected,
            ),
            const SizedBox(width: 10),
          ],

          const TopBarProfileMenu(),
        ],
      ),
    );
  }
}
