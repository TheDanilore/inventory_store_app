import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_table.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';

class InventoryStockTable extends StatefulWidget {
  final List<InventoryStockItem> items;
  final InventoryStockItem? selectedItem;
  final ValueChanged<InventoryStockItem> onQuickView;
  final ValueChanged<InventoryStockItem> onOpenDetail;
  final ValueChanged<InventoryStockItem> onKardex;

  /// Muestra el código QR de la variante (icono extra en la columna acciones).
  final ValueChanged<InventoryStockItem>? onShowQr;
  final ValueChanged<InventoryStockItem>? onStockEntry;
  final ValueChanged<InventoryStockItem>? onStockExit;
  final AdminTablePaginationConfig? paginationConfig;
  final bool isLoading;

  const InventoryStockTable({
    super.key,
    required this.items,
    this.selectedItem,
    required this.onQuickView,
    required this.onOpenDetail,
    required this.onKardex,
    this.onShowQr,
    this.onStockEntry,
    this.onStockExit,
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
          cmp = a.productName.toLowerCase().compareTo(
            b.productName.toLowerCase(),
          );
          break;
        case 'sku':
          cmp = (a.sku ?? '').toLowerCase().compareTo(
            (b.sku ?? '').toLowerCase(),
          );
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
          placeholder:
              (context, url) => Container(
                width: size,
                height: size,
                color: AppColors.background,
              ),
          errorWidget:
              (context, url, error) => Container(
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
      itemId:
          (item) => item.variantId.isNotEmpty ? item.variantId : item.productId,
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
                .map(
                  (i) =>
                      '- ${i.productName} (${i.attrsText}): ${i.stock} uds. | Venta: S/ ${i.salePrice.toStringAsFixed(2)}',
                )
                .join('\n');
            final fullText =
                'RESUMEN DE STOCK (${selectedList.length} productos)\n$summary';
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: InventoryPalette.of(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.attrsText.trim().isNotEmpty &&
                          item.attrsText.trim() != 'Única' &&
                          item.attrsText.trim().toLowerCase() !=
                              'variante estándar')
                        Text(
                          item.attrsText,
                          style: TextStyle(
                            fontSize: 11,
                            color: InventoryPalette.of(context).textSecondary,
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
          label: 'SKU / CÓDIGO',
          fixedWidth: 185,
          isSortable: true,
          tooltip: 'Código SKU, código de barras y categoría asignada',
          cellBuilder: (context, item) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.sku?.isNotEmpty == true)
                      InkWell(
                        onTap:
                            () => _copyToClipboard(context, item.sku!, 'SKU'),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: InventoryPalette.of(context).subtle,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: InventoryPalette.of(context).borderStrong,
                            ),
                          ),
                          child: Text(
                            item.sku!,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 10.5,
                              color: InventoryPalette.of(context).textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: InventoryPalette.of(context).subtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sin SKU',
                          style: TextStyle(
                            fontSize: 10,
                            color: InventoryPalette.of(context).textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (item.barcode?.isNotEmpty == true)
                      InkWell(
                        onTap:
                            () => _copyToClipboard(
                              context,
                              item.barcode!,
                              'Código de barras',
                            ),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.barcode_reader,
                                size: 10,
                                color: AppColors.tealDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                item.barcode!,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                  color: AppColors.tealDark,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  style: TextStyle(
                    fontSize: 11,
                    color: InventoryPalette.of(context).textSecondary,
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
                  style: TextStyle(
                    color: InventoryPalette.of(context).textSecondary,
                    fontSize: 11,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Venta: S/ ${item.salePrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: InventoryPalette.of(context).textPrimary,
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

            final Color badgeBg =
                isOut
                    ? InventoryPalette.of(context).dangerBg
                    : (isLow
                        ? InventoryPalette.of(context).warnBg
                        : InventoryPalette.of(context).okBg);
            final Color badgeBorder =
                isOut
                    ? InventoryPalette.of(context).dangerBd
                    : (isLow
                        ? InventoryPalette.of(context).warnBd
                        : InventoryPalette.of(context).okBd);
            final Color badgeColor =
                isOut
                    ? InventoryPalette.of(context).dangerFg
                    : (isLow
                        ? InventoryPalette.of(context).warnFg
                        : InventoryPalette.of(context).okFg);
            final IconData badgeIcon =
                isOut
                    ? Icons.highlight_off_rounded
                    : (isLow
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded);

            return Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3.5,
                ),
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
          fixedWidth:
              (widget.onStockEntry != null || widget.onStockExit != null)
                  ? (widget.onShowQr != null ? 236 : 202)
                  : (widget.onShowQr != null ? 164 : 130),
          alignment: Alignment.centerRight,
          isSortable: false,
          cellBuilder: (context, item) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onStockEntry != null)
                  Tooltip(
                    message: 'Ingresar Stock (Entrada)',
                    child: IconButton(
                      icon: const Icon(Icons.add_box_outlined, size: 17),
                      color: AppColors.tealDark,
                      onPressed: () => widget.onStockEntry!(item),
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (widget.onStockExit != null)
                  Tooltip(
                    message: 'Registrar Salida / Merma',
                    child: IconButton(
                      icon: const Icon(Icons.outbox_rounded, size: 17),
                      color: AppColors.danger,
                      onPressed: () => widget.onStockExit!(item),
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
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
                if (widget.onShowQr != null)
                  Tooltip(
                    message: 'Código QR',
                    child: IconButton(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 17),
                      color: InventoryPalette.of(context).textSecondary,
                      onPressed: () => widget.onShowQr!(item),
                      splashRadius: 16,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Tooltip(
                  message: 'Ver en Kárdex',
                  child: IconButton(
                    icon: const Icon(Icons.receipt_long_rounded, size: 17),
                    color: InventoryPalette.of(context).textSecondary,
                    onPressed: () => widget.onKardex(item),
                    splashRadius: 16,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Tooltip(
                  message: 'Ficha Completa de Producto',
                  child: IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    color: InventoryPalette.of(context).textSecondary,
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
        final Color badgeBg =
            isOut
                ? InventoryPalette.of(context).dangerBg
                : (isLow
                    ? InventoryPalette.of(context).warnBg
                    : InventoryPalette.of(context).okBg);
        final Color badgeColor =
            isOut
                ? InventoryPalette.of(context).dangerFg
                : (isLow
                    ? InventoryPalette.of(context).warnFg
                    : InventoryPalette.of(context).okFg);

        return InkWell(
          onTap: () => widget.onQuickView(item),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? InventoryPalette.of(context).selectedTint
                      : InventoryPalette.of(context).surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isSelected
                        ? AppColors.teal
                        : InventoryPalette.of(context).border,
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
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: InventoryPalette.of(context).textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.attrsText.isNotEmpty &&
                          item.attrsText != 'Única')
                        Text(
                          item.attrsText,
                          style: TextStyle(
                            fontSize: 11,
                            color: InventoryPalette.of(context).textSecondary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${item.stock} uds.',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'S/ ${item.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: InventoryPalette.of(context).textPrimary,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
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
