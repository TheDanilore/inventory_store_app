import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/warehouse_layout/warehouse_procedural_painter.dart';

/// Visor Interactivo y Editor Drag & Drop del Gemelo Digital con soporte completo Desktop (Mouse) y Móvil (Touch).
class WarehouseLayoutViewer extends StatefulWidget {
  final WarehouseLayoutConfig layout;
  final WarehouseZone? selectedZone;
  final ValueChanged<WarehouseZone?>? onZoneSelected;
  final ValueChanged<WarehouseLayoutConfig>? onLayoutChanged;
  final VoidCallback? onOpenEditor;
  final bool showControls;

  const WarehouseLayoutViewer({
    super.key,
    required this.layout,
    this.selectedZone,
    this.onZoneSelected,
    this.onLayoutChanged,
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
  WarehouseZone? _selectedZone;
  WarehouseZone? _hoveredZone;

  // Estado de Arrastre Desktop (Mouse) y Móvil (Touch)
  bool _isEditDragMode = true;
  bool _isDraggingZone = false;
  WarehouseZone? _draggingZone;
  Offset? _dragStartMeterPos;
  Offset? _initialZonePos;
  Offset? _pointerDownPosition;
  bool _hasDragged = false;

  static const double _meterScale = 28.0;
  static const double _gridSnapStep = 0.5; // Ajuste magnético cada medio metro

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

  // ===========================================================================
  // CONVERSIÓN DE COORDENADAS PANTALLA <-> METROS DEL LOCAL
  // ===========================================================================
  Offset _screenToMeter(Offset localPos, Size canvasSize) {
    final dim = widget.layout.dimensions;

    if (_viewMode == WarehouseViewMode.topDown2D) {
      final totalW = dim.widthMeters * _meterScale;
      final totalL = dim.lengthMeters * _meterScale;
      final originX = (canvasSize.width - totalW) / 2;
      final originY = (canvasSize.height - totalL) / 2;
      final mx = (localPos.dx - originX) / _meterScale;
      final my = (localPos.dy - originY) / _meterScale;
      return Offset(mx, my);
    } else {
      final scale = _meterScale * 0.88;
      final origin = Offset(canvasSize.width / 2, canvasSize.height / 3.4);
      final relPos = localPos - origin;

      final u = relPos.dx / (WarehouseProceduralPainter.cos30 * scale);
      final v = relPos.dy / (WarehouseProceduralPainter.sin30 * scale);
      final mx = (u + v) / 2;
      final my = (v - u) / 2;
      return Offset(mx, my);
    }
  }

  // ===========================================================================
  // GESTIÓN DE POINTER DIRECTO (SOLUCIÓN NATIVA PARA MOUSE EN DESKTOP)
  // ===========================================================================
  void _handlePointerDown(PointerDownEvent event, Size canvasSize) {
    // Solo botón izquierdo del ratón (buttons == 1) o touch primario
    if (event.buttons != 1 && event.buttons != 0) return;

    final localPos = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformController.value),
      event.localPosition,
    );

    final painter = WarehouseProceduralPainter(
      layout: widget.layout,
      viewMode: _viewMode,
      meterScale: _meterScale,
    );

    final hit = painter.findZoneAt(localPos, canvasSize);
    _pointerDownPosition = event.localPosition;
    _hasDragged = false;

    if (hit != null && _isEditDragMode) {
      setState(() {
        _isDraggingZone = true;
        _selectedZone = hit;
        _draggingZone = hit;
        _dragStartMeterPos = _screenToMeter(localPos, canvasSize);
        _initialZonePos = Offset(hit.x, hit.y);
      });
      widget.onZoneSelected?.call(hit);
      HapticFeedback.selectionClick();
    } else {
      if (hit != _selectedZone) {
        setState(() {
          _selectedZone = hit;
        });
        widget.onZoneSelected?.call(hit);
      }
    }
  }

  void _handlePointerMove(PointerMoveEvent event, Size canvasSize) {
    if (!_isDraggingZone ||
        _draggingZone == null ||
        _dragStartMeterPos == null ||
        _initialZonePos == null) {
      return;
    }

    if (_pointerDownPosition != null &&
        (event.localPosition - _pointerDownPosition!).distance > 4) {
      _hasDragged = true;
    }

    final localPos = MatrixUtils.transformPoint(
      Matrix4.inverted(_transformController.value),
      event.localPosition,
    );

    final currentMeter = _screenToMeter(localPos, canvasSize);
    final delta = currentMeter - _dragStartMeterPos!;

    double newX = _initialZonePos!.dx + delta.dx;
    double newY = _initialZonePos!.dy + delta.dy;

    // Snapping magnético a saltos de 0.5m
    newX = (newX / _gridSnapStep).round() * _gridSnapStep;
    newY = (newY / _gridSnapStep).round() * _gridSnapStep;

    final maxW = (widget.layout.dimensions.widthMeters - _draggingZone!.width)
        .clamp(0.0, widget.layout.dimensions.widthMeters);
    final maxL = (widget.layout.dimensions.lengthMeters - _draggingZone!.length)
        .clamp(0.0, widget.layout.dimensions.lengthMeters);

    newX = newX.clamp(0.0, maxW);
    newY = newY.clamp(0.0, maxL);

    if (newX != _draggingZone!.x || newY != _draggingZone!.y) {
      final updatedZone = _draggingZone!.copyWith(x: newX, y: newY);
      _updateZoneInLayout(updatedZone);
      _draggingZone = updatedZone;
    }
  }

  void _handlePointerUp(PointerEvent event) {
    if (_isDraggingZone) {
      setState(() {
        _isDraggingZone = false;
        _draggingZone = null;
        _dragStartMeterPos = null;
        _initialZonePos = null;
        _pointerDownPosition = null;
      });
      if (_hasDragged) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _updateZoneInLayout(WarehouseZone updatedZone) {
    final zones = List<WarehouseZone>.from(widget.layout.zones);
    final idx = zones.indexWhere((z) => z.id == updatedZone.id);
    if (idx != -1) {
      zones[idx] = updatedZone;
      final newConfig = widget.layout.copyWith(zones: zones);
      setState(() {
        _selectedZone = updatedZone;
      });
      widget.onLayoutChanged?.call(newConfig);
    }
  }

  // ===========================================================================
  // ACCIONES RÁPIDAS SOBRE MÓDULOS (ROTAR, DUPLICAR, ELIMINAR, NUDGE)
  // ===========================================================================
  void _nudgeZone(WarehouseZone zone, double dx, double dy) {
    final maxW = (widget.layout.dimensions.widthMeters - zone.width).clamp(
      0.0,
      widget.layout.dimensions.widthMeters,
    );
    final maxL = (widget.layout.dimensions.lengthMeters - zone.length).clamp(
      0.0,
      widget.layout.dimensions.lengthMeters,
    );

    final newX = (zone.x + dx).clamp(0.0, maxW);
    final newY = (zone.y + dy).clamp(0.0, maxL);

    final updated = zone.copyWith(x: newX, y: newY);
    _updateZoneInLayout(updated);
    HapticFeedback.selectionClick();
  }

  void _rotateZone(WarehouseZone zone) {
    final newW = zone.length;
    final newL = zone.width;

    final maxW = (widget.layout.dimensions.widthMeters - newW).clamp(
      0.0,
      widget.layout.dimensions.widthMeters,
    );
    final maxL = (widget.layout.dimensions.lengthMeters - newL).clamp(
      0.0,
      widget.layout.dimensions.lengthMeters,
    );

    final rotated = zone.copyWith(
      width: newW,
      length: newL,
      x: zone.x.clamp(0.0, maxW),
      y: zone.y.clamp(0.0, maxL),
    );

    _updateZoneInLayout(rotated);
    HapticFeedback.mediumImpact();
  }

  void _duplicateZone(WarehouseZone zone) {
    final nextX = (zone.x + zone.width + 0.5).clamp(
      0.0,
      (widget.layout.dimensions.widthMeters - zone.width).clamp(
        0.0,
        widget.layout.dimensions.widthMeters,
      ),
    );

    final clone = zone.copyWith(
      id: 'zone_${DateTime.now().microsecondsSinceEpoch}',
      name: '${zone.name} (Copia)',
      x: nextX,
      y: zone.y,
    );

    final zones = List<WarehouseZone>.from(widget.layout.zones)..add(clone);
    final newConfig = widget.layout.copyWith(zones: zones);
    setState(() {
      _selectedZone = clone;
    });
    widget.onLayoutChanged?.call(newConfig);
    HapticFeedback.mediumImpact();
  }

  void _deleteZone(WarehouseZone zone) {
    final zones = List<WarehouseZone>.from(widget.layout.zones)
      ..removeWhere((z) => z.id == zone.id);
    final newConfig = widget.layout.copyWith(zones: zones);
    setState(() {
      _selectedZone = null;
    });
    widget.onLayoutChanged?.call(newConfig);
    widget.onZoneSelected?.call(null);
    HapticFeedback.heavyImpact();
  }

  void _showAddModuleSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Añadir Módulo a la Tienda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildAddOption(
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Mostrador de Vidrio / Vitrina',
                  subtitle:
                      'Vitrinas de atención con tapa de madera y exhibición',
                  onTap:
                      () => _createZone(
                        'glass_counter',
                        'Mostrador',
                        'MOSTRADOR',
                        4.0,
                        1.2,
                        1.1,
                        0xFFF59E0B,
                      ),
                ),
                _buildAddOption(
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF059669),
                  title: 'Estante de Insumos (Pared)',
                  subtitle:
                      'Estantería para frascos de pomo, sobres y foliares',
                  onTap:
                      () => _createZone(
                        'wall_shelf',
                        'Estante Pomos',
                        'EST-P',
                        3.0,
                        0.9,
                        2.6,
                        0xFF059669,
                        levels: 4,
                      ),
                ),
                _buildAddOption(
                  icon: Icons.grass_rounded,
                  color: const Color(0xFFB45309),
                  title: 'Palet de Fertilizantes en Suelo',
                  subtitle: 'Tarima con sacos apilados (UREA, NPK) y bidones',
                  onTap:
                      () => _createZone(
                        'floor_fertilizer',
                        'Abonos en Suelo',
                        'ABONOS',
                        3.0,
                        2.5,
                        0.65,
                        0xFFB45309,
                      ),
                ),
                _buildAddOption(
                  icon: Icons.computer_rounded,
                  color: const Color(0xFF2563EB),
                  title: 'Caja / Computadora Vendedor',
                  subtitle: 'Escritorio POS con monitor y terminal de cobro',
                  onTap:
                      () => _createZone(
                        'checkout',
                        'Caja POS',
                        'CAJA-PC',
                        2.6,
                        1.4,
                        1.0,
                        0xFF2563EB,
                      ),
                ),
                _buildAddOption(
                  icon: Icons.door_front_door_rounded,
                  color: const Color(0xFFEF4444),
                  title: 'Puerta Principal de Acceso',
                  subtitle:
                      'Acceso de clientes con puerta entreabierta y felpudo',
                  onTap:
                      () => _createZone(
                        'door',
                        'Puerta Entrada',
                        'ENTRADA',
                        2.4,
                        0.6,
                        2.4,
                        0xFFEF4444,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddOption({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  void _createZone(
    String type,
    String name,
    String codePrefix,
    double w,
    double l,
    double h,
    int colorValue, {
    int levels = 1,
  }) {
    final count = widget.layout.zones.where((z) => z.type == type).length + 1;
    final newZone = WarehouseZone(
      id: 'zone_${DateTime.now().microsecondsSinceEpoch}',
      name: '$name $count',
      type: type,
      code: '$codePrefix-$count',
      x: 2.0,
      y: 2.0,
      width: w,
      length: l,
      height: h,
      levels: levels,
      colorValue: colorValue,
    );

    final zones = List<WarehouseZone>.from(widget.layout.zones)..add(newZone);
    final newConfig = widget.layout.copyWith(zones: zones);
    setState(() {
      _selectedZone = newZone;
    });
    widget.onLayoutChanged?.call(newConfig);
    widget.onZoneSelected?.call(newZone);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasW =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1000.0;
        final canvasH =
            constraints.maxHeight.isFinite ? constraints.maxHeight : 700.0;
        final canvasSize = Size(canvasW, canvasH);

        return Stack(
          children: [
            // 1. LIENZO INTERACTIVO CON MOUSE REGION Y LISTENER
            MouseRegion(
              cursor:
                  _isDraggingZone
                      ? SystemMouseCursors.grabbing
                      : (_hoveredZone != null
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.basic),
              onHover: (event) {
                final localPos = MatrixUtils.transformPoint(
                  Matrix4.inverted(_transformController.value),
                  event.localPosition,
                );
                final painter = WarehouseProceduralPainter(
                  layout: widget.layout,
                  viewMode: _viewMode,
                  meterScale: _meterScale,
                );
                final hit = painter.findZoneAt(localPos, canvasSize);
                if (hit?.id != _hoveredZone?.id) {
                  setState(() => _hoveredZone = hit);
                }
              },
              child: Listener(
                onPointerDown: (event) => _handlePointerDown(event, canvasSize),
                onPointerMove: (event) => _handlePointerMove(event, canvasSize),
                onPointerUp: _handlePointerUp,
                onPointerCancel: _handlePointerUp,
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.35,
                  maxScale: 3.5,
                  boundaryMargin: const EdgeInsets.all(400),
                  constrained: true,
                  panEnabled: !_isDraggingZone,
                  child: CustomPaint(
                    size: canvasSize,
                    painter: WarehouseProceduralPainter(
                      layout: widget.layout,
                      viewMode: _viewMode,
                      selectedZone: _selectedZone,
                      isDarkMode: isDark,
                      meterScale: _meterScale,
                    ),
                  ),
                ),
              ),
            ),

            // 2. BARRA DE HERRAMIENTAS FLOTANTE SUPERIOR
            if (widget.showControls)
              Positioned(
                top: 16,
                right: 16,
                child: _buildTopControlBar(isDark),
              ),

            // 3. LEYENDA TÉCNICA FLOTANTE INFERIOR IZQUIERDA
            if (widget.showControls)
              Positioned(bottom: 16, left: 16, child: _buildLegendCard(isDark)),

            // 4. BOTÓN FLOTANTE: "+ AÑADIR MÓDULO" (CENTRO INFERIOR)
            if (widget.showControls)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    onPressed: _showAddModuleSheet,
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Añadir Módulo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),

            // 5. TARJETA INSPECTORA Y CINTA DE ACCIONES (INFERIOR DERECHA)
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: 6),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<WarehouseViewMode>(
              segments: [
                ButtonSegment(
                  value: WarehouseViewMode.isometric25D,
                  icon: const Icon(Icons.view_in_ar_rounded, size: 15),
                  label: Text(
                    isCompact ? '3D' : '3D Maqueta',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ButtonSegment(
                  value: WarehouseViewMode.topDown2D,
                  icon: const Icon(Icons.grid_on_rounded, size: 15),
                  label: Text(
                    isCompact ? '2D' : '2D Plano',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
                foregroundColor:
                    isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary,
                backgroundColor:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const SizedBox(height: 20, child: VerticalDivider(width: 1)),
            const SizedBox(width: 2),

            // Toggle de Modo Arrastre
            IconButton(
              icon: Icon(
                _isEditDragMode
                    ? Icons.pan_tool_rounded
                    : Icons.lock_outline_rounded,
                size: 18,
                color: _isEditDragMode ? const Color(0xFF059669) : Colors.grey,
              ),
              tooltip:
                  _isEditDragMode
                      ? 'Arrastre Activo (Toca y mueve)'
                      : 'Arrastre Bloqueado',
              onPressed: () {
                setState(() {
                  _isEditDragMode = !_isEditDragMode;
                });
                HapticFeedback.selectionClick();
              },
              visualDensity: VisualDensity.compact,
            ),

            // Zoom In
            IconButton(
              icon: const Icon(Icons.zoom_in_rounded, size: 19),
              tooltip: 'Acercar',
              color: isDark ? Colors.white : AppColors.textPrimary,
              onPressed: _zoomIn,
              visualDensity: VisualDensity.compact,
            ),
            // Zoom Out
            IconButton(
              icon: const Icon(Icons.zoom_out_rounded, size: 19),
              tooltip: 'Alejar',
              color: isDark ? Colors.white : AppColors.textPrimary,
              onPressed: _zoomOut,
              visualDensity: VisualDensity.compact,
            ),
            // Centrar
            IconButton(
              icon: const Icon(Icons.center_focus_strong_rounded, size: 19),
              tooltip: 'Centrar Vista',
              color: isDark ? Colors.white : AppColors.textPrimary,
              onPressed: _resetTransform,
              visualDensity: VisualDensity.compact,
            ),

            // Botón Generador Procedural
            if (widget.onOpenEditor != null) ...[
              const SizedBox(width: 2),
              const SizedBox(height: 20, child: VerticalDivider(width: 1)),
              const SizedBox(width: 6),
              FilledButton.icon(
                onPressed: widget.onOpenEditor,
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 15,
                  color: Colors.white,
                ),
                label: Text(
                  isCompact ? 'Generador' : 'Generador Layout',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
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
              _buildLegendDot(const Color(0xFF059669), 'Pomos / Sobres'),
              _buildLegendDot(const Color(0xFFF59E0B), 'Mostrador Vidrio'),
              _buildLegendDot(const Color(0xFFB45309), 'Abonos Suelo'),
              _buildLegendDot(const Color(0xFF2563EB), 'Caja / PC'),
              _buildLegendDot(const Color(0xFFEF4444), 'Acceso'),
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
      width: 320,
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
                      '${zone.code ?? zone.type.toUpperCase()} • (${zone.x.toStringAsFixed(1)}m, ${zone.y.toStringAsFixed(1)}m)',
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
          const Divider(height: 12),

          // Pad direccional de movimiento fino (+-0.5m)
          Row(
            children: [
              const Text(
                'Mover:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                tooltip: 'Mover Izquierda (-0.5m)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _nudgeZone(zone, -0.5, 0),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                tooltip: 'Mover Arriba (-0.5m)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _nudgeZone(zone, 0, -0.5),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                tooltip: 'Mover Abajo (+0.5m)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _nudgeZone(zone, 0, 0.5),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                tooltip: 'Mover Derecha (+0.5m)',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _nudgeZone(zone, 0.5, 0),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Botones de acción rápida: Rotar 90°, Duplicar, Eliminar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rotateZone(zone),
                  icon: const Icon(Icons.rotate_right_rounded, size: 15),
                  label: const Text(
                    'Girar 90°',
                    style: TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _duplicateZone(zone),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                child: const Icon(Icons.content_copy_rounded, size: 15),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () => _deleteZone(zone),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                child: const Icon(Icons.delete_outline_rounded, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),

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
      case 'glass_counter':
      case 'counter':
        return Icons.storefront_rounded;
      case 'wall_shelf':
        return Icons.shelves;
      case 'floor_fertilizer':
      case 'pallet_area':
        return Icons.grass_rounded;
      case 'door':
        return Icons.door_front_door_rounded;
      case 'gondola':
        return Icons.store_rounded;
      case 'industrial_rack':
        return Icons.inventory_2_rounded;
      default:
        return Icons.layers_rounded;
    }
  }
}
