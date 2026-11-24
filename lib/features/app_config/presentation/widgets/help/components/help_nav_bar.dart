import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Barra de pestañas / contador de resultados del Centro de Ayuda.
/// Deriva dinámicamente sus pestañas desde [docTabs] para mantener una única fuente de verdad.
class HelpNavBar extends StatelessWidget {
  final TabController tabController;
  final List<HelpTabModel> docTabs;
  final bool searching;
  final String searchQuery;
  final int totalResults;
  final VoidCallback onClearSearch;

  const HelpNavBar({
    super.key,
    required this.tabController,
    required this.docTabs,
    required this.searching,
    required this.searchQuery,
    required this.totalResults,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

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
                        '$totalResults ${totalResults == 1 ? 'resultado' : 'resultados'} para “$searchQuery”',
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
                      onPressed: onClearSearch,
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
                controller: tabController,
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
                  for (final tab in docTabs) _buildTab(tab.label, tab.icon),
                  _buildTab('Diagnóstico & Cloud', Icons.cloud_done_rounded),
                ],
              ),
    );
  }

  Widget _buildTab(String label, IconData icon) {
    return Tab(
      height: 46,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 17), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}
