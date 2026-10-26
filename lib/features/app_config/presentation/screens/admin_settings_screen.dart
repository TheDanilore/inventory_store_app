import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_keep_alive_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_hero_header.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/currencies_settings_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/scanner_settings_hub_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/tabs/appearance_settings_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/tabs/business_settings_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/tabs/financial_accounts_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/tabs/loyalty_settings_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/tabs/printer_settings_tab.dart';

/// Pantalla principal de administración y configuración del sistema ERP.
/// Orquesta los módulos de configuración a través de un TabBar responsivo
/// preservando el estado de cada vista en memoria mediante [AppKeepAliveTab].
class AdminSettingsScreen extends StatefulWidget {
  final int initialTabIndex;

  const AdminSettingsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Hero Banner Header (Centrado a 1200) ────────────────────
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: SettingsHeroHeader(
                      isDark: isDark,
                      isDesktop: isDesktop,
                    ),
                  ),
                ),

                // ── Segmented Navigation Bar (Centrado a 1200) ──────────────
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: _buildSegmentedTabBar(context, isDark),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Content Area (Full width -> Scrollbar pegado a la derecha) ─
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      AppKeepAliveTab(
                        child: BusinessSettingsTab(isDark: isDark),
                      ),
                      AppKeepAliveTab(
                        child: CurrenciesSettingsTab(isDark: isDark),
                      ),
                      AppKeepAliveTab(
                        child: AppearanceSettingsTab(isDark: isDark),
                      ),
                      AppKeepAliveTab(
                        child: FinancialAccountsTab(isDark: isDark),
                      ),
                      AppKeepAliveTab(
                        child: LoyaltySettingsTab(isDark: isDark),
                      ),
                      AppKeepAliveTab(
                        child: PrinterSettingsTab(isDark: isDark),
                      ),
                      const AppKeepAliveTab(child: ScannerSettingsHubTab()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Segmented Tab Bar ─────────────────────────────────────────────────────
  Widget _buildSegmentedTabBar(BuildContext context, bool isDark) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20),
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
        physics: const BouncingScrollPhysics(),
        labelColor: Colors.white,
        unselectedLabelColor:
            isDark ? AppColors.darkTextPrimary : const Color(0xFF334155),
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
          fontWeight: FontWeight.w600,
        ),
        tabs:
            _tabs.map((tab) {
              return Tab(
                height: 38,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 16),
                      const SizedBox(width: 7),
                      Text(tab.title),
                    ],
                  ),
                ),
              );
            }).toList(),
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
