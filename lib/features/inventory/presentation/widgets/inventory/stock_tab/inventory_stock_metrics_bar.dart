import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';

class InventoryStockMetricsBar extends StatelessWidget {
  final bool isCompact;

  const InventoryStockMetricsBar({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      InventoryCubit,
      InventoryState,
      (double, int, int, String)
    >(
      selector: (state) {
        if (state is InventoryLoaded) {
          return (
            state.globalTotalCost,
            state.globalTotalStock,
            state.globalLowStockCount,
            state.stockStatusFilter,
          );
        }
        return (0.0, 0, 0, 'all');
      },
      builder: (context, data) {
        final (totalCost, totalStock, lowStockCount, statusFilter) = data;
        final cubit = context.read<InventoryCubit>();

        return Row(
          children: [
            MetricCardItem(
              label: isCompact ? 'Valor Inv.' : 'Valor Total del Inv.',
              value: 'S/ ${totalCost.toStringAsFixed(2)}',
              icon: Icons.monetization_on_rounded,
              color: AppColors.primary,
              isCompact: isCompact,
              tooltip: 'Restablecer vista a todo el catálogo',
              onTap: () => cubit.setStockStatusFilter('all'),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            MetricCardItem(
              label: isCompact ? 'Stock total' : 'Stock Total',
              value: isCompact ? '$totalStock' : '$totalStock uds.',
              icon: Icons.inventory_rounded,
              color: AppColors.teal,
              isCompact: isCompact,
              isSelected: statusFilter == 'in_stock',
              tooltip:
                  isCompact
                      ? 'Filtrar con stock'
                      : 'Filtrar solo productos con stock disponible',
              onTap:
                  () => cubit.setStockStatusFilter(
                    statusFilter == 'in_stock' ? 'all' : 'in_stock',
                  ),
            ),
            SizedBox(width: isCompact ? 8 : 12),
            MetricCardItem(
              label: isCompact ? 'Bajo stock' : 'Productos Bajo Stock',
              value: '$lowStockCount',
              icon: Icons.warning_amber_rounded,
              color: lowStockCount > 0 ? AppColors.warning : AppColors.success,
              highlight: lowStockCount > 0,
              isCompact: isCompact,
              isSelected: statusFilter == 'low_stock',
              tooltip:
                  isCompact
                      ? 'Filtrar bajo stock [B]'
                      : 'Clic para alternar filtro de bajo stock [B]',
              onTap:
                  () => cubit.setStockStatusFilter(
                    statusFilter == 'low_stock' ? 'all' : 'low_stock',
                  ),
            ),
          ],
        );
      },
    );
  }
}

class MetricCardItem extends StatefulWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;
  final bool isCompact;
  final bool isSelected;
  final String? tooltip;
  final VoidCallback? onTap;

  const MetricCardItem({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
    this.isCompact = false,
    this.isSelected = false,
    this.tooltip,
    this.onTap,
  });

  @override
  State<MetricCardItem> createState() => _MetricCardItemState();
}

class _MetricCardItemState extends State<MetricCardItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        widget.isSelected
            ? widget.color
            : (_isHovered
                ? widget.color.withValues(alpha: 0.5)
                : (widget.highlight
                    ? widget.color
                    : InventoryPalette.of(context).border));
    final effectiveBg =
        widget.isSelected
            ? widget.color.withValues(alpha: 0.08)
            : (_isHovered
                ? widget.color.withValues(alpha: 0.03)
                : InventoryPalette.of(context).surface);

    final cardWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCompact ? 8 : 14,
        vertical: widget.isCompact ? 9 : 11,
      ),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: effectiveBorder,
          width: widget.isSelected ? 2 : (widget.highlight ? 1.5 : 1),
        ),
        boxShadow:
            widget.isSelected
                ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
                : AppColors.cardShadow(opacity: _isHovered ? 0.05 : 0.02),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(widget.isCompact ? 5 : 7),
            decoration: BoxDecoration(
              color:
                  widget.isSelected
                      ? widget.color
                      : widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              widget.icon,
              size: widget.isCompact ? 14 : 16,
              color: widget.isSelected ? Colors.white : widget.color,
            ),
          ),
          SizedBox(width: widget.isCompact ? 6 : 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: widget.isCompact ? 10 : 11,
                          color: InventoryPalette.of(context).textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'ACTIVO',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: widget.isCompact ? 13 : 15,
                      fontWeight: FontWeight.w900,
                      color:
                          (widget.highlight || widget.isSelected)
                              ? widget.color
                              : InventoryPalette.of(context).textPrimary,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget interactive = cardWidget;
    if (widget.onTap != null) {
      interactive = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: cardWidget,
        ),
      );
    }

    if (widget.tooltip != null) {
      interactive = Tooltip(message: widget.tooltip!, child: interactive);
    }

    return Expanded(child: interactive);
  }
}
