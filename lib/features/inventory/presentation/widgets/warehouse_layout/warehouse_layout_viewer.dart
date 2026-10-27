import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/warehouse_procedural_painter.dart';

/// Visor Interactivo del Gemelo Digital con Zoom, Paneo, Selector de Modo y Hit-Testing.
class WarehouseLayoutViewer extends StatefulWidget {
  final WarehouseLayoutConfig layout;
  final WarehouseZone? selectedZone;
  final ValueChanged<WarehouseZone?>? onZoneSelected;
  final VoidCallback? onOpenEditor;
  final bool showControls;

  const WarehouseLayoutViewer({
    super.key,
    required this.layout,
    this.selectedZone,
    this.onZoneSelected,
    this.onOpenEditor,
    this.showControls = true,
  });

  @override
  State<WarehouseLayoutViewer> createState() => _WarehouseLayoutViewerState();
}

class _WarehouseLayoutViewerState extends State<WarehouseLayoutViewer> {
  final TransformationController _transformController =
      TransformationController();
  WarehouseViewMode _viewMode = WarehouseViewMode.isometric25D;
  late WarehouseZone? _selectedZone;

  @override
  void initState() {
    super.initState();
    _selectedZone = widget.selectedZone;
  }

  @override
  void didUpdateWidget(covariant WarehouseLayoutViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedZone != oldWidget.selectedZone) {
      _selectedZone = widget.selectedZone;
    }
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetTransform() {
    _transformController.value = Matrix4.identity();
  }

  void _zoomIn() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale < 3.0) {
      final matrix = _transformController.value.clone();
      matrix.scaleByDouble(1.25, 1.25, 1.0, 1.0);
      _transformController.value = matrix;
    }
  }

  void _zoomOut() {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale > 0.4) {
      final matrix = _transformController.value.clone();
      matrix.scaleByDouble(0.8, 0.8, 1.0, 1.0);
      _transformController.value = matrix;
    }
  }

  void _handleTap(TapUpDetails details, Size canvasSize) {
    // Convertir coordenadas del click considerando la matriz de transformación del InteractiveViewer
    final transform = _transformController.value;
    final inverted = Matrix4.inverted(transform);
    final localPos = MatrixUtils.transformPoint(
      inverted,
      details.localPosition,
    );

    final painter = WarehouseProceduralPainter(
      layout: widget.layout,
      viewMode: _viewMode,
      meterScale: 28.0,
    );

    final hit = painter.findZoneAt(localPos, canvasSize);
    setState(() {
      _selectedZone = hit;
    });
    widget.onZoneSelected?.call(hit);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tamaño virtual amplio para el lienzo de proyección
        final canvasW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1000.0;
        final canvasH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 700.0;
        final canvasSize = Size(canvasW, canvasH);

        return Stack(
          children: [
            // 1. LIENZO INTERACTIVO CON GESTOS Y HIT-TESTING
            GestureDetector(
              onTapUp: (details) => _handleTap(details, canvasSize),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.35,
                maxScale: 3.5,
                boundaryMargin: const EdgeInsets.all(400),
                constrained: true,
                child: CustomPaint(
                  size: canvasSize,
                  painter: WarehouseProceduralPainter(
                    layout: widget.layout,
                    viewMode: _viewMode,
                    selectedZone: _selectedZone,
                    isDarkMode: isDark,
                    meterScale: 28.0,
                  ),
                ),
              ),
            ),

            // 2. BARRA DE HERRAMIENTAS FLOTANTE SUPERIOR (Modo 2D / 2.5D y Zoom)
            if (widget.showControls)
              Positioned(
                top: 16,
                right: 16,
                child: _buildTopControlBar(isDark),
              ),

            // 3. LEYENDA TÉCNICA FLOTANTE INFERIOR IZQUIERDA
            if (widget.showControls)
              Positioned(bottom: 16, left: 16, child: _buildLegendCard(isDark)),

            // 4. TARJETA INSPECTORA DE ZONA SELECCIONADA (INFERIOR DERECHA)
            if (_selectedZone != null)
              Positioned(
                bottom: 16,
                right: 16,
                child: _buildZoneInspectorCard(_selectedZone!, isDark),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTopControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE61E293B) : const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x3394A3B8) : const Color(0x1F000000),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón selector de Modo (2D Plano vs 2.5D Isométrico)
          SegmentedButton<WarehouseViewMode>(
            segments: const [
              ButtonSegment(
                value: WarehouseViewMode.isometric25D,
                icon: Icon(Icons.view_in_ar_rounded, size: 16),
                label: Text(
                  '3D Iso',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              ButtonSegment(
                value: WarehouseViewMode.topDown2D,
                icon: Icon(Icons.grid_on_rounded, size: 16),
                label: Text(
                  '2D Plano',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            selected: {_viewMode},
            onSelectionChanged: (newSelection) {
              setState(() {
                _viewMode = newSelection.first;
              });
            },
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(height: 20, child: VerticalDivider(width: 1)),
          const SizedBox(width: 4),

          // Zoom In
          IconButton(
            icon: const Icon(Icons.zoom_in_rounded, size: 20),
            tooltip: 'Acercar',
            onPressed: _zoomIn,
            visualDensity: VisualDensity.compact,
          ),
          // Zoom Out
          IconButton(
            icon: const Icon(Icons.zoom_out_rounded, size: 20),
            tooltip: 'Alejar',
            onPressed: _zoomOut,
            visualDensity: VisualDensity.compact,
          ),
          // Centrar
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded, size: 20),
            tooltip: 'Centrar Vista',
            onPressed: _resetTransform,
            visualDensity: VisualDensity.compact,
          ),

          // Botón Diseñar / Editar Layout
          if (widget.onOpenEditor != null) ...[
            const SizedBox(width: 4),
            const SizedBox(height: 20, child: VerticalDivider(width: 1)),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: widget.onOpenEditor,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text(
                'Diseñar Layout',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLegendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xE61E293B) : const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0x3394A3B8) : const Color(0x1F000000),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.architecture_rounded,
                size: 14,
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.layout.dimensions.widthMeters.toStringAsFixed(1)}m × ${widget.layout.dimensions.lengthMeters.toStringAsFixed(1)}m (${widget.layout.dimensions.areaSquareMeters.toStringAsFixed(0)} m²)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildLegendDot(const Color(0xFF10B981), 'Cajas / POS'),
              _buildLegendDot(const Color(0xFF6366F1), 'Góndolas'),
              _buildLegendDot(const Color(0xFF3B82F6), 'Racks'),
              _buildLegendDot(const Color(0xFFF59E0B), 'Muelles / Docks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildZoneInspectorCard(WarehouseZone zone, bool isDark) {
    final color = Color(zone.colorValue ?? 0xFF3B82F6);

    return Container(
      width: 290,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF01E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getZoneIcon(zone.type), color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      zone.code ?? zone.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() => _selectedZone = null);
                  widget.onZoneSelected?.call(null);
                },
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInspectorMetric(
                'Dimensiones',
                '${zone.width.toStringAsFixed(1)}m × ${zone.length.toStringAsFixed(1)}m',
              ),
              _buildInspectorMetric(
                'Altura',
                '${zone.height.toStringAsFixed(1)}m',
              ),
              if (zone.isRack || zone.isGondola)
                _buildInspectorMetric('Niveles', '${zone.levels}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  IconData _getZoneIcon(String type) {
    switch (type) {
      case 'checkout':
        return Icons.point_of_sale_rounded;
      case 'gondola':
        return Icons.store_rounded;
      case 'industrial_rack':
        return Icons.inventory_2_rounded;
      case 'loading_dock':
        return Icons.local_shipping_rounded;
      case 'packing_station':
        return Icons.all_inbox_rounded;
      case 'backroom':
        return Icons.meeting_room_rounded;
      default:
        return Icons.layers_rounded;
    }
  }
}
