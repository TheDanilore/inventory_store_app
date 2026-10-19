import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';

import 'package:inventory_store_app/features/main_navigation/presentation/widgets/scanner_settings_hub_tab.dart';

/// Modal centralizado de Configuración del ERP (Shopeers / Apple HIG Style)
class AdminSettingsDialog extends StatefulWidget {
  final int initialTabIndex;

  const AdminSettingsDialog({super.key, this.initialTabIndex = 0});

  static Future<void> show(BuildContext context, {int initialTabIndex = 0}) {
    context.push('/settings?tab=$initialTabIndex');
    return Future.value();
  }

  @override
  State<AdminSettingsDialog> createState() => _AdminSettingsDialogState();
}

class _AdminSettingsDialogState extends State<AdminSettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 620),
        child: Column(
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFDBEAFE),
                      ),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Configuraciones del Sistema',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ajustes de empresa, interfaz y parámetros operacionales',
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
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color:
                        isDark
                            ? AppColors.darkTextMuted
                            : const Color(0xFF94A3B8),
                    tooltip: 'Cerrar (Esc)',
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),

            // ── Tab Bar Navigation ──────────────────────────────────────
            Container(
              color:
                  isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor:
                    isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                unselectedLabelColor:
                    isDark ? AppColors.darkTextMuted : const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: const Color(0xFF3B82F6),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.storefront_rounded, size: 16),
                    text: 'Empresa',
                  ),
                  Tab(
                    icon: Icon(Icons.palette_outlined, size: 16),
                    text: 'Apariencia',
                  ),
                  Tab(
                    icon: Icon(Icons.account_balance_rounded, size: 16),
                    text: 'Cuentas',
                  ),
                  Tab(
                    icon: Icon(Icons.card_giftcard_rounded, size: 16),
                    text: 'Puntos',
                  ),
                  Tab(
                    icon: Icon(Icons.print_rounded, size: 16),
                    text: 'Impresora POS',
                  ),
                  Tab(
                    icon: Icon(Icons.qr_code_scanner_rounded, size: 16),
                    text: 'Lectores y Escáneres',
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),

            // ── Tab Views ──────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBusinessTab(context),
                  _buildAppearanceTab(context),
                  _buildFinancialAccountsTab(context),
                  _buildLoyaltyPointsTab(context),
                  _buildPrinterTab(context),
                  const ScannerSettingsHubTab(),
                ],
              ),
            ),

            // ── Dialog Footer ──────────────────────────────────────────
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Preferencias del Sistema · Danilore One ERP',
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          isDark
                              ? AppColors.darkTextMuted
                              : const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: const Text(
                      'Listo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessTab(BuildContext context) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final name = info?.businessName ?? 'DANILORE ONE ERP';
        final ruc = info?.taxId ?? '20601234567';
        final address = info?.address ?? 'Av. Principal 123';
        final phone = info?.phone ?? '987 654 321';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSettingRow(
              context,
              icon: Icons.business_rounded,
              title: 'Nombre Comercial',
              subtitle: name,
              trailing: 'Moneda: PEN (S/)',
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              context,
              icon: Icons.numbers_rounded,
              title: 'RUC / Identificación Fiscal',
              subtitle: ruc,
              trailing: 'IGV: 18%',
            ),
            const SizedBox(height: 12),
            _buildSettingRow(
              context,
              icon: Icons.location_on_outlined,
              title: 'Dirección Comercial',
              subtitle: address,
              trailing: phone,
            ),
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/business-info');
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Editar Información Completa de Empresa'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B82F6),
                  side: BorderSide(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFBFDBFE),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceTab(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Card de Selección de Tema Interactivo ───────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                isDark
                    ? AppColors.darkSurfaceElevated
                    : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.palette_outlined,
                      color: Color(0xFF3B82F6),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tema y Apariencia Visual',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark
                                    ? AppColors.darkTextPrimary
                                    : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Selecciona la paleta de colores para toda la plataforma ERP',
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
                ],
              ),
              const SizedBox(height: 16),

              // Opciones de Tema (Claro, Oscuro Midnight Slate, Automático)
              BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, currentMode) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 420;

                      final options = [
                        _ThemeOptionItem(
                          mode: ThemeMode.light,
                          title: 'Claro Ejecutivo',
                          subtitle: 'Apple / Linear HIG',
                          icon: Icons.light_mode_outlined,
                          isSelected: currentMode == ThemeMode.light,
                        ),
                        _ThemeOptionItem(
                          mode: ThemeMode.dark,
                          title: 'Oscuro Midnight',
                          subtitle: 'Slate Navy (#0B0F19)',
                          icon: Icons.dark_mode_outlined,
                          isSelected: currentMode == ThemeMode.dark,
                        ),
                        _ThemeOptionItem(
                          mode: ThemeMode.system,
                          title: 'Automático',
                          subtitle: 'Según el Sistema',
                          icon: Icons.brightness_auto_outlined,
                          isSelected: currentMode == ThemeMode.system,
                        ),
                      ];

                      return Flex(
                        direction: isWide ? Axis.horizontal : Axis.vertical,
                        children:
                            options.map((opt) {
                              final tileWidget = InkWell(
                                onTap: () {
                                  context.read<ThemeCubit>().setThemeMode(
                                    opt.mode,
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        opt.isSelected
                                            ? (isDark
                                                ? const Color(
                                                  0xFF1E3A8A,
                                                ).withValues(alpha: 0.35)
                                                : const Color(0xFFEFF6FF))
                                            : (isDark
                                                ? const Color(0xFF111827)
                                                : Colors.white),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          opt.isSelected
                                              ? const Color(0xFF3B82F6)
                                              : (isDark
                                                  ? AppColors.darkBorderSubtle
                                                  : const Color(0xFFE2E8F0)),
                                      width: opt.isSelected ? 1.8 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        opt.icon,
                                        size: 18,
                                        color:
                                            opt.isSelected
                                                ? const Color(0xFF3B82F6)
                                                : (isDark
                                                    ? AppColors
                                                        .darkTextSecondary
                                                    : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              opt.title,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    opt.isSelected
                                                        ? (isDark
                                                            ? const Color(
                                                              0xFF93C5FD,
                                                            )
                                                            : const Color(
                                                              0xFF1E40AF,
                                                            ))
                                                        : (isDark
                                                            ? AppColors
                                                                .darkTextPrimary
                                                            : const Color(
                                                              0xFF0F172A,
                                                            )),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              opt.subtitle,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color:
                                                    isDark
                                                        ? AppColors
                                                            .darkTextMuted
                                                        : const Color(
                                                          0xFF64748B,
                                                        ),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (opt.isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          size: 16,
                                          color: Color(0xFF3B82F6),
                                        ),
                                    ],
                                  ),
                                ),
                              );

                              if (isWide) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: tileWidget,
                                  ),
                                );
                              } else {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: tileWidget,
                                );
                              }
                            }).toList(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        _buildSettingRow(
          context,
          icon: Icons.vibration_rounded,
          title: 'Feedback Háptico',
          subtitle:
              'Vibración y confirmación táctil en escaneos y acciones rápidas',
          trailing: 'Activado',
        ),
        const SizedBox(height: 14),
        _buildSettingRow(
          context,
          icon: Icons.keyboard_rounded,
          title: 'Atajos Globales de Teclado',
          subtitle:
              'Búsqueda instantánea con ⌘K, recarga con R y filtros con 1..4',
          trailing: 'Habilitados',
        ),
      ],
    );
  }

  Widget _buildFinancialAccountsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          context,
          icon: Icons.account_balance_wallet_rounded,
          title: 'Cuentas Financieras & Cajas',
          subtitle:
              'Administra cuentas bancarias, billeteras digitales (Yape, Plin) y cajas',
          trailing: 'Activas',
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/financial-accounts');
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Administrar Cuentas Financieras'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: BorderSide(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFBFDBFE),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoyaltyPointsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          context,
          icon: Icons.card_giftcard_rounded,
          title: 'Sistema de Fidelización y Puntos',
          subtitle:
              'Define el porcentaje de puntos otorgados por compra y vigencia',
          trailing: 'Configurable',
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/points-settings');
            },
            icon: const Icon(Icons.stars_rounded, size: 18),
            label: const Text('Gestionar Ajustes de Puntos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
              side: BorderSide(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155)
                        : const Color(0xFFBFDBFE),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrinterTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingRow(
          context,
          icon: Icons.print_rounded,
          title: 'Formato de Impresión de Tickets POS',
          subtitle: 'Ancho estándar de comprobantes térmicos para ventas',
          trailing: '80 mm (Térmico)',
        ),
        const SizedBox(height: 14),
        _buildSettingRow(
          context,
          icon: Icons.receipt_long_rounded,
          title: 'Impresión Automática',
          subtitle: 'Disparar impresión al confirmar cobro en terminal de caja',
          trailing: 'Opcional en cobro',
        ),
      ],
    );
  }

  Widget _buildSettingRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceHighlight : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFE2E8F0),
              ),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionItem {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _ThemeOptionItem({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });
}
