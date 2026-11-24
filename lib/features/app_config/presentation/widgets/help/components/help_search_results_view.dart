import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_components.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Vista lazy de resultados de búsqueda en el Centro de Ayuda.
class HelpSearchResultsView extends StatelessWidget {
  final List<HelpTabModel> docTabs;
  final List<HelpSearchHit> hits;
  final String searchQuery;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onNavigateToTab;

  const HelpSearchResultsView({
    super.key,
    required this.docTabs,
    required this.hits,
    required this.searchQuery,
    required this.onClearSearch,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

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
                'Sin resultados para “$searchQuery”',
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
                onPressed: onClearSearch,
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
        return ListView.separated(
          key: const PageStorageKey<String>('help_search_results'),
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
          itemCount: hits.length,
          separatorBuilder: (_, _) => const SizedBox(height: 32),
          itemBuilder: (context, index) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: _SearchHitCard(
                  tab: docTabs[hits[index].tabIndex],
                  hit: hits[index],
                  onNavigate: () => onNavigateToTab(hits[index].tabIndex),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchHitCard extends StatelessWidget {
  final HelpTabModel tab;
  final HelpSearchHit hit;
  final VoidCallback onNavigate;

  const _SearchHitCard({
    required this.tab,
    required this.hit,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t = HelpThemeTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onNavigate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 14, color: t.accent),
                  const SizedBox(width: 6),
                  Text(
                    tab.label.toUpperCase(),
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
        if (hit.group.title != null) ...[
          HelpSectionHeader(
            title: hit.group.title!,
            subtitle: hit.group.subtitle,
          ),
          const SizedBox(height: 14),
        ],
        Column(
          children: [
            for (var j = 0; j < hit.items.length; j++) ...[
              if (j > 0) const SizedBox(height: 12),
              hit.items[j].child,
            ],
          ],
        ),
      ],
    );
  }
}
