import 'package:flutter/foundation.dart';

/// Configuración de paginación para [AdminProTable].
class AdminTablePaginationConfig {
  final int currentPage; // 1-indexed
  final int pageSize;

  /// Total de registros. Puede ser `null` cuando el backend no lo informa
  /// (p. ej. con filtros activos); en ese caso el pie muestra solo
  /// "página X de Y" y se debe indicar [totalPagesOverride].
  final int? totalItems;

  /// Total de páginas informado por el backend. Si es `null` se calcula a
  /// partir de [totalItems] y [pageSize].
  final int? totalPagesOverride;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;
  final List<int> pageSizeOptions;

  const AdminTablePaginationConfig({
    required this.currentPage,
    required this.pageSize,
    required this.onPageChanged,
    required this.onPageSizeChanged,
    this.totalItems,
    this.totalPagesOverride,
    this.pageSizeOptions = const [15, 25, 50, 100],
  });

  int get totalPages {
    if (totalPagesOverride != null) {
      return totalPagesOverride!.clamp(1, 999999);
    }
    final total = totalItems ?? 0;
    return total <= 0 ? 1 : (total / pageSize).ceil().clamp(1, 999999);
  }

  int get fromItem =>
      (totalItems ?? 0) == 0 ? 0 : ((currentPage - 1) * pageSize) + 1;

  int get toItem =>
      ((currentPage - 1) * pageSize + pageSize).clamp(0, totalItems ?? 0);

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
}

