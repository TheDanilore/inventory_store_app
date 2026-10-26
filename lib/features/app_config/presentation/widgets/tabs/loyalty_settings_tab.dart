import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_scroll_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_section_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_tiles.dart';

class LoyaltySettingsTab extends StatefulWidget {
  final bool isDark;

  const LoyaltySettingsTab({super.key, required this.isDark});

  @override
  State<LoyaltySettingsTab> createState() => _LoyaltySettingsTabState();
}

class _LoyaltySettingsTabState extends State<LoyaltySettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _isSavingLoyalty = false;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;

    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (blocCtx, state) {
        final isGlobalEnabled =
            state.businessInfo?.loyaltyGlobalEnabled ?? false;
        final isCustomerVisible =
            state.businessInfo?.loyaltyCustomerVisible ?? false;

        return SettingsScrollContent(
          isDark: isDark,
          children: [
            SettingsSectionCard(
              isDark: isDark,
              icon: Icons.card_giftcard_rounded,
              title: 'Programa de Fidelización y Puntos',
              subtitle:
                  'Activa o desactiva la acumulación de puntos por compras y su visualización para clientes',
              action: FilledButton.icon(
                onPressed:
                    isGlobalEnabled
                        ? () => context.go('/points-settings')
                        : null,
                icon: const Icon(Icons.stars_rounded, size: 16),
                label: const Text('Reglas Avanzadas de Puntos'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isGlobalEnabled
                          ? const Color(0xFF2563EB)
                          : (isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1)),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                  disabledForegroundColor:
                      isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              children: [
                // Callout Banner de Estado de Puntos
                if (!isGlobalEnabled)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF2D2010)
                              : const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF78350F)
                                : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo de Puntos Desactivado',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFFFDE68A)
                                          : const Color(0xFF92400E),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Para acceder a la vista de reglas avanzadas, acumulación y juegos interactivos, primero debes activar el interruptor principal abajo.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF062A1B)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF047857)
                                : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Módulo de Fidelización Activo en ERP y POS',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFF065F46),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'La vista de reglas avanzadas está habilitada para configurar tasas de canje, acumulación por compras y juegos.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      isDark
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => context.go('/points-settings'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            foregroundColor: const Color(0xFF047857),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Abrir Reglas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // Switch 1: Habilitar Globalmente
                SettingsSwitchTile(
                  isDark: isDark,
                  icon: Icons.power_settings_new_rounded,
                  title: 'Habilitar Sistema de Puntos Globalmente',
                  subtitle:
                      'Permite acumular y canjear puntos en ventas del POS. Si se apaga, desaparece de toda la app y se desactiva el acceso a las reglas de puntos.',
                  value: isGlobalEnabled,
                  isLoading: _isSavingLoyalty,
                  badgeText: isGlobalEnabled ? 'ACTIVO' : 'DESACTIVADO',
                  badgeColor:
                      isGlobalEnabled
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                  onChanged: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final cubit = context.read<AppConfigCubit>();
                    setState(() => _isSavingLoyalty = true);
                    final success = await cubit.updateLoyaltySettings(
                      loyaltyGlobalEnabled: val,
                      loyaltyCustomerVisible: val ? isCustomerVisible : false,
                    );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (val
                                  ? 'Módulo de Puntos activado. Ya puedes acceder a las reglas avanzadas.'
                                  : 'Módulo de Puntos desactivado globalmente.')
                              : 'Error al actualizar el estado de puntos',
                        ),
                        backgroundColor:
                            success
                                ? const Color(0xFF10B981)
                                : AppColors.danger,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Switch 2: Visibilidad para Clientes
                SettingsSwitchTile(
                  isDark: isDark,
                  icon: Icons.visibility_outlined,
                  title: 'Visible para Clientes en el Catálogo Web/Móvil',
                  subtitle:
                      'Muestra a los clientes su saldo de puntos y equivalencia en soles en su perfil y catálogo.',
                  value: isCustomerVisible,
                  isEnabled: isGlobalEnabled,
                  badgeText: isCustomerVisible ? 'VISIBLE' : 'OCULTO',
                  badgeColor:
                      isCustomerVisible
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF64748B),
                  onChanged: (val) async {
                    if (!isGlobalEnabled) return;
                    final messenger = ScaffoldMessenger.of(context);
                    final cubit = context.read<AppConfigCubit>();
                    setState(() => _isSavingLoyalty = true);
                    final success = await cubit.updateLoyaltySettings(
                      loyaltyGlobalEnabled: true,
                      loyaltyCustomerVisible: val,
                    );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (val
                                  ? 'Saldo de puntos ahora visible para clientes'
                                  : 'Saldo de puntos oculto para clientes')
                              : 'Error al guardar la visibilidad de puntos',
                        ),
                        backgroundColor:
                            success
                                ? const Color(0xFF10B981)
                                : AppColors.danger,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Resumen de Regla
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isGlobalEnabled
                              ? 'El sistema está otorgando 1 Punto por cada S/ 10 de compra. 100 Puntos equivalen a S/ 1.00 de descuento en caja.'
                              : 'El módulo está actualmente apagado. No se generan ni descuentan puntos durante las operaciones de venta, y la vista de reglas se encuentra bloqueada.',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFF475569),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
