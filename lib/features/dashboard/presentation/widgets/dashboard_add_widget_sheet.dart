import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

/// Descriptor para los widgets modulares disponibles en el Dashboard
class DashboardWidgetItem {
  final String id;
  final String title;
  final String description;
  final String categoryTag;
  final Widget previewMockup;
  final bool isDefaultVisible;
  final bool isComingSoon;

  const DashboardWidgetItem({
    required this.id,
    required this.title,
    required this.description,
    required this.categoryTag,
    required this.previewMockup,
    this.isDefaultVisible = true,
    this.isComingSoon = false,
  });
}

/// Panel interactivo "Add Widget" / Personalizador estilo Shopeers
class DashboardAddWidgetSheet extends StatefulWidget {
  final Set<String> visibleWidgetIds;
  final void Function(String id, bool isVisible) onToggleWidget;
  final VoidCallback onResetDefaults;

  const DashboardAddWidgetSheet({
    super.key,
    required this.visibleWidgetIds,
    required this.onToggleWidget,
    required this.onResetDefaults,
  });

  /// Muestra el panel de widgets en Desktop (Side Sheet derecho) o Móvil (Modal BottomSheet)
  static Future<void> show(
    BuildContext context, {
    required Set<String> visibleWidgetIds,
    required void Function(String id, bool isVisible) onToggleWidget,
    required VoidCallback onResetDefaults,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    if (isDesktop) {
      return showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Add Widget',
        barrierColor: Colors.black.withValues(alpha: 0.35),
        transitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (ctx, anim1, anim2) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 440,
                height: double.infinity,
                child: DashboardAddWidgetSheet(
                  visibleWidgetIds: visibleWidgetIds,
                  onToggleWidget: onToggleWidget,
                  onResetDefaults: onResetDefaults,
                ),
              ),
            ),
          );
        },
        transitionBuilder: (ctx, anim1, anim2, child) {
          final offsetAnim = Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));
          return SlideTransition(position: offsetAnim, child: child);
        },
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          return FractionallySizedBox(
            heightFactor: 0.88,
            child: DashboardAddWidgetSheet(
              visibleWidgetIds: visibleWidgetIds,
              onToggleWidget: onToggleWidget,
              onResetDefaults: onResetDefaults,
            ),
          );
        },
      );
    }
  }

  @override
  State<DashboardAddWidgetSheet> createState() =>
      _DashboardAddWidgetSheetState();
}

class _DashboardAddWidgetSheetState extends State<DashboardAddWidgetSheet> {
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  late Set<String> _currentVisible;

  @override
  void initState() {
    super.initState();
    _currentVisible = Set<String>.from(widget.visibleWidgetIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static List<DashboardWidgetItem> get allAvailableWidgets => [
        DashboardWidgetItem(
          id: 'kpi_strip',
          title: 'Métricas Principales (KPIs)',
          description:
              'Métricas globales de ventas, ticket medio, inventario y utilidad bruta.',
          categoryTag: '#Rendimiento',
          previewMockup: _buildKpiMockup(),
        ),
        DashboardWidgetItem(
          id: 'profit_spline',
          title: 'Curva de Utilidad y Ventas',
          description:
              'Gráfico de curva continua (Spline) con trayectoria de ganancias netas.',
          categoryTag: '#Finanzas',
          previewMockup: _buildSplineMockup(),
        ),
        DashboardWidgetItem(
          id: 'best_sellers',
          title: 'Productos de Mayor Rotación',
          description:
              'Artículos con más unidades despachadas y rendimiento financiero por SKU.',
          categoryTag: '#Operaciones',
          previewMockup: _buildBestSellersMockup(),
        ),
        DashboardWidgetItem(
          id: 'customer_segments',
          title: 'Segmentación de Clientes',
          description:
              'Canales de compradores principales (Minoristas, Distribuidores y Mayoristas).',
          categoryTag: '#Estrategia',
          previewMockup: _buildCustomersMockup(),
        ),
        DashboardWidgetItem(
          id: 'weekly_activity',
          title: 'Días de Mayor Actividad',
          description:
              'Histograma semanal con picos de mayor demanda y frecuencia comercial.',
          categoryTag: '#Operaciones',
          previewMockup: _buildWeeklyActivityMockup(),
        ),
        DashboardWidgetItem(
          id: 'radial_goal',
          title: 'Meta Financiera de Ahorro',
          description:
              'Indicador radial porcentual con progreso hacia la meta mensual de la tienda.',
          categoryTag: '#Finanzas',
          previewMockup: _buildRadialGoalMockup(),
        ),
        DashboardWidgetItem(
          id: 'ai_assistant',
          title: 'Asistente IA Predictivo',
          description:
              'Predicciones automáticas, alertas de quiebre de stock y consultas inteligentes.',
          categoryTag: '#InteligenciaArtificial',
          previewMockup: _buildAiAssistantMockup(),
          isDefaultVisible: false,
          isComingSoon: true,
        ),
        DashboardWidgetItem(
          id: 'expiring_batches',
          title: 'Lotes Críticos por Vencer',
          description:
              'Control preventivo de mercancía perecible en fecha de riesgo FEFO.',
          categoryTag: '#Inventario',
          previewMockup: _buildExpiringBatchesMockup(),
        ),
      ];

  List<DashboardWidgetItem> get _filteredWidgets {
    return allAvailableWidgets.where((w) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          w.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          w.categoryTag.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'Todos' || w.categoryTag == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _handleToggle(DashboardWidgetItem item) {
    if (item.isComingSoon) return;
    if (!kIsWeb) {
      Vibration.vibrate(duration: 25, amplitude: 60);
    }
    final nextState = !_currentVisible.contains(item.id);
    setState(() {
      if (nextState) {
        _currentVisible.add(item.id);
      } else {
        _currentVisible.remove(item.id);
      }
    });
    widget.onToggleWidget(item.id, nextState);
  }

  void _handleReset() {
    if (!kIsWeb) {
      Vibration.vibrate(duration: 40, amplitude: 90);
    }
    setState(() {
      _currentVisible = allAvailableWidgets
          .where((w) => !w.isComingSoon && w.isDefaultVisible)
          .map((w) => w.id)
          .toSet();
    });
    widget.onResetDefaults();
  }

  @override
  Widget build(BuildContext context) {
    final categories = [
      'Todos',
      '#Rendimiento',
      '#Finanzas',
      '#Operaciones',
      '#Estrategia',
      '#InteligenciaArtificial',
      '#Inventario',
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 28,
            offset: Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Mobile Drag Handle (solo pantallas móviles) ─────────────
          if (MediaQuery.of(context).size.width < 720)
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 38,
                height: 4.5,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),

          // ── Header: Título, contador y botón cerrar ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Añadir Widgets',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_currentVisible.length} de ${allAvailableWidgets.length} activos en el dashboard',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar panel (Esc)',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'Buscar componentes...',
                  hintStyle: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ),

          // ── Category Filters Scroll ─────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // ── Widgets List ────────────────────────────────────────────
          Expanded(
            child: _filteredWidgets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_off_rounded,
                          size: 40,
                          color: const Color(0xFF94A3B8).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No se encontraron widgets',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
                    itemCount: _filteredWidgets.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _filteredWidgets[index];
                      final isVisible = _currentVisible.contains(item.id);

                      return _buildWidgetCatalogCard(item, isVisible);
                    },
                  ),
          ),

          // ── Footer: Restaurar predeterminados y Botón Listo ─────────
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _handleReset,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text(
                    'Restaurar por defecto',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Listo',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetCatalogCard(DashboardWidgetItem item, bool isVisible) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVisible
              ? const Color(0xFF2563EB).withValues(alpha: 0.4)
              : const Color(0xFFE2E8F0),
          width: isVisible ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isVisible
                ? const Color(0xFF2563EB).withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: Micro-mockup Vectorial
          item.previewMockup,
          const SizedBox(width: 14),

          // Center: Title, Description & Category Pill
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        item.categoryTag,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right: Action Button (+ Añadir o ✓ Activo o Próximamente)
          Align(
            alignment: Alignment.center,
            child: item.isComingSoon
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 13,
                          color: Color(0xFF64748B),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Próximamente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _handleToggle(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isVisible
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFF2563EB),
                        borderRadius: BorderRadius.circular(8),
                        border: isVisible
                            ? Border.all(color: const Color(0xFFBFDBFE))
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVisible
                                ? Icons.check_circle_rounded
                                : Icons.add_rounded,
                            size: 14,
                            color: isVisible
                                ? const Color(0xFF2563EB)
                                : Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVisible ? 'Activo' : 'Añadir',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isVisible
                                  ? const Color(0xFF2563EB)
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MICRO-MOCKUPS VECTORIALES (ESTILO SHOPEERS PREVIEW CARDS)
  // ─────────────────────────────────────────────────────────────────────────

  static Widget _buildKpiMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 14,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 10,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Container(
            width: 32,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildSplineMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: SizedBox(
          width: 44,
          height: 28,
          child: CustomPaint(
            painter: _SplineLinePainter(),
          ),
        ),
      ),
    );
  }

  static Widget _buildBestSellersMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildCustomersMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 26,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 16,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildWeeklyActivityMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 5,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 5,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 6,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 5,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildRadialGoalMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 4,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF10B981),
                ),
              ),
              const Text(
                '72%',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAiAssistantMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF60A5FA), Color(0xFF2563EB), Color(0xFF1E3A8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  static Widget _buildExpiringBatchesMockup() {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE4E6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 22,
            color: Color(0xFFE11D48),
          ),
        ),
      ),
    );
  }
}

class _SplineLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.cubicTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.1,
      size.width,
      size.height * 0.4,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
