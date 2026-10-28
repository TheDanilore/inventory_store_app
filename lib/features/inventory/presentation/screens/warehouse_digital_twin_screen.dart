import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/warehouses/warehouses_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/warehouse_layout_editor_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/warehouse_layout_viewer.dart';

/// Pantalla Ejecutiva del Gemelo Digital Procedural de una Tienda o Almacén.
class WarehouseDigitalTwinScreen extends StatefulWidget {
  final WarehouseEntity warehouse;

  const WarehouseDigitalTwinScreen({super.key, required this.warehouse});

  static Future<void> navigate(
    BuildContext context,
    WarehouseEntity warehouse,
  ) {
    WarehousesCubit? existingCubit;
    try {
      existingCubit = context.read<WarehousesCubit>();
    } catch (_) {}

    final cubit = existingCubit ?? sl<WarehousesCubit>();

    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder:
            (ctx) => BlocProvider.value(
              value: cubit,
              child: WarehouseDigitalTwinScreen(warehouse: warehouse),
            ),
      ),
    );
  }

  @override
  State<WarehouseDigitalTwinScreen> createState() =>
      _WarehouseDigitalTwinScreenState();
}

class _WarehouseDigitalTwinScreenState
    extends State<WarehouseDigitalTwinScreen> {
  late WarehouseLayoutConfig _currentLayout;
  WarehouseZone? _selectedZone;
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    // Si no tiene zonas previas, generar un layout predeterminado de acuerdo al tipo de almacén
    if (widget.warehouse.layoutConfig.isEmpty) {
      if (widget.warehouse.isStore) {
        _currentLayout = WarehouseLayoutConfig.generateDefaultStore();
      } else if (widget.warehouse.isDarkStore) {
        _currentLayout = WarehouseLayoutConfig.generateDefaultDarkStore();
      } else {
        _currentLayout = WarehouseLayoutConfig.generateDefaultCentral();
      }
      _hasUnsavedChanges = true;
    } else {
      _currentLayout = widget.warehouse.layoutConfig;
    }
  }

  Future<void> _openEditor() async {
    final result = await WarehouseLayoutEditorSheet.show(
      context,
      initialConfig: _currentLayout,
      warehouseType: widget.warehouse.type,
    );

    if (result != null) {
      setState(() {
        _currentLayout = result;
        _selectedZone = null;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _saveChanges() async {
    final cubit = context.read<WarehousesCubit>();
    final ok = await cubit.saveWarehouseLayout(
      warehouseId: widget.warehouse.id,
      layoutConfig: _currentLayout,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _hasUnsavedChanges = false;
      });
      AppSnackbar.show(
        context,
        message:
            'Gemelo Digital y distribución guardados correctamente en la nube.',
        type: SnackbarType.success,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar la distribución procedural.',
        type: SnackbarType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final whType = widget.warehouse.warehouseType;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: whType.brandColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(whType.icon, color: whType.brandColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.warehouse.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: whType.brandColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: whType.brandColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          whType.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: whType.brandColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_currentLayout.dimensions.areaSquareMeters.toStringAsFixed(0)} m² útiles • ${_currentLayout.zones.length} módulos y zonas registradas',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Botón Editor Procedural
          OutlinedButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Icons.tune_rounded, size: 16),
            label: const Text('Reconfigurar'),
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary,
              side: BorderSide(
                color:
                    isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 8),

          // Botón Guardar en la Nube
          BlocBuilder<WarehousesCubit, WarehousesState>(
            builder: (context, state) {
              return FilledButton.icon(
                onPressed:
                    _hasUnsavedChanges && !state.isSaving ? _saveChanges : null,
                icon:
                    state.isSaving
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : Icon(
                          _hasUnsavedChanges
                              ? Icons.cloud_upload_rounded
                              : Icons.check_circle_rounded,
                          size: 16,
                          color:
                              _hasUnsavedChanges
                                  ? Colors.white
                                  : const Color(0xFF059669),
                        ),
                label: Text(
                  _hasUnsavedChanges ? 'Guardar Cambios' : 'Sincronizado',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        _hasUnsavedChanges
                            ? Colors.white
                            : const Color(0xFF065F46),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _hasUnsavedChanges
                          ? AppColors.primary
                          : const Color(0xFFD1FAE5),
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              );
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: WarehouseLayoutViewer(
        layout: _currentLayout,
        selectedZone: _selectedZone,
        onZoneSelected: (zone) {
          setState(() {
            _selectedZone = zone;
          });
        },
        onOpenEditor: _openEditor,
      ),
    );
  }
}
