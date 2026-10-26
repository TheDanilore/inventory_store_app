import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Tile interactivo tipo Switch para configuraciones booleanas con soporte para
/// insignias (badges), estados de carga y deshabilitación.
class SettingsSwitchTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isEnabled;
  final bool isLoading;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailingAction;

  const SettingsSwitchTile({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isEnabled = true,
    this.isLoading = false,
    this.badgeText,
    this.badgeColor,
    this.trailingAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color:
                value && isEnabled
                    ? const Color(0xFF2563EB)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF64748B)),
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color:
                              isEnabled
                                  ? (isDark
                                      ? AppColors.darkTextPrimary
                                      : const Color(0xFF0F172A))
                                  : AppColors.textMuted,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? const Color(0xFF2563EB))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor ?? const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isEnabled
                            ? (isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B))
                            : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (trailingAction != null) ...[
                  const SizedBox(height: 6),
                  trailingAction!,
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Switch.adaptive(
              value: value,
              activeTrackColor: const Color(0xFF2563EB),
              onChanged: isEnabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}

/// Tile con botón de acción lateral para disparar diálogos o atajos.
class SettingsActionTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionPressed;

  const SettingsActionTile({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            size: 20,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onActionPressed,
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(actionLabel, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Tile informativo con insignia (badge) de estado para mostrar parámetros del sistema.
class SettingsInfoTile extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String value;
  final String badge;
  final Color? badgeColor;

  const SettingsInfoTile({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    required this.value,
    required this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBadgeColor = badgeColor ?? const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
            size: 19,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isDark
                            ? AppColors.darkTextSecondary
                            : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: effectiveBadgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: effectiveBadgeColor.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: effectiveBadgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
