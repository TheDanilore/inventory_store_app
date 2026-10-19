import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/scanner_settings_hub_tab.dart';

/// Pantalla completa de Configuración del ERP (Linear / Apple HIG Style)
class AdminSettingsScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminSettingsScreen({super.key, this.initialTabIndex = 0});

  static void open(BuildContext context, {int tabIndex = 0}) {
    context.go('/settings?tab=$tabIndex');
  }

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    _TabSpec(
      title: 'Empresa',
      subtitle: 'Datos comerciales',
      icon: Icons.storefront_rounded,
    ),
    _TabSpec(
      title: 'Apariencia',
      subtitle: 'Tema y visuales',
      icon: Icons.palette_outlined,
    ),
    _TabSpec(
      title: 'Cuentas',
      subtitle: 'Cajas y bancos',
      icon: Icons.account_balance_rounded,
    ),
    _TabSpec(
      title: 'Puntos',
      subtitle: 'Fidelización',
      icon: Icons.card_giftcard_rounded,
    ),
    _TabSpec(
      title: 'Impresora POS',
      subtitle: 'Tickets térmicos',
      icon: Icons.print_rounded,
    ),
    _TabSpec(
      title: 'Lectores y Escáneres',
      subtitle: 'Pistolas USB / BT',
      icon: Icons.qr_code_scanner_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });

    final cubit = context.read<AppConfigCubit>();
    if (cubit.state.businessInfo == null) {
      cubit.loadBusinessInfo();
    }
  }

  @override
  void didUpdateWidget(covariant AdminSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex) {
      final target = widget.initialTabIndex.clamp(0, _tabs.length - 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AdminLayout(
      title: 'Configuraciones',
      breadcrumb: 'Configuración > Sistema',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;

          return Container(
            color: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero Banner Header ──────────────────────────────
                    _buildHeroHeader(context, isDark, isDesktop),

                    // ── Segmented Navigation Bar ────────────────────────
                    _buildSegmentedTabBar(context, isDark),

                    // ── Content Area ────────────────────────────────────
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBusinessView(context, isDark),
                          _buildAppearanceView(context, isDark),
                          _buildFinancialAccountsView(context, isDark),
                          _buildLoyaltyPointsView(context, isDark),
                          _buildPrinterView(context, isDark),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: ScannerSettingsHubTab(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Hero Header ───────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_suggest_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Configuraciones del Sistema',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 17,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? AppColors.darkTextPrimary
                            : const Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Parámetros operacionales, identidad corporativa, apariencia y hardware de venta',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 11.5,
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
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                  SizedBox(width: 6),
                  Text(
                    'ERP Operativo',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Segmented Tab Bar ─────────────────────────────────────────────────────
  Widget _buildSegmentedTabBar(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131C2E) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        tabs:
            _tabs.map((tab) {
              return Tab(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 17),
                      const SizedBox(width: 8),
                      Text(tab.title),
                    ],
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  // ── Tab 0: Empresa & Negocio ──────────────────────────────────────────────
  Widget _buildBusinessView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final name = info?.businessName ?? 'DANILORE ONE ERP';
        final ruc = info?.taxId ?? '10751565149';
        final address = info?.address ?? 'Virtual';
        final phone = info?.phone ?? '936081881';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.storefront_rounded,
              title: 'Identidad Comercial de la Empresa',
              subtitle:
                  'Información principal impresa en comprobantes de venta y tickets',
              action: FilledButton.icon(
                onPressed: () => context.go('/business-info'),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Editar Información Completa'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
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
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.badge_outlined,
                  title: 'Nombre Comercial',
                  value: name,
                  badge: 'Moneda: PEN (S/)',
                ),
                const SizedBox(height: 10),
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.pin_outlined,
                  title: 'RUC / Identificación Fiscal',
                  value: ruc,
                  badge: 'IGV: 18%',
                ),
                const SizedBox(height: 10),
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.location_on_outlined,
                  title: 'Dirección Comercial',
                  value: address,
                  badge: 'Tel: $phone',
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.cloud_done_rounded,
              title: 'Infraestructura de Datos & Nube',
              subtitle: 'Conexión activa con el backend Supabase',
              children: [
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.cloud_done_rounded,
                  title: 'Base de Datos Cloud',
                  value: 'Supabase PostgreSQL con RLS Activo',
                  badge: 'Conectado',
                  badgeColor: const Color(0xFF10B981),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // ── Tab 1: Apariencia & Interfaz ──────────────────────────────────────────
  Widget _buildAppearanceView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.palette_outlined,
          title: 'Tema y Paleta Visual',
          subtitle:
              'Personaliza la interfaz de usuario en toda la plataforma ERP',
          children: [
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, currentMode) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;

                    final options = [
                      _ThemeOptionItem(
                        mode: ThemeMode.light,
                        title: 'Claro Ejecutivo',
                        subtitle: 'Estilo Apple / Linear HIG',
                        icon: Icons.light_mode_rounded,
                        isSelected: currentMode == ThemeMode.light,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.dark,
                        title: 'Oscuro Midnight',
                        subtitle: 'Slate Navy (#0B0F19)',
                        icon: Icons.dark_mode_rounded,
                        isSelected: currentMode == ThemeMode.dark,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.system,
                        title: 'Automático',
                        subtitle: 'Sincronizado con el SO',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: currentMode == ThemeMode.system,
                      ),
                    ];

                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      children:
                          options.map((opt) {
                            final card = InkWell(
                              onTap: () {
                                context.read<ThemeCubit>().setThemeMode(
                                  opt.mode,
                                );
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
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
                                    width: opt.isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      opt.icon,
                                      size: 22,
                                      color:
                                          opt.isSelected
                                              ? const Color(0xFF3B82F6)
                                              : (isDark
                                                  ? AppColors.darkTextSecondary
                                                  : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
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
                                          const SizedBox(height: 2),
                                          Text(
                                            opt.subtitle,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color:
                                                  isDark
                                                      ? AppColors.darkTextMuted
                                                      : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (opt.isSelected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 18,
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
                                    horizontal: 6,
                                  ),
                                  child: card,
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: card,
                            );
                          }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Preferencias de Interacción',
          subtitle: 'Comportamiento del teclado y respuesta háptica táctil',
          children: [
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.vibration_rounded,
              title: 'Feedback Háptico',
              value: 'Respuesta táctil y vibración en escaneos y cobros',
              badge: 'Activado',
            ),
            const SizedBox(height: 10),
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.keyboard_rounded,
              title: 'Atajos Globales de Teclado',
              value:
                  '⌘K / Ctrl+K búsqueda instantánea · F2 Cobrar · Alt+B Borrador',
              badge: 'Habilitados',
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 2: Cuentas Financieras ────────────────────────────────────────────
  Widget _buildFinancialAccountsView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.account_balance_wallet_rounded,
          title: 'Cuentas Financieras & Cajas',
          subtitle:
              'Administra cuentas bancarias, billeteras digitales y cajas receptoras',
          action: FilledButton.icon(
            onPressed: () => context.go('/financial-accounts'),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Administrar Cuentas'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          children: [
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.payments_outlined,
              title: 'Métodos de Pago Activos',
              value:
                  'Efectivo en Caja Principal, Yape, Plin, BCP, BBVA, Crédito',
              badge: 'Configurado',
              badgeColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.currency_exchange_rounded,
              title: 'Moneda del Sistema',
              value: 'Soles Peruanos (PEN - S/)',
              badge: 'Predeterminada',
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 3: Puntos & Fidelización ──────────────────────────────────────────
  Widget _buildLoyaltyPointsView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.card_giftcard_rounded,
          title: 'Programa de Fidelización y Puntos',
          subtitle:
              'Premios por compras recurrentes y saldo en billetera para clientes',
          action: FilledButton.icon(
            onPressed: () => context.go('/points-settings'),
            icon: const Icon(Icons.stars_rounded, size: 16),
            label: const Text('Gestionar Puntos'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          children: [
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.loyalty_rounded,
              title: 'Módulo de Puntos Activo',
              value:
                  'Acumulación y canje automático en el Punto de Venta (POS)',
              badge: 'Activo',
              badgeColor: const Color(0xFF10B981),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 4: Impresora POS ──────────────────────────────────────────────────
  Widget _buildPrinterView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.print_rounded,
          title: 'Configuración de Impresión de Tickets POS',
          subtitle:
              'Parámetros para ticketeras térmicas conectadas por USB, Red o Bluetooth',
          children: [
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.receipt_long_rounded,
              title: 'Ancho de Papel Térmico',
              value:
                  '80 mm (Estándar para boletas, facturas y tickets rápidos)',
              badge: '80 mm Predeterminado',
            ),
            const SizedBox(height: 10),
            _buildInfoTile(
              context,
              isDark: isDark,
              icon: Icons.auto_mode_rounded,
              title: 'Impresión Automática',
              value:
                  'Preguntar o disparar impresión al confirmar cobro en caja',
              badge: 'Opcional en Cobro',
            ),
          ],
        ),
      ],
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color:
                isDark ? AppColors.darkBorderSubtle : const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String value,
    required String badge,
    Color? badgeColor,
  }) {
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

class _TabSpec {
  final String title;
  final String subtitle;
  final IconData icon;

  const _TabSpec({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
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
