// ─── SECCIÓN DE FIDELIDAD (FEATURE TOGGLES) ───────────────────────────────────
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class LoyaltySection extends StatelessWidget {
  final bool globalEnabled;
  final bool customerVisible;
  final ValueChanged<bool> onGlobalChanged;
  final ValueChanged<bool>? onCustomerVisibleChanged;

  const LoyaltySection({
    super.key,
    required this.globalEnabled,
    required this.customerVisible,
    required this.onGlobalChanged,
    required this.onCustomerVisibleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.stars_rounded,
                color: Colors.amber.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Módulo de Fidelidad y Monedas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Configuración del sistema de recompensas por compras.',
                  style: TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Feature Card 1: Habilitación Global
        _FeatureToggleCard(
          icon: Icons.power_settings_new_rounded,
          iconColor: Colors.amber.shade700,
          iconBackground: Colors.amber.shade50,
          title: 'Habilitar Sistema Globalmente',
          description:
              'Si se apaga, el sistema de monedas y saldo desaparece para toda la aplicación.',
          value: globalEnabled,
          onChanged: onGlobalChanged,
        ),
        const SizedBox(height: 12),

        // Feature Card 2: Visibilidad en Cliente
        _FeatureToggleCard(
          icon: Icons.visibility_outlined,
          iconColor: Colors.indigo.shade600,
          iconBackground: Colors.indigo.shade50,
          title: 'Visible para Clientes',
          description:
              'Permite a los clientes ver su saldo de puntos en el catálogo y perfil.',
          value: customerVisible,
          isEnabled: globalEnabled,
          onChanged: onCustomerVisibleChanged,
        ),
      ],
    );
  }
}

class _FeatureToggleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String description;
  final bool value;
  final bool isEnabled;
  final ValueChanged<bool>? onChanged;

  const _FeatureToggleCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.description,
    required this.value,
    this.isEnabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor =
        isEnabled
            ? (isDark ? AppColors.darkSurface : Colors.white)
            : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              (value && isEnabled)
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isEnabled
                      ? (isDark
                          ? iconColor.withValues(alpha: 0.15)
                          : iconBackground)
                      : (isDark
                          ? const Color(0xFF1E293B)
                          : Colors.grey.shade100),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color:
                  isEnabled
                      ? iconColor
                      : (isDark
                          ? const Color(0xFF64748B)
                          : Colors.grey.shade400),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color:
                        isEnabled
                            ? (isDark
                                ? const Color(0xFFF8FAFC)
                                : Colors.black87)
                            : (isDark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade500),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isEnabled
                            ? (isDark
                                ? const Color(0xFF94A3B8)
                                : Colors.grey.shade600)
                            : (isDark
                                ? const Color(0xFF64748B)
                                : Colors.grey.shade400),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: isEnabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
