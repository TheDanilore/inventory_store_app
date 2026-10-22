import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/file_export_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/export_inventory_excel_usecase.dart';

/// Panel de exportación de inventario a Excel, sobre [AdaptiveDetailSheet]:
/// - **Desktop / Tablet (>= 640dp)**: Slide-over lateral (Esc cierra, Enter exporta).
/// - **Mobile (< 640dp)**: Bottom Sheet con drag handle.
class InventoryExportSheet extends StatefulWidget {
  final String? selectedWarehouseId;
  final String? selectedWarehouseName;
  final List<WarehouseEntity> warehouses;

  const InventoryExportSheet({
    super.key,
    this.selectedWarehouseId,
    this.selectedWarehouseName,
    this.warehouses = const [],
  });

  static Future<void> show(
    BuildContext context, {
    String? selectedWarehouseId,
    String? selectedWarehouseName,
    List<WarehouseEntity> warehouses = const [],
  }) async {
    await AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 460.0,
      breakpoint: 640.0,
      barrierLabel: 'Cerrar exportación',
      builder:
          (ctx) => InventoryExportSheet(
            selectedWarehouseId: selectedWarehouseId,
            selectedWarehouseName: selectedWarehouseName,
            warehouses: warehouses,
          ),
    );
  }

  @override
  State<InventoryExportSheet> createState() => _InventoryExportSheetState();
}

class _InventoryExportSheetState extends State<InventoryExportSheet> {
  late InventoryExportMode _selectedMode;
  String? _targetWarehouseId;
  String? _targetWarehouseName;
  InventoryStockFilterOption _filterOption = InventoryStockFilterOption.all;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _targetWarehouseId = widget.selectedWarehouseId;
    _targetWarehouseName = widget.selectedWarehouseName;

    if (_targetWarehouseId != null && _targetWarehouseId!.isNotEmpty) {
      _selectedMode = InventoryExportMode.byWarehouse;
    } else {
      _selectedMode = InventoryExportMode.consolidated;
    }
  }

  Future<void> _handleExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      final exportUseCase = sl<ExportInventoryExcelUseCase>();
      final result = await exportUseCase(
        warehouseId:
            _selectedMode == InventoryExportMode.consolidated
                ? null
                : _targetWarehouseId,
        warehouseName: _targetWarehouseName,
        mode: _selectedMode,
        filter: _filterOption,
      );

      if (!mounted) return;

      switch (result.outcome) {
        case FileExportOutcome.saved:
          Navigator.of(context).pop();
          AppSnackbar.show(
            context,
            message: 'Inventario exportado con éxito.',
            type: SnackbarType.success,
          );
          break;
        case FileExportOutcome.cancelled:
          setState(() => _isExporting = false);
          AppSnackbar.show(
            context,
            message: 'Exportación cancelada.',
            type: SnackbarType.warning,
          );
          break;
        case FileExportOutcome.failed:
          setState(() => _isExporting = false);
          AppSnackbar.show(
            context,
            message: 'Ocurrió un error al guardar el archivo exportado.',
            type: SnackbarType.error,
          );
          break;
      }
    } catch (e, stackTrace) {
      LoggerService.e(
        'Error al exportar inventario a Excel',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        setState(() => _isExporting = false);
        String userFriendlyMsg = 'Ocurrió un error al exportar el inventario.';
        if (e.toString().contains('SocketException') ||
            e.toString().contains('Failed host lookup')) {
          userFriendlyMsg = 'Error de conexión. Verifica tu acceso a internet.';
        }
        AppSnackbar.show(
          context,
          message: userFriendlyMsg,
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isExporting,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.enter &&
              !_isExporting) {
            _handleExport();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: DetailSheetFrame(
          title: 'Exportar Inventario a Excel',
          subtitle: const Text(
            'Descarga un archivo .csv compatible con Microsoft Excel',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
            ),
            child: const Icon(
              Icons.table_view_rounded,
              color: AppColors.teal,
              size: 22,
            ),
          ),
          bodyPadding: const EdgeInsets.all(24),
          bodyBackgroundColor: AppColors.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. SELECTOR DE ALCANCE / MODO ──
              const Text(
                'ALCANCE DE LA EXPORTACIÓN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Opción 1: Consolidado General
              _ModeOptionCard(
                title: 'Stock General Consolidado',
                subtitle:
                    '1 fila por variante con el stock total acumulado de toda la empresa.',
                icon: Icons.inventory_2_outlined,
                isSelected: _selectedMode == InventoryExportMode.consolidated,
                onTap: () {
                  setState(() {
                    _selectedMode = InventoryExportMode.consolidated;
                  });
                },
              ),

              const SizedBox(height: 8),

              // Opción 2: Desglosado por Almacén
              _ModeOptionCard(
                title: 'Detallado por Almacén y Lotes',
                subtitle:
                    'Desglosa las existencias, números de lote y vencimientos por cada almacén físico.',
                icon: Icons.warehouse_outlined,
                isSelected: _selectedMode == InventoryExportMode.byWarehouse,
                onTap: () {
                  setState(() {
                    _selectedMode = InventoryExportMode.byWarehouse;
                  });
                },
              ),

              // Si eligió por almacén, selector de almacén específico
              if (_selectedMode == InventoryExportMode.byWarehouse &&
                  widget.warehouses.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Filtrar almacén:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            value: _targetWarehouseId,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los almacenes'),
                              ),
                              ...widget.warehouses.map((wh) {
                                return DropdownMenuItem<String?>(
                                  value: wh.id,
                                  child: Text(wh.name),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _targetWarehouseId = val;
                                if (val != null) {
                                  _targetWarehouseName =
                                      widget.warehouses
                                          .firstWhere((w) => w.id == val)
                                          .name;
                                } else {
                                  _targetWarehouseName = 'Todos los almacenes';
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // ── 2. FILTRO DE EXISTENCIAS ──
              const Text(
                'FILTRAR POR DISPONIBILIDAD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _FilterChip(
                    label: 'Todos los productos',
                    isSelected: _filterOption == InventoryStockFilterOption.all,
                    onTap:
                        () => setState(
                          () => _filterOption = InventoryStockFilterOption.all,
                        ),
                  ),
                  _FilterChip(
                    label: 'Solo con stock (> 0)',
                    isSelected:
                        _filterOption == InventoryStockFilterOption.inStockOnly,
                    onTap:
                        () => setState(
                          () =>
                              _filterOption =
                                  InventoryStockFilterOption.inStockOnly,
                        ),
                  ),
                  _FilterChip(
                    label: 'Bajo stock o agotados',
                    isSelected:
                        _filterOption ==
                        InventoryStockFilterOption.lowStockOnly,
                    onTap:
                        () => setState(
                          () =>
                              _filterOption =
                                  InventoryStockFilterOption.lowStockOnly,
                        ),
                  ),
                ],
              ),
            ],
          ),
          footer: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    _isExporting ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isExporting ? null : _handleExport,
                icon:
                    _isExporting
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.download_rounded, size: 18),
                label: Text(
                  _isExporting ? 'Generando archivo...' : 'Descargar Excel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color:
                          isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
