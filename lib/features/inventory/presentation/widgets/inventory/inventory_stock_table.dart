import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

class InventoryStockTable extends StatefulWidget {
  final List<InventoryStockItem> items;
  final InventoryStockItem? selectedItem;
  final ValueChanged<InventoryStockItem> onQuickView;
  final ValueChanged<InventoryStockItem> onOpenDetail;
  final ValueChanged<InventoryStockItem> onKardex;
  final AdminTablePaginationConfig? paginationConfig;
  final bool isLoading;

  const InventoryStockTable({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onQuickView,
    required this.onOpenDetail,
    required this.onKardex,
    this.paginationConfig,
    this.isLoading = false,
  });

  @override
  State<InventoryStockTable> createState() => _InventoryStockTableState();
}

class _InventoryStockTableState extends State<InventoryStockTable> {
  final Set<Object> _selectedIds = {};
  String? _sortColumnId;
  bool _isSortAscending = true;

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.success,
    );
  }

  List<InventoryStockItem> _getSortedItems() {
    if (_sortColumnId == null) return widget.items;
    final list = List<InventoryStockItem>.from(widget.items);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumnId) {
        case 'product':
          cmp = a.productName.toLowerCase().compareTo(b.productName.toLowerCase());
          break;
        case 'sku':
          cmp = (a.sku ?? '').toLowerCase().compareTo((b.sku ?? '').toLowerCase());
          break;
        case 'pricing':
          cmp = a.salePrice.compareTo(b.salePrice);
          break;
        case 'stock':
          cmp = a.stock.compareTo(b.stock);
          break;
      }
      return _isSortAscending ? cmp : -cmp;
    });
    return list;
  }

  static Widget buildAvatar(String? imageUrl, {double size = 36}) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: 120,
          memCacheHeight: 120,
          maxWidthDiskCache: 250,
          maxHeightDiskCache: 250,
          placeholder: (context, url) => Container(
            width: size,
            height: size,
            color: AppColors.background,
          ),
          errorWidget: (context, url, error) => Container(
            width: size,
            height: size,
            color: AppColors.background,
            child: const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.border,
              size: 16,
            ),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primary,
        size: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sortedList = _getSortedItems();

    return AdminProTable<InventoryStockItem>(
      items: sortedList,
      itemId: (item) => item.variantId.isNotEmpty ? item.variantId : item.productId,
      selectedIds: _selectedIds,
      onSelectionChanged: (newSet) {
        setState(() {
          _selectedIds.clear();
          _selectedIds.addAll(newSet);
        });
      },
      sortColumnId: _sortColumnId,
      isSortAscending: _isSortAscending,
      onSort: (colId, isAsc) {
        setState(() {
          _sortColumnId = colId;
          _isSortAscending = isAsc;
        });
      },
      paginationConfig: widget.paginationConfig,
      onRowTap: widget.onQuickView,
      isLoading: widget.isLoading,
      minTableWidth: 960.0,
      margin: EdgeInsets.zero,
      bulkActions: [
        AdminBulkAction<InventoryStockItem>(
          label: 'Copiar SKUs',
          icon: Icons.copy_rounded,
          onPressed: (selectedList) {
            final skus = selectedList
                .map((i) => i.sku?.isNotEmpty == true ? i.sku! : i.productName)
                .join(', ');
            _copyToClipboard(context, skus, '${selectedList.length} SKUs');
          },
        ),
        AdminBulkAction<InventoryStockItem>(
          label: 'Copiar Resumen de Stock',
          icon: Icons.summarize_rounded,
          customColor: AppColors.teal,
          onPressed: (selectedList) {
            final summary = selectedList
                .map((i) => '- ${i.productName} (${i.attrsText}): ${i.stock} uds. | Venta: S/ ${i.salePrice.toStringAsFixed(2)}')
                .join('\n');
            final fullText = 'RESUMEN DE STOCK (${selectedList.length} productos)\n$summary';
            _copyToClipboard(context, fullText, 'Resumen de stock');
          },
        ),
      ],
      columns: [
        // 1. Producto (Avatar + Nombre + Variante)
        AdminTableColumn<InventoryStockItem>(
          id: 'product',
          label: 'PRODUCTO / VARIANTE',
          flex: 5,
          isSortable: true,
          tooltip: 'Nombre del producto y variante de inventario',
          cellBuilder: (context, item) {
            return Row(
              children: [
                buildAvatar(item.imageUrl, size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.attrsText.trim().isNotEmpty &&
                          item.attrsText.trim() != 'Única' &&
                          item.attrsText.trim().toLowerCase() != 'variante estándar')
                        Text(
                          item.attrsText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        // 2. SKU / Categoría
        AdminTableColumn<InventoryStockItem>(
          id: 'sku',
          label: 'SKU / CATEGORÍA',
          fixedWidth: 170,
          isSortable: true,
          tooltip: 'Código SKU y categoría asignada',
          cellBuilder: (context, item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.sku?.isNotEmpty == true)
                  InkWell(
                    onTap: () => _copyToClipboard(context, item.sku!, 'SKU'),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Text(
                        item.sku!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Sin SKU',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),

        // 3. Costo / Venta
        AdminTableColumn<InventoryStockItem>(
          id: 'pricing',
          label: 'COSTO / VENTA',
          fixedWidth: 160,
          isSortable: true,
          tooltip: 'Costo unitario y precio de venta al público',
          cellBuilder: (context, item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Costo: S/ ${item.unitCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Venta: S/ ${item.salePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: Color(0xFF0F172A),
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            );
          },
        ),

        // 4. Disponibilidad
        AdminTableColumn<InventoryStockItem>(
          id: 'stock',
          label: 'DISPONIBILIDAD',
          fixedWidth: 150,
          isSortable: true,
          tooltip: 'Unidades físicas disponibles en almacén',
          cellBuilder: (context, item) {
            final isOut = item.stock <= 0;
            final isLow = item.isLowStock;

            final Color badgeBg = isOut
                ? const Color(0xFFFEE2E2)
                : (isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7));
            final Color badgeBorder = isOut
                ? const Color(0xFFFCA5A5)
                : (isLow ? const Color(0xFFFCD34D) : const Color(0xFF86EFAC));
            final Color badgeColor = isOut
                ? const Color(0xFF991B1B)
                : (isLow ? const Color(0xFF92400E) : const Color(0xFF166534));
            final IconData badgeIcon = isOut
                ? Icons.highlight_off_rounded
                : (isLow ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded);

            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 12, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      '${item.stock} uds.',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // 5. Acciones
        AdminTableColumn<InventoryStockItem>(
          id: 'actions',
          label: 'ACCIONES',
          fixedWidth: 130,
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, item) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Ficha Rápida y Variantes',
                  child: IconButton(
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    color: AppColors.teal,
                    onPressed: () => widget.onQuickView(item),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Tooltip(
                  message: 'Ver en Kárdex',
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long_rounded, size: 17),
                    color: const Color(0xFF64748B),
                    onPressed: () => widget.onKardex(item),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Tooltip(
                  message: 'Ficha Completa de Producto',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    color: const Color(0xFF64748B),
                    onPressed: () => widget.onOpenDetail(item),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            );
          },
        ),
      ],
      mobileCardBuilder: (context, item, isSelected, onSelect) {
        final isOut = item.stock <= 0;
        final isLow = item.isLowStock;
        final Color badgeBg = isOut
            ? const Color(0xFFFEE2E2)
            : (isLow ? const Color(0xFFFEF3C7) : const Color(0xFFDCFCE7));
        final Color badgeColor = isOut
            ? const Color(0xFF991B1B)
            : (isLow ? const Color(0xFF92400E) : const Color(0xFF166534));

        return InkWell(
          onTap: () => widget.onQuickView(item),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFF0FDFA) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.teal : AppColors.border,
                width: isSelected ? 1.6 : 1,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.03),
            ),
            child: Row(
              children: [
                buildAvatar(item.imageUrl, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.attrsText.isNotEmpty && item.attrsText != 'Única')
                        Text(
                          item.attrsText,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.stock} uds.',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: badgeColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'S/ ${item.salePrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: isSelected,
                  activeColor: AppColors.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: (val) => onSelect(val ?? false),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
