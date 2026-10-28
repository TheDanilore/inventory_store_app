import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';

/// Modal / Diálogo responsivo para configurar proceduralmente el layout de una tienda o almacén.
class WarehouseLayoutEditorSheet extends StatefulWidget {
  final WarehouseLayoutConfig initialConfig;
  final String warehouseType; // 'store' o 'warehouse'
  final ValueChanged<WarehouseLayoutConfig> onApply;

  const WarehouseLayoutEditorSheet({
    super.key,
    required this.initialConfig,
    this.warehouseType = 'warehouse',
    required this.onApply,
  });

  static Future<WarehouseLayoutConfig?> show(
    BuildContext context, {
    required WarehouseLayoutConfig initialConfig,
    String warehouseType = 'warehouse',
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog<WarehouseLayoutConfig>(
        context: context,
        useRootNavigator: true,
        builder:
            (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: WarehouseLayoutEditorSheet(
                  initialConfig: initialConfig,
                  warehouseType: warehouseType,
                  onApply: (cfg) => Navigator.of(ctx).pop(cfg),
                ),
              ),
            ),
      );
    } else {
      return showModalBottomSheet<WarehouseLayoutConfig>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        isDismissible: true,
        enableDrag: true,
        backgroundColor: Colors.transparent,
        builder:
            (ctx) => WarehouseLayoutEditorSheet(
              initialConfig: initialConfig,
              warehouseType: warehouseType,
              onApply: (cfg) => Navigator.of(ctx).pop(cfg),
            ),
      );
    }
  }

  @override
  State<WarehouseLayoutEditorSheet> createState() =>
      _WarehouseLayoutEditorSheetState();
}

class _WarehouseLayoutEditorSheetState
    extends State<WarehouseLayoutEditorSheet> {
  late double _widthMeters;
  late double _lengthMeters;
  late double _heightMeters;
  late int _aislesCount;
  late int _shelvesPerAisle;
  late int _levelsPerShelf;
  late String _presetType;

  @override
  void initState() {
    super.initState();
    final cfg = widget.initialConfig;
    _widthMeters = cfg.dimensions.widthMeters;
    _lengthMeters = cfg.dimensions.lengthMeters;
    _heightMeters = cfg.dimensions.heightMeters;
    _aislesCount = cfg.aislesCount > 0 ? cfg.aislesCount : 4;
    _shelvesPerAisle = cfg.shelvesPerAisle > 0 ? cfg.shelvesPerAisle : 4;
    _levelsPerShelf = cfg.levelsPerShelf > 0 ? cfg.levelsPerShelf : 3;
    _presetType = widget.warehouseType == 'store' ? 'store' : 'central';
  }

  WarehouseLayoutConfig _generateCurrentConfig() {
    if (_presetType == 'store') {
      return WarehouseLayoutConfig.generateDefaultStore(
        width: _widthMeters,
        length: _lengthMeters,
        height: _heightMeters,
        gondolaColumns: _aislesCount,
        gondolasPerColumn: _shelvesPerAisle,
        levels: _levelsPerShelf,
      );
    } else if (_presetType == 'dark_store') {
      return WarehouseLayoutConfig.generateDefaultDarkStore(
        width: _widthMeters,
        length: _lengthMeters,
        height: _heightMeters,
        aisles: _aislesCount,
        racksPerAisle: _shelvesPerAisle,
      );
    } else {
      return WarehouseLayoutConfig.generateDefaultCentral(
        width: _widthMeters,
        length: _lengthMeters,
        height: _heightMeters,
        aisles: _aislesCount,
        racksPerAisle: _shelvesPerAisle,
        levels: _levelsPerShelf,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final totalArea = _widthMeters * _lengthMeters;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius:
            isDesktop
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(24, isDesktop ? 20 : 12, 24, 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle exclusivo para móvil
            if (!isDesktop) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            // Cabecera
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.architecture_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generador Procedural de Layout',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Ajusta la receta matemática para regenerar el mapa 3D',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // 1. Selector de Plantilla Operativa
            const Text(
              'PLANTILLA DE DISTRIBUCIÓN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPresetCard(
                    id: 'store',
                    title: 'Tienda Agrícola',
                    subtitle: 'Estantes + Mostrador',
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPresetCard(
                    id: 'central',
                    title: 'Almacén Central',
                    subtitle: 'Racks + Docks',
                    icon: Icons.warehouse_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPresetCard(
                    id: 'dark_store',
                    title: 'Dark Store',
                    subtitle: 'Picking Express',
                    icon: Icons.bolt_rounded,
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 2. Dimensiones del Local (Metros)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DIMENSIONES FÍSICAS DEL LOCAL',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${totalArea.toStringAsFixed(0)} m² útiles',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Slider Ancho / Frente
            _buildSliderRow(
              label: 'Frente (Ancho)',
              valueText: '${_widthMeters.toStringAsFixed(1)} m',
              value: _widthMeters,
              min: 8.0,
              max: 60.0,
              onChanged: (v) => setState(() => _widthMeters = v),
            ),

            // Slider Fondo / Largo
            _buildSliderRow(
              label: 'Fondo (Largo)',
              valueText: '${_lengthMeters.toStringAsFixed(1)} m',
              value: _lengthMeters,
              min: 10.0,
              max: 80.0,
              onChanged: (v) => setState(() => _lengthMeters = v),
            ),

            // Slider Altura
            _buildSliderRow(
              label: 'Altura de Techo',
              valueText: '${_heightMeters.toStringAsFixed(1)} m',
              value: _heightMeters,
              min: 2.5,
              max: 10.0,
              onChanged: (v) => setState(() => _heightMeters = v),
            ),

            const SizedBox(height: 16),

            // 3. Pasillos y Estanterías
            Text(
              _presetType == 'store'
                  ? 'ORGANIZACIÓN DE ESTANTERÍAS (TIENDA)'
                  : 'ORGANIZACIÓN DE PASILLOS Y ESTANTES',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            _buildCounterRow(
              label:
                  _presetType == 'store'
                      ? 'Estantes Pared Fondo (Pomos)'
                      : 'Número de Pasillos / Columnas',
              value: _aislesCount,
              min: 1,
              max: 10,
              isDark: isDark,
              onChanged: (v) => setState(() => _aislesCount = v),
            ),
            const SizedBox(height: 10),

            _buildCounterRow(
              label:
                  _presetType == 'store'
                      ? 'Estantes Pared Lateral (Sobres)'
                      : 'Estantes / Módulos por Pasillo',
              value: _shelvesPerAisle,
              min: 1,
              max: 8,
              isDark: isDark,
              onChanged: (v) => setState(() => _shelvesPerAisle = v),
            ),
            const SizedBox(height: 10),

            _buildCounterRow(
              label: 'Niveles de Altura (Bandejas)',
              value: _levelsPerShelf,
              min: 1,
              max: 6,
              isDark: isDark,
              onChanged: (v) => setState(() => _levelsPerShelf = v),
            ),

            const SizedBox(height: 24),

            // Botones de Acción
            SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark
                                ? const Color(0xFFCBD5E1)
                                : AppColors.textSecondary,
                        side: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final newConfig = _generateCurrentConfig();
                        widget.onApply(newConfig);
                      },
                      icon: const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Aplicar Cambios',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _presetType == id;

    return InkWell(
      onTap: () {
        setState(() {
          _presetType = id;
          if (id == 'store') {
            _heightMeters = 3.8;
            _levelsPerShelf = 3;
          } else if (id == 'central') {
            _heightMeters = 6.0;
            _levelsPerShelf = 4;
          } else {
            _heightMeters = 4.0;
            _levelsPerShelf = 4;
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : null,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.grey),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            Text(
              valueText,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt() * 2,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildCounterRow({
    required String label,
    required int value,
    required int min,
    required int max,
    required bool isDark,
    required ValueChanged<int> onChanged,
  }) {
    final canDecrease = value > min;
    final canIncrease = value < max;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Disminuir (-)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canDecrease ? () => onChanged(value - 1) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          canDecrease
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            canDecrease
                                ? AppColors.primary.withValues(alpha: 0.35)
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFCBD5E1)),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      size: 18,
                      color:
                          canDecrease
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 38,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
              // Botón Aumentar (+)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: canIncrease ? () => onChanged(value + 1) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          canIncrease
                              ? AppColors.primary
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow:
                          canIncrease
                              ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                              : null,
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 18,
                      color:
                          canIncrease
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
