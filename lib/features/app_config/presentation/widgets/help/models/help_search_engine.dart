import 'package:inventory_store_app/features/app_config/presentation/widgets/help/components/help_text.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/help/models/help_doc_models.dart';

/// Resultado inmutable de una consulta en el Centro de Ayuda.
class HelpSearchResult {
  final String query;
  final List<String> tokens;
  final List<HelpSearchHit> hits;
  final int totalItems;

  const HelpSearchResult({
    required this.query,
    required this.tokens,
    required this.hits,
    required this.totalItems,
  });

  static const HelpSearchResult empty = HelpSearchResult(
    query: '',
    tokens: <String>[],
    hits: <HelpSearchHit>[],
    totalItems: 0,
  );

  bool get isSearching => query.isNotEmpty;
}

class _IndexedHelpGroup {
  final int tabIndex;
  final HelpGroupModel group;
  final List<({HelpItemModel item, String haystack})> entries;

  const _IndexedHelpGroup({
    required this.tabIndex,
    required this.group,
    required this.entries,
  });
}

/// Motor de búsqueda pre-indexado para el catálogo estático de ayuda.
///
/// Pre-normaliza los textos una sola vez para evitar asignaciones de strings
/// y compilación repetida de [RegExp] durante la escritura en el buscador.
class HelpSearchEngine {
  static final RegExp _whitespaceRegex = RegExp(r'\s+');

  final List<_IndexedHelpGroup> _groups;

  HelpSearchEngine._(this._groups);

  factory HelpSearchEngine.fromTabs(List<HelpTabModel> tabs) {
    final indexed = <_IndexedHelpGroup>[];
    for (var ti = 0; ti < tabs.length; ti++) {
      for (final group in tabs[ti].groups) {
        final groupNormalized = HelpText.normalize(
          group.title ?? '',
          cache: false,
        );
        final entries = <({HelpItemModel item, String haystack})>[];
        for (final item in group.items) {
          final itemNorm = HelpText.normalize(item.text, cache: false);
          final haystack =
              groupNormalized.isEmpty ? itemNorm : '$groupNormalized $itemNorm';
          entries.add((item: item, haystack: haystack));
        }
        indexed.add(
          _IndexedHelpGroup(tabIndex: ti, group: group, entries: entries),
        );
      }
    }
    return HelpSearchEngine._(List.unmodifiable(indexed));
  }

  static List<String> tokenize(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const <String>[];
    final normalized = HelpText.normalize(trimmed, cache: false);
    final seen = <String>{};
    for (final part in normalized.split(_whitespaceRegex)) {
      if (part.isNotEmpty) {
        seen.add(part);
      }
    }
    return List.unmodifiable(seen);
  }

  HelpSearchResult search(String rawQuery) {
    final query = rawQuery.trim();
    if (query.isEmpty) return HelpSearchResult.empty;

    final tokens = tokenize(query);
    if (tokens.isEmpty) return HelpSearchResult.empty;

    final hits = <HelpSearchHit>[];
    var totalItems = 0;

    for (final group in _groups) {
      final matched = <HelpItemModel>[];
      for (final entry in group.entries) {
        var matchesAll = true;
        for (final token in tokens) {
          if (!entry.haystack.contains(token)) {
            matchesAll = false;
            break;
          }
        }
        if (matchesAll) {
          matched.add(entry.item);
        }
      }
      if (matched.isNotEmpty) {
        totalItems += matched.length;
        hits.add(
          HelpSearchHit(
            tabIndex: group.tabIndex,
            group: group.group,
            items: matched,
          ),
        );
      }
    }

    return HelpSearchResult(
      query: query,
      tokens: tokens,
      hits: hits,
      totalItems: totalItems,
    );
  }
}
