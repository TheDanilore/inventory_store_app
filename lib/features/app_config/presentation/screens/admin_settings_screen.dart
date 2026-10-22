import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/barcode_scanner_hardware_service.dart';
import 'package:inventory_store_app/core/services/pos_printer_settings_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/currencies_settings_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/scanner_settings_hub_tab.dart';

/// Pantalla completa de Configuración del ERP (Linear / Apple HIG Style)
/// Totalmente configurable e interactiva (Vibración, Sonido, Impresora POS, Puntos, Monedas, Empresa).
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
  final TextEditingController _printerFooterCtrl = TextEditingController();
  bool _isPrintingTestTicket = false;
  bool _isSavingLoyalty = false;

  static const _tabs = [
    _TabSpec(
      title: 'Empresa',
      subtitle: 'Datos comerciales',
      icon: Icons.storefront_rounded,
    ),
    _TabSpec(
      title: 'Monedas',
      subtitle: 'Divisas y tipo de cambio',
      icon: Icons.currency_exchange_rounded,
    ),
    _TabSpec(
      title: 'Apariencia',
      subtitle: 'Tema e interacción',
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

    // Inicializar servicios de hardware y preferencias
    BarcodeScannerHardwareService.init();
    PosPrinterSettingsService.init().then((_) {
      if (mounted) {
        _printerFooterCtrl.text =
            PosPrinterSettingsService.footerMessageNotifier.value;
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
    _printerFooterCtrl.dispose();
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
                          CurrenciesSettingsTab(isDark: isDark),
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
        final logoUrl = info?.logoUrl;

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
                if (logoUrl != null && logoUrl.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
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
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            logoUrl,
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (c, e, s) => const Icon(
                                  Icons.business_rounded,
                                  size: 32,
                                ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Logotipo Oficial Activo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Visible en tickets, comprobantes y reportes',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                _buildInfoTile(
                  context,
                  isDark: isDark,
                  icon: Icons.badge_outlined,
                  title: 'Nombre Comercial',
                  value: name,
                  badge: 'Moneda Base: PEN (S/)',
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

  // ── Tab 2: Apariencia & Interacción ───────────────────────────────────────
  Widget _buildAppearanceView(BuildContext context, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Tema visual ──
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

        // ── Preferencias de Interacción (Vibración y Sonido interactivos) ──
        _buildSectionCard(
          context,
          isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Preferencias de Interacción y Hardware',
          subtitle:
              'Configura y prueba la vibración, sonidos de confirmación y atajos de teclado',
          children: [
            // Switch 1: Vibración / Feedback Háptico
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.hapticNotifier,
              builder: (context, isHapticEnabled, _) {
                return _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.vibration_rounded,
                  title: 'Feedback Háptico (Vibración)',
                  subtitle:
                      'Vibración táctil al escanear productos, presionar botones clave y cobrar.',
                  value: isHapticEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setHapticFeedback(val);
                    if (val) {
                      HapticFeedback.mediumImpact();
                    }
                  },
                  trailingAction:
                      isHapticEnabled
                          ? TextButton.icon(
                            icon: const Icon(Icons.touch_app_rounded, size: 14),
                            label: const Text(
                              'Probar',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF2563EB),
                            ),
                            onPressed: () => HapticFeedback.heavyImpact(),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Switch 2: Sonido / Bip de Escaneo y Ventas
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.soundBeepNotifier,
              builder: (context, isSoundEnabled, _) {
                return _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.volume_up_rounded,
                  title: 'Sonido y Bip de Confirmación',
                  subtitle:
                      'Emite un sonido auditivo al leer códigos de barras o registrar ventas con éxito.',
                  value: isSoundEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setSoundBeep(val);
                    if (val) {
                      SystemSound.play(SystemSoundType.click);
                    }
                  },
                  trailingAction:
                      isSoundEnabled
                          ? TextButton.icon(
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Probar Sonido',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF10B981),
                            ),
                            onPressed:
                                () => SystemSound.play(SystemSoundType.click),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Item 3: Atajos de Teclado con Modal Informativo
            _buildInteractiveActionTile(
              context,
              isDark: isDark,
              icon: Icons.keyboard_rounded,
              title: 'Atajos Globales de Teclado',
              subtitle:
                  '⌘K / Ctrl+K búsqueda rápida · F2 Cobro POS · Alt+B Guardar borrador',
              actionLabel: 'Ver todos los atajos',
              onActionPressed: () => _showKeyboardShortcutsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  // ── Tab 3: Cuentas Financieras ────────────────────────────────────────────
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

  // ── Tab 4: Puntos & Fidelización (Totalmente Configurable) ─────────────────
  Widget _buildLoyaltyPointsView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (blocCtx, state) {
        final isGlobalEnabled =
            state.businessInfo?.loyaltyGlobalEnabled ?? false;
        final isCustomerVisible =
            state.businessInfo?.loyaltyCustomerVisible ?? false;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.card_giftcard_rounded,
              title: 'Programa de Fidelización y Puntos',
              subtitle:
                  'Activa o desactiva la acumulación de puntos por compras y su visualización para clientes',
              action: FilledButton.icon(
                onPressed: () => context.go('/points-settings'),
                icon: const Icon(Icons.stars_rounded, size: 16),
                label: const Text('Reglas Avanzadas de Puntos'),
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
                // Switch 1: Habilitar Globalmente
                _buildInteractiveSwitchTile(
                  context,
                  isDark: isDark,
                  icon: Icons.power_settings_new_rounded,
                  title: 'Habilitar Sistema de Puntos Globalmente',
                  subtitle:
                      'Permite acumular y canjear puntos en ventas del POS. Si se apaga, desaparece de toda la app.',
                  value: isGlobalEnabled,
                  isLoading: _isSavingLoyalty,
                  badgeText: isGlobalEnabled ? 'ACTIVO' : 'DESACTIVADO',
                  badgeColor:
                      isGlobalEnabled
                          ? const Color(0xFF10B981)
                          : const Color(0xFF64748B),
                  onChanged: (val) async {
                    setState(() => _isSavingLoyalty = true);
                    final success = await context
                        .read<AppConfigCubit>()
                        .updateLoyaltySettings(
                          loyaltyGlobalEnabled: val,
                          loyaltyCustomerVisible:
                              val ? isCustomerVisible : false,
                        );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? (val
                                  ? 'Módulo de Puntos activado con éxito'
                                  : 'Módulo de Puntos desactivado globalmente')
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
                _buildInteractiveSwitchTile(
                  context,
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
                    setState(() => _isSavingLoyalty = true);
                    final success = await context
                        .read<AppConfigCubit>()
                        .updateLoyaltySettings(
                          loyaltyGlobalEnabled: true,
                          loyaltyCustomerVisible: val,
                        );
                    if (!mounted) return;
                    setState(() => _isSavingLoyalty = false);
                    ScaffoldMessenger.of(this.context).showSnackBar(
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
                              : 'El módulo está actualmente apagado. No se generan ni descuentan puntos durante las operaciones de venta.',
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

  // ── Tab 5: Impresora POS (Totalmente Configurable) ─────────────────────────
  Widget _buildPrinterView(BuildContext context, bool isDark) {
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final businessName = info?.businessName ?? 'DANILORE ONE ERP';
        final taxId = info?.taxId ?? '10751565149';
        final address = info?.address ?? 'Virtual';
        final phone = info?.phone ?? '';

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionCard(
              context,
              isDark: isDark,
              icon: Icons.print_rounded,
              title: 'Configuración de Impresión Térmica POS',
              subtitle:
                  'Ajusta el ancho de papel, disparo automático de tickets y realiza pruebas de corte y texto',
              children: [
                // 1. Selector de Ancho de Papel
                ValueListenableBuilder<String>(
                  valueListenable: PosPrinterSettingsService.paperWidthNotifier,
                  builder: (context, currentWidth, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ancho del Rollo de Papel Térmico',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentWidth,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaperWidthOption(
                                  width: '80mm',
                                  label: '80 mm (Estándar POS)',
                                  desc:
                                      'Ticketeras fijas USB/Red (Epson, Bixolon, Xprinter)',
                                  isSelected: currentWidth == '80mm',
                                  isDark: isDark,
                                  onTap:
                                      () =>
                                          PosPrinterSettingsService.setPaperWidth(
                                            '80mm',
                                          ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildPaperWidthOption(
                                  width: '58mm',
                                  label: '58 mm (Compacto)',
                                  desc:
                                      'Ticketeras móviles Bluetooth y terminales portátiles',
                                  isSelected: currentWidth == '58mm',
                                  isDark: isDark,
                                  onTap:
                                      () =>
                                          PosPrinterSettingsService.setPaperWidth(
                                            '58mm',
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Impresión Automática al Cobrar
                ValueListenableBuilder<bool>(
                  valueListenable: PosPrinterSettingsService.autoPrintNotifier,
                  builder: (context, autoPrint, _) {
                    return _buildInteractiveSwitchTile(
                      context,
                      isDark: isDark,
                      icon: Icons.auto_mode_rounded,
                      title: 'Impresión Automática al Cobrar',
                      subtitle:
                          'Abre el cuadro de diálogo de impresión automáticamente al completar una venta en el POS.',
                      value: autoPrint,
                      onChanged: (val) {
                        PosPrinterSettingsService.setAutoPrint(val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Cantidad de Copias
                ValueListenableBuilder<int>(
                  valueListenable: PosPrinterSettingsService.copiesNotifier,
                  builder: (context, copies, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
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
                            Icons.copy_rounded,
                            color: Color(0xFF64748B),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Copias del Comprobante',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '1 copia para el cliente, o 2 para control interno de almacén/cocina',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 Copia')),
                              ButtonSegment(value: 2, label: Text('2 Copias')),
                            ],
                            selected: {copies},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) {
                                PosPrinterSettingsService.setCopies(set.first);
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Mensaje del Pie de Página del Ticket
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.short_text_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mensaje al Pie del Ticket',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _printerFooterCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Ej: ¡Gracias por su compra! Conserve su ticket para cualquier garantía.',
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text('Guardar Mensaje'),
                          onPressed: () async {
                            await PosPrinterSettingsService.setFooterMessage(
                              _printerFooterCtrl.text.trim(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pie de ticket actualizado correctamente',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Laboratorio de Calibración / Impresión de Prueba
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.print_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Laboratorio de Calibración Térmica',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Envía un ticket de prueba para validar alineación, corte y nitidez.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        icon:
                            _isPrintingTestTicket
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          _isPrintingTestTicket
                              ? 'Enviando...'
                              : 'Imprimir Prueba',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed:
                            _isPrintingTestTicket
                                ? null
                                : () async {
                                  setState(() => _isPrintingTestTicket = true);
                                  final success =
                                      await PosPrinterSettingsService.printTestTicket(
                                        businessName: businessName,
                                        taxId: taxId,
                                        address: address,
                                        phone: phone,
                                      );
                                  if (!mounted) return;
                                  setState(() => _isPrintingTestTicket = false);
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Ticket de prueba enviado a la cola de impresión'
                                            : 'No se pudo generar el ticket de prueba',
                                      ),
                                      backgroundColor:
                                          success
                                              ? const Color(0xFF10B981)
                                              : AppColors.danger,
                                    ),
                                  );
                                },
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

  Widget _buildPaperWidthOption({
    required String width,
    required String label,
    required String desc,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color:
                      isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                    color:
                        isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : const Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets Responsive ─────────────────────────────────────────────
  Widget _buildSectionCard(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
    required List<Widget> children,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 600;

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
              if (!isNarrow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF3B82F6),
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
                    if (action != null) ...[const SizedBox(width: 12), action],
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: const Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
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
                if (action != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: action),
                ],
              ],
              const SizedBox(height: 16),
              Divider(
                height: 1,
                color:
                    isDark
                        ? AppColors.darkBorderSubtle
                        : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractiveSwitchTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isEnabled = true,
    bool isLoading = false,
    String? badgeText,
    Color? badgeColor,
    Widget? trailingAction,
  }) {
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
                          badgeText,
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
                const SizedBox(height: 2),
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
              ],
            ),
          ),
          if (trailingAction != null) ...[
            trailingAction,
            const SizedBox(width: 8),
          ],
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

  Widget _buildInteractiveActionTile(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onActionPressed,
  }) {
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

  void _showKeyboardShortcutsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkSurfaceElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.keyboard_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text(
                  'Atajos Globales de Teclado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShortcutRow('⌘K / Ctrl+K', 'Búsqueda instantánea ERP'),
                  _buildShortcutRow(
                    'F2',
                    'Abrir cobro de venta en el POS (Checkout)',
                  ),
                  _buildShortcutRow(
                    'Alt + B',
                    'Guardar venta actual como borrador',
                  ),
                  _buildShortcutRow('⌘P / Ctrl+P', 'Reimprimir último ticket'),
                  _buildShortcutRow(
                    'F4',
                    'Enfocar buscador de productos con código de barras',
                  ),
                  _buildShortcutRow('Esc', 'Cerrar modales o cancelar diálogo'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Widget _buildShortcutRow(String keys, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 12.5)),
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
