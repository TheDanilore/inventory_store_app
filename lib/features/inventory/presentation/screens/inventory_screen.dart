import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_stock_tab.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_batches_tab.dart';
import 'package:inventory_store_app/core/utils/focus_utils.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_export_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

/// Pantalla principal de Control de Inventario & Stock.
///
/// Arquitectura Camaleónica y Multi-dispositivo:
/// - **Desktop (>= 1024dp)**: Filosofía Power User / ERP Pro Tool (Linear/Stripe).
///   Barra de herramientas compacta con atajos de tecla única (Focus Shield),
///   indicador de urgencia cruzada entre stock y lotes, selector con hover y exportador rápido.
/// - **Tablet (640dp - 1024dp)**: Eficiencia híbrida, distribución balanceada y modales contenidos.
/// - **Móvil (< 640dp)**: Filosofía Apple HIG. Selector de almacén mediante modal BottomSheet táctil,
///   targets táctiles mínimos de 48x48dp, bordes curvos (16-24dp) y optimización estricta del pulgar.
class InventoryScreen extends StatefulWidget {
  final String? initialSearch;
  final bool isEmbedded;

  const InventoryScreen({
    super.key,
    this.initialSearch,
    this.isEmbedded = false,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _screenFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
      }
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 1) {
      // Lazy load de la pestaña de lotes evitando llamadas duplicadas
      final cubit = context.read<InventoryCubit>();
      final state = cubit.state;
      if (state is InventoryLoaded && state.batchItems.isEmpty) {
        cubit.initBatchesTab();
      }
    }
  }

  void _openExportModal(InventoryLoaded? loadedState) {
    InventoryExportSheet.show(
      context,
      selectedWarehouseId: loadedState?.selectedWarehouseId,
      selectedWarehouseName: loadedState?.selectedWarehouseName,
      warehouses: loadedState?.warehouses ?? [],
    );
  }

  // ── REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ────────────────────
  bool get _isInputFieldFocused => FocusUtils.isInputFieldFocused();

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo de texto editable (buscador, editor de stock),
    // aislamos los atajos de una sola tecla para permitir la escritura natural sin interferencias.
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        FocusManager.instance.primaryFocus?.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isModifier =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isAltPressed;

    // Atajo [1] o [Numpad 1] -> Conmutar a Stock General
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      if (_tabController.index != 0) {
        _tabController.animateTo(0);
        return KeyEventResult.handled;
      }
    }

    // Atajo [2] o [Numpad 2] -> Conmutar a Estado de Lotes
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      if (_tabController.index != 1) {
        _tabController.animateTo(1);
        return KeyEventResult.handled;
      }
    }

    // Atajo [R] -> Recargar todo el inventario
    if (key == LogicalKeyboardKey.keyR && !isModifier) {
      context.read<InventoryCubit>().refreshAll();
      AppSnackbar.show(
        context,
        message: 'Actualizando catálogo de inventario y lotes...',
        type: SnackbarType.info,
        duration: const Duration(seconds: 2),
      );
      return KeyEventResult.handled;
    }

    // Atajo [E] o [Ctrl+E] / [Alt+E] -> Exportar Excel
    if ((key == LogicalKeyboardKey.keyE && !isModifier) ||
        (isModifier && key == LogicalKeyboardKey.keyE)) {
      final state = context.read<InventoryCubit>().state;
      final loadedState = state is InventoryLoaded ? state : null;
      _openExportModal(loadedState);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _showWarehouseBottomSheet(
    BuildContext context,
    InventoryLoaded? state,
  ) {
    _WarehousePickerBottomSheet.show(context, state);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryCubit, InventoryState>(
      buildWhen: (previous, current) {
        if (previous.runtimeType != current.runtimeType) return true;
        if (previous is InventoryLoaded && current is InventoryLoaded) {
          final urgentPrev = previous.countVencido + previous.countCritico;
          final urgentCurr = current.countVencido + current.countCritico;
          return urgentPrev != urgentCurr ||
              previous.selectedWarehouseId != current.selectedWarehouseId ||
              previous.warehouses.length != current.warehouses.length;
        }
        return false;
      },
      builder: (context, state) {
        final loadedState = state is InventoryLoaded ? state : null;
        int urgentCount = 0;
        if (loadedState != null) {
          urgentCount = loadedState.countVencido + loadedState.countCritico;
        }

        final inventoryBody = Column(
          children: [
            // ── Barra Superior Camaleónica: Segmented Control, Almacén & Exportación ──
            _AdaptiveInventoryHeader(
              tabController: _tabController,
              loadedState: loadedState,
              urgentCount: urgentCount,
              onOpenExport: () => _openExportModal(loadedState),
              onOpenWarehousePickerMobile: () => _showWarehouseBottomSheet(context, loadedState),
            ),

            // ── Contenido de Pestañas / Vistas ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  InventoryStockTab(initialSearch: widget.initialSearch),
                  const InventoryBatchesTab(),
                ],
              ),
            ),
          ],
        );

        final focusableContent = Focus(
          focusNode: _screenFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: FocusTraversalGroup(
            child: widget.isEmbedded
                ? Material(color: AppColors.background, child: inventoryBody)
                : AdminLayout(
                    title: 'Inventario',
                    showBackButton: true,
                    body: inventoryBody,
                  ),
          ),
        );

        return focusableContent;
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── HEADER CAMALEÓNICO DE INVENTARIO ─────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _AdaptiveInventoryHeader extends StatelessWidget {
  final TabController tabController;
  final InventoryLoaded? loadedState;
  final int urgentCount;
  final VoidCallback onOpenExport;
  final VoidCallback onOpenWarehousePickerMobile;

  const _AdaptiveInventoryHeader({
    required this.tabController,
    required this.loadedState,
    required this.urgentCount,
    required this.onOpenExport,
    required this.onOpenWarehousePickerMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 640;
          final isDesktop = constraints.maxWidth >= 1024;

          final tabBarWidget = _SegmentedTabs(
            controller: tabController,
            urgentCount: urgentCount,
            isDesktop: isDesktop,
            isMobile: isMobile,
          );

          final warehouseSelector = isMobile
              ? _MobileWarehouseSelectorButton(
                  selectedName: loadedState?.selectedWarehouseName ?? 'Todos los almacenes',
                  isSelected: loadedState?.selectedWarehouseId != null &&
                      loadedState!.selectedWarehouseId!.isNotEmpty,
                  onTap: onOpenWarehousePickerMobile,
                )
              : _DesktopWarehouseDropdown(state: loadedState);

          final exportButton = _AdaptiveExportButton(
            onPressed: onOpenExport,
            isCompact: isMobile,
          );

          final refreshButton = _QuickRefreshButton(
            onPressed: () {
              context.read<InventoryCubit>().refreshAll();
              AppSnackbar.show(
                context,
                message: 'Actualizando catálogo de inventario...',
                type: SnackbarType.info,
                duration: const Duration(seconds: 2),
              );
            },
          );

          // Diseño Móvil: 2 filas ergonómicas con targets táctiles amplios
          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                tabBarWidget,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: warehouseSelector),
                    const SizedBox(width: 8),
                    exportButton,
                    const SizedBox(width: 6),
                    refreshButton,
                  ],
                ),
              ],
            );
          }

          // Diseño Tablet y Desktop: Barra lineal horizontal con salud de lotes integrada
          return Row(
            children: [
              tabBarWidget,
              if (urgentCount > 0 && !isMobile) ...[
                const SizedBox(width: 12),
                _HealthUrgentBadge(
                  urgentCount: urgentCount,
                  onTap: () {
                    if (tabController.index != 1) {
                      tabController.animateTo(1);
                    }
                  },
                ),
              ],
              const Spacer(),
              warehouseSelector,
              const SizedBox(width: 10),
              exportButton,
              const SizedBox(width: 6),
              refreshButton,
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── PESTAÑAS SEGMENTADAS (LINEAR / STRIPE STYLE) ─────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  final int urgentCount;
  final bool isDesktop;
  final bool isMobile;

  const _SegmentedTabs({
    required this.controller,
    required this.urgentCount,
    required this.isDesktop,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : (isDesktop ? 460 : 410)),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: AppColors.cardShadow(opacity: 0.05),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
        ),
        dividerColor: Colors.transparent,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabs: [
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inventory_2_rounded, size: 16),
                const SizedBox(width: 8),
                const Text('Stock General'),
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  _ShortcutKeyPill(text: '1'),
                ],
              ],
            ),
          ),
          Tab(
            height: 38,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.event_busy_rounded, size: 16),
                const SizedBox(width: 8),
                const Text('Estado de Lotes'),
                if (urgentCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$urgentCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                if (isDesktop) ...[
                  const SizedBox(width: 6),
                  _ShortcutKeyPill(text: '2'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutKeyPill extends StatelessWidget {
  final String text;

  const _ShortcutKeyPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── CHIP DE SALUD DE LOTES (PUENTE ENTRE VISTAS) ─────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _HealthUrgentBadge extends StatefulWidget {
  final int urgentCount;
  final VoidCallback onTap;

  const _HealthUrgentBadge({
    required this.urgentCount,
    required this.onTap,
  });

  @override
  State<_HealthUrgentBadge> createState() => _HealthUrgentBadgeState();
}

class _HealthUrgentBadgeState extends State<_HealthUrgentBadge> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hay ${widget.urgentCount} lotes que requieren retiro o revisión urgente',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.danger.withValues(alpha: 0.14)
                  : AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isHovered
                    ? AppColors.danger
                    : AppColors.danger.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.danger,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.urgentCount} lotes críticos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: AppColors.danger,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SELECTOR DE ALMACÉN DESKTOP / TABLET (DROPDOWN REFINADO) ──────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopWarehouseDropdown extends StatefulWidget {
  final InventoryLoaded? state;

  const _DesktopWarehouseDropdown({this.state});

  @override
  State<_DesktopWarehouseDropdown> createState() =>
      _DesktopWarehouseDropdownState();
}

class _DesktopWarehouseDropdownState extends State<_DesktopWarehouseDropdown> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final warehouses = widget.state?.warehouses ?? [];
    final selectedId = widget.state?.selectedWarehouseId;
    final isSelected = selectedId != null && selectedId.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.04)
              : (_isHovered
                  ? AppColors.surfaceDark
                  : AppColors.background),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.45)
                : (_isHovered ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border),
          ),
          boxShadow: AppColors.cardShadow(opacity: 0.02),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warehouse_rounded,
              size: 17,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              'Almacén:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedId,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 19,
                ),
                borderRadius: BorderRadius.circular(10),
                dropdownColor: AppColors.surface,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      'Todos los almacenes',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ...warehouses.map((wh) {
                    return DropdownMenuItem<String?>(
                      value: wh.id,
                      child: Text(
                        wh.name,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }),
                ],
                onChanged: (newWarehouseId) {
                  String whName = 'Todos los almacenes';
                  if (newWarehouseId != null) {
                    final found =
                        warehouses.where((w) => w.id == newWarehouseId);
                    if (found.isNotEmpty) {
                      whName = found.first.name;
                    }
                  }
                  context.read<InventoryCubit>().setWarehouseFilter(
                        newWarehouseId,
                        whName,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── SELECTOR DE ALMACÉN MÓVIL (APPLE HIG BOTÓN TÁCTIL) ────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _MobileWarehouseSelectorButton extends StatelessWidget {
  final String selectedName;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileWarehouseSelectorButton({
    required this.selectedName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 44, // Target táctil mínimo de 44-48dp
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warehouse_rounded,
              size: 18,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── MODAL BOTTOM SHEET DE SELECCIÓN DE ALMACÉN (MÓVIL APPLE HIG) ─────────────
// ─────────────────────────────────────────────────────────────────────────────

class _WarehousePickerBottomSheet extends StatelessWidget {
  final InventoryLoaded? state;

  const _WarehousePickerBottomSheet({required this.state});

  static Future<void> show(BuildContext context, InventoryLoaded? state) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _WarehousePickerBottomSheet(state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warehouses = state?.warehouses ?? [];
    final selectedId = state?.selectedWarehouseId;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header del BottomSheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warehouse_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filtrar por Almacén',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Selecciona una sede o depósito operativo',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _WarehouseOptionTile(
                    title: 'Todos los almacenes',
                    subtitle: 'Mostrar existencias consolidadas de la empresa',
                    isSelected: selectedId == null || selectedId.isEmpty,
                    onTap: () {
                      context.read<InventoryCubit>().setWarehouseFilter(
                            null,
                            'Todos los almacenes',
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                  ...warehouses.map((wh) {
                    final isSelected = selectedId == wh.id;
                    final address = (wh.address != null && wh.address!.isNotEmpty)
                        ? wh.address!
                        : 'Sede operativa registrada';
                    return _WarehouseOptionTile(
                      title: wh.name,
                      subtitle: address,
                      isSelected: isSelected,
                      onTap: () {
                        context.read<InventoryCubit>().setWarehouseFilter(
                              wh.id,
                              wh.name,
                            );
                        Navigator.of(context).pop();
                      },
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarehouseOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _WarehouseOptionTile({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Icon(
                Icons.store_rounded,
                size: 18,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── BOTÓN DE EXPORTACIÓN ADAPTATIVO ──────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _AdaptiveExportButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isCompact;

  const _AdaptiveExportButton({
    required this.onPressed,
    this.isCompact = false,
  });

  @override
  State<_AdaptiveExportButton> createState() => _AdaptiveExportButtonState();
}

class _AdaptiveExportButtonState extends State<_AdaptiveExportButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Exportar Inventario a Excel (Ctrl + E o presiona E)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 12 : 14,
            ),
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.teal.withValues(alpha: 0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered ? AppColors.teal : AppColors.border,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.table_view_rounded,
                  size: 17,
                  color: AppColors.teal,
                ),
                if (!widget.isCompact) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'Exportar Excel',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Ctrl+E',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── BOTÓN DE RECARGA RÁPIDA (FEEDBACK PRO) ───────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

class _QuickRefreshButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _QuickRefreshButton({required this.onPressed});

  @override
  State<_QuickRefreshButton> createState() => _QuickRefreshButtonState();
}

class _QuickRefreshButtonState extends State<_QuickRefreshButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Recargar existencias y lotes (presiona R)',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: widget.onPressed,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _isHovered
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : AppColors.border,
              ),
              boxShadow: AppColors.cardShadow(opacity: 0.02),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 18,
              color: _isHovered ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
