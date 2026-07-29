import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_search_repository.dart';

@LazySingleton(as: CatalogSearchRepository)
class CatalogSearchRepositoryImpl implements CatalogSearchRepository {
  static const String _searchHistoryKey = 'catalog_search_history';

  @override
  Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_searchHistoryKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveSearchHistory(List<String> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_searchHistoryKey, history);
    } catch (_) {}
  }

  @override
  Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (_) {}
  }
}
