import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/system_diagnostics_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_hero_header.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/content/help_tabs_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/tabs/help_content_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/tabs/help_diagnostics_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:go_router/go_router.dart';

/// Centro de Ayuda, Documentación y Telemetría del ERP Danilore One.
/// Orquestador modular de alto rendimiento con búsqueda reactiva sin tildes,
/// catálogo inmutable en memoria y caché Zero-Shimmer en diagnósticos.
class AdminHelpScreen extends StatefulWidget {
  const AdminHelpScreen({super.key});

  @override
  State<AdminHelpScreen> createState() => _AdminHelpScreenState();
}

class _AdminHelpScreenState extends State<AdminHelpScreen>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 8;

  late final TabController _tabController;
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  late final List<HelpTabModel> _docTabs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _searchCtrl = TextEditingController();

    // Catálogo inmutable de manuales
    _docTabs = HelpTabsContent.buildTabs();

    // Carga inicial de diagnósticos con Zero-Shimmer (en memoria SWR)
    context.read<SystemDiagnosticsCubit>().loadDiagnostics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  void _setQuery(String value) {
    setState(() => _searchQuery = value.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  List<String> _searchTokens() {
    final q = _searchQuery.trim();
    if (q.isEmpty) return const [];
    return HelpText.normalize(
      q,
    ).split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet().toList();
  }

  List<HelpSearchHit> _search(List<HelpTabModel> tabs) {
    final tokens = _searchTokens();
    final hits = <HelpSearchHit>[];
    for (var ti = 0; ti < tabs.length; ti++) {
      for (final g in tabs[ti].groups) {
        final groupText = HelpText.normalize(g.title ?? '');
        final matched =
            g.items.where((it) {
              final hay = '$groupText ${HelpText.normalize(it.text)}';
              return tokens.every((tk) => hay.contains(tk));
            }).toList();
        if (matched.isNotEmpty) {
          hits.add(HelpSearchHit(tabIndex: ti, group: g, items: matched));
        }
      }
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);
    final searching = _searchQuery.isNotEmpty;
    final hits = searching ? _search(_docTabs) : const <HelpSearchHit>[];
    final total = hits.fold<int>(0, (sum, h) => sum + h.items.length);
    final searchTokens = _searchTokens();

    return HelpHighlightScope(
      searchTokens: searchTokens,
      tokens: t,
      child: AdminLayout(
        title: 'Ayuda y Soporte',
        breadcrumb: 'ERP > Ayuda y Documentación',
        body: ColoredBox(
          color: t.bg,
          child: NestedScrollView(
            headerSliverBuilder:
                (context, innerBoxIsScrolled) => [
                  SliverToBoxAdapter(
                    child: HelpHeroHeader(
                      searchCtrl: _searchCtrl,
                      searchQuery: _searchQuery,
                      onSearchChanged: _setQuery,
                      onClearSearch: _clearSearch,
                      onChipSelected: (chip) {
                        _searchCtrl.text = chip;
                        _setQuery(chip);
                      },
                      onCopyDiagnostics: () {
                        final cubit = context.read<SystemDiagnosticsCubit>();
                        final d = cubit.state.diagnostics;
                        final report =
                            d?.versionDisplay ?? 'DANILORE ONE ERP v1.4.2';
                        _copyToClipboard(report, 'Diagnóstico del sistema');
                      },
                    ),
                  ),
                ],
            body: Column(
              children: [
                _buildNavBar(t, searching, total),
                Expanded(
                  child:
                      searching
                          ? _buildResultsView(t, hits)
                          : TabBarView(
                            controller: _tabController,
                            children: [
                              for (var i = 0; i < _docTabs.length; i++)
                                HelpContentTab(index: i, tab: _docTabs[i]),
                              const HelpDiagnosticsTab(),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar(HelpThemeTokens t, bool searching, int total) {
    const allTabSpecs = [
      ('Cajas y Mostradores', Icons.point_of_sale_rounded),
      ('Ventas y POS', Icons.shopping_bag_rounded),
      ('Roles y Permisos', Icons.admin_panel_settings_rounded),
      ('Facturación', Icons.receipt_long_rounded),
      ('Finanzas', Icons.account_balance_wallet_rounded),
      ('Inventario', Icons.inventory_2_rounded),
      ('Atajos', Icons.keyboard_rounded),
      ('Diagnóstico & Cloud', Icons.cloud_done_rounded),
    ];

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border),
        ),
      ),
      child:
          searching
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 17, color: t.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$total ${total == 1 ? 'resultado' : 'resultados'} para “$_searchQuery”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.title,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSearch,
                      child: Text(
                        'Limpiar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelColor: t.accent,
                unselectedLabelColor: t.muted,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: t.accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(8),
                tabs: [
                  for (final spec in allTabSpecs)
                    Tab(
                      height: 46,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(spec.$2, size: 17),
                          const SizedBox(width: 8),
                          Text(spec.$1),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  Widget _buildResultsView(HelpThemeTokens t, List<HelpSearchHit> hits) {
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44, color: t.muted),
              const SizedBox(height: 12),
              Text(
                'Sin resultados para “$_searchQuery”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.title,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba con otra palabra clave (ej. “turno”, “yape”, “factura”).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Ver toda la ayuda'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth >= 720 ? 24.0 : 16.0;
        return ListView(
          key: const PageStorageKey<String>('help_search_results'),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < hits.length; i++) ...[
                      if (i > 0) const SizedBox(height: 32),
                      _buildHitItem(t, hits[i]),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHitItem(HelpThemeTokens t, HelpSearchHit h) {
    final tabLabel = _docTabs[h.tabIndex].label;
    final tabIcon = _docTabs[h.tabIndex].icon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              _clearSearch();
              _tabController.animateTo(h.tabIndex);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tabIcon, size: 14, color: t.accent),
                  const SizedBox(width: 6),
                  Text(
                    tabLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: t.accent,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded, size: 16, color: t.accent),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (h.group.title != null) ...[
              HelpSectionHeader(
                title: h.group.title!,
                subtitle: h.group.subtitle,
              ),
              const SizedBox(height: 14),
            ],
            Column(
              children: [
                for (var j = 0; j < h.items.length; j++) ...[
                  if (j > 0) const SizedBox(height: 12),
                  h.items[j].child,
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// Diálogo de compatibilidad que redirige a `/help`.
class AdminHelpDialog extends StatelessWidget {
  const AdminHelpDialog({super.key});

  static Future<void> show(BuildContext context) async {
    context.go('/help');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: sl<SystemDiagnosticsCubit>(),
      child: const AdminHelpScreen(),
    );
  }
}
