import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/inventory_stock_models.dart';
import 'package:inventory_store_app/services/admin/inventory_service.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';
import 'package:inventory_store_app/models/product_model.dart';

class InventoryProvider extends ChangeNotifier {
  final _service = InventoryService();

  // ── Tab 1: Stock General ──
  bool isLoadingStock = true;
  String errorMessageStock = '';
  List<InventoryStockItem> stockItems = [];

  int currentStockPage = 0;
  static const int stockPageSize = 8;
  int totalStockItems = 0;
  int get totalStockPages =>
      totalStockItems == 0 ? 1 : (totalStockItems / stockPageSize).ceil();

  String stockSearchText = '';
  String stockCategoryFilter = 'Todos';
  List<String> categories = ['Todos'];

  // Métricas globales Stock
  int globalTotalVariants = 0;
  int globalTotalStock = 0;
  int globalLowStockCount = 0;
  double globalTotalCost = 0.0;

  // ── Tab 2: Lotes ──
  bool isLoadingBatches = true;
  String errorMessageBatches = '';
  List<InventoryBatchItem> batchItems = [];

  int currentBatchPage = 0;
  static const int batchPageSize = 8;
  int totalBatchItems = 0;
  int get totalBatchPages =>
      totalBatchItems == 0 ? 1 : (totalBatchItems / batchPageSize).ceil();

  String batchSearchText = '';
  String batchStatusFilter = 'Todos';

  // Métricas de lotes (respetan la búsqueda actual)
  int countVencido = 0;
  int countCritico = 0;
  int countProximo = 0;
  int countNormal = 0;

  // ── Inicialización ──
  Future<void> initStockTab() async {
    await _loadCategories();
    await _loadGlobalStockMetrics();
    await fetchStockPage();
  }

  Future<void> initBatchesTab() async {
    await fetchBatchMetrics();
    await fetchBatchPage();
  }

  Future<ProductModel?> fetchProductById(String productId) async {
    try {
      final catalogService = CatalogService();
      return await catalogService.getProductById(productId);
    } catch (e) {
      debugPrint('Error fetching product by id: $e');
      return null;
    }
  }

  // ── Métodos Tab 1 ──
  Future<void> _loadCategories() async {
    try {
      categories = await _service.getCategories();
    } catch (e) {
      debugPrint('Error cargando categorías: $e');
    }
  }

  Future<void> _loadGlobalStockMetrics() async {
    try {
      final metrics = await _service.getGeneralStockMetrics();
      globalTotalVariants = metrics['totalVariants'] ?? 0;
      globalTotalStock = metrics['totalStock'] ?? 0;
      globalLowStockCount = metrics['lowStockCount'] ?? 0;
      globalTotalCost = (metrics['totalCost'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      debugPrint('Error cargando métricas globales de stock: $e');
    }
  }

  Future<void> fetchStockPage() async {
    isLoadingStock = true;
    errorMessageStock = '';
    notifyListeners();

    try {
      totalStockItems = await _service.getTotalGeneralStockCount(
        search: stockSearchText,
        categoryName: stockCategoryFilter,
      );

      if (currentStockPage >= totalStockPages) {
        currentStockPage = 0;
      }

      stockItems = await _service.getGeneralStockPaginated(
        page: currentStockPage,
        pageSize: stockPageSize,
        search: stockSearchText,
        categoryName: stockCategoryFilter,
      );
    } catch (e) {
      debugPrint('Error loading stock: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        errorMessageStock = 'Sin conexión a internet.';
      } else {
        errorMessageStock = 'Error cargando stock.';
      }
    } finally {
      isLoadingStock = false;
      notifyListeners();
    }
  }

  void setStockPage(int page) {
    if (page == currentStockPage) return;
    currentStockPage = page;
    fetchStockPage();
  }

  void setStockSearch(String text) {
    stockSearchText = text;
    currentStockPage = 0;
    fetchStockPage();
  }

  void setStockCategory(String cat) {
    stockCategoryFilter = cat;
    currentStockPage = 0;
    fetchStockPage();
  }

  // ── Métodos Tab 2 ──
  Future<void> fetchBatchMetrics() async {
    try {
      final metrics = await _service.getBatchMetrics(search: batchSearchText);
      countVencido = metrics['vencido'] ?? 0;
      countCritico = metrics['critico'] ?? 0;
      countProximo = metrics['proximo'] ?? 0;
      countNormal = metrics['normal'] ?? 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando métricas de lotes: $e');
    }
  }

  Future<void> fetchBatchPage() async {
    isLoadingBatches = true;
    errorMessageBatches = '';
    notifyListeners();

    try {
      totalBatchItems = await _service.getTotalBatchesCount(
        search: batchSearchText,
        statusFilter: batchStatusFilter,
      );

      if (currentBatchPage >= totalBatchPages) {
        currentBatchPage = 0;
      }

      batchItems = await _service.getBatchesPaginated(
        page: currentBatchPage,
        pageSize: batchPageSize,
        search: batchSearchText,
        statusFilter: batchStatusFilter,
      );
    } catch (e) {
      debugPrint('Error loading batches: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        errorMessageBatches = 'Sin conexión a internet.';
      } else {
        errorMessageBatches = 'Error cargando lotes.';
      }
    } finally {
      isLoadingBatches = false;
      notifyListeners();
    }
  }

  void setBatchPage(int page) {
    if (page == currentBatchPage) return;
    currentBatchPage = page;
    fetchBatchPage();
  }

  void setBatchSearch(String text) {
    batchSearchText = text;
    currentBatchPage = 0;
    fetchBatchMetrics(); // Se actualiza la métrica al buscar
    fetchBatchPage();
  }

  void setBatchStatus(String status) {
    batchStatusFilter = status;
    currentBatchPage = 0;
    fetchBatchPage();
  }
}
