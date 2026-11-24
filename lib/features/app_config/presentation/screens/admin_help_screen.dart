import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/system_diagnostics_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_hero_header.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_nav_bar.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_search_results_view.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/content/help_tabs_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_search_engine.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/tabs/help_content_tab.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/tabs/help_diagnostics_tab.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Centro de Ayuda, Documentación y Telemetría del ERP Danilore One.
///
/// Provee el singleton [SystemDiagnosticsCubit] mediante `BlocProvider.value`
/// para garantizar disponibilidad en `/help` sin cerrar el singleton al salir
/// de la vista y mantener caché L1/L2 Zero-Shimmer.
class AdminHelpScreen extends StatelessWidget {
  final SystemDiagnosticsCubit? diagnosticsCubit;

  const AdminHelpScreen({super.key, this.diagnosticsCubit});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SystemDiagnosticsCubit>.value(
      value: diagnosticsCubit ?? sl<SystemDiagnosticsCubit>(),
      child: const _AdminHelpView(),
    );
  }
}

class _AdminHelpView extends StatefulWidget {
  const _AdminHelpView();

  @override
  State<_AdminHelpView> createState() => _AdminHelpViewState();
}

class _AdminHelpViewState extends State<_AdminHelpView>
    with SingleTickerProviderStateMixin {
  static const Duration _searchDebounce = Duration(milliseconds: 150);

  static final List<HelpTabModel> _docTabs = HelpTabsContent.tabs;
  static final HelpSearchEngine _searchEngine = HelpSearchEngine.fromTabs(
    _docTabs,
  );

  late final TabController _tabController;
  late final TextEditingController _searchCtrl;
  late final ValueNotifier<HelpSearchResult> _searchResult;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _docTabs.length + 1, vsync: this);
    _searchCtrl = TextEditingController();
    _searchResult = ValueNotifier<HelpSearchResult>(HelpSearchResult.empty);

    // Carga inicial Zero-Shimmer (L1 con TTL -> L2 -> Red con deduplicación in-flight).
    context.read<SystemDiagnosticsCubit>().loadDiagnostics();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchResult.dispose();
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

  void _onSearchChanged(String rawValue) {
    _debounceTimer?.cancel();
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      _searchResult.value = HelpSearchResult.empty;
      return;
    }
    _debounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      _searchResult.value = _searchEngine.search(trimmed);
    });
  }

  void _selectChip(String chip) {
    _debounceTimer?.cancel();
    _searchCtrl.text = chip;
    _searchResult.value = _searchEngine.search(chip);
  }

  void _clearSearch() {
    _debounceTimer?.cancel();
    _searchCtrl.clear();
    _searchResult.value = HelpSearchResult.empty;
  }

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

    return AdminLayout(
      title: 'Ayuda y Soporte',
      breadcrumb: 'ERP > Ayuda y Documentación',
      body: ColoredBox(
        color: t.bg,
        child: ValueListenableBuilder<HelpSearchResult>(
          valueListenable: _searchResult,
          builder: (context, result, _) {
            return HelpHighlightScope(
              searchTokens: result.tokens,
              tokens: t,
              child: NestedScrollView(
                headerSliverBuilder:
                    (context, _) => [
                      SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: HelpHeroHeader(
                            searchCtrl: _searchCtrl,
                            searchQuery: result.query,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _clearSearch,
                            onChipSelected: _selectChip,
                            onCopyDiagnostics: () {
                              final d =
                                  context
                                      .read<SystemDiagnosticsCubit>()
                                      .state
                                      .diagnostics;
                              final isOnline =
                                  context.read<NetworkCubit>().state
                                      is NetworkConnected;
                              final report =
                                  d?.buildDiagnosticReport(
                                    isOnline: isOnline,
                                  ) ??
                                  'DANILORE ONE ERP | DB: PostgreSQL Supabase | Network: ${isOnline ? 'Online' : 'Offline'}';
                              _copyToClipboard(
                                report,
                                'Diagnóstico del sistema',
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                body: Column(
                  children: [
                    HelpNavBar(
                      tabController: _tabController,
                      docTabs: _docTabs,
                      searching: result.isSearching,
                      searchQuery: result.query,
                      totalResults: result.totalItems,
                      onClearSearch: _clearSearch,
                    ),
                    Expanded(
                      child:
                          result.isSearching
                              ? HelpSearchResultsView(
                                docTabs: _docTabs,
                                hits: result.hits,
                                searchQuery: result.query,
                                onClearSearch: _clearSearch,
                                onNavigateToTab: (tabIndex) {
                                  _clearSearch();
                                  _tabController.animateTo(tabIndex);
                                },
                              )
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
            );
          },
        ),
      ),
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
  Widget build(BuildContext context) => const AdminHelpScreen();
}
