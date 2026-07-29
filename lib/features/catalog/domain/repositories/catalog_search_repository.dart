abstract class CatalogSearchRepository {
  Future<List<String>> getSearchHistory();
  Future<void> saveSearchHistory(List<String> history);
  Future<void> clearSearchHistory();
}
