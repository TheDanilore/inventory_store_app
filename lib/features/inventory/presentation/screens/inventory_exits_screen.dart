import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_exit_item_model.dart';
import 'package:inventory_store_app/features/inventory/data/utils/inventory_exits_pdf_generator.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_exit_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exits/inventory_exits_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exit_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/inventory_exits_table_view.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_skeleton.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryExitsScreen extends StatefulWidget {
  final String? targetExitId;

  const InventoryExitsScreen({super.key, this.targetExitId});

  @override
  State<InventoryExitsScreen> createState() => _InventoryExitsScreenState();
}

class _InventoryExitsScreenState extends State<InventoryExitsScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _searchDebounce;

  bool _hasDraft = false;
  bool _isTableView = true;
  bool _isSideSheetOpen = false;
  InventoryExitEntity? _selectedExit;
  String? _pendingTargetExitId;

  @override
  void initState() {
    super.initState();
    _pendingTargetExitId = widget.targetExitId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _screenFocusNode.requestFocus();
        final cubit = context.read<InventoryExitsCubit>();
        _searchCtrl.text = cubit.state.searchQuery;
        cubit.initLoad();
      }
    });
  }

  @override
  void didUpdateWidget(covariant InventoryExitsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetExitId != oldWidget.targetExitId) {
      if (widget.targetExitId == null) {
        if (_selectedExit != null) {
          setState(() => _selectedExit = null);
        }
        return;
      }
      if (widget.targetExitId == _selectedExit?.id) {
        return;
      }
      _pendingTargetExitId = widget.targetExitId;
      final exits = context.read<InventoryExitsCubit>().state.exits;
      final isTablet = MediaQuery.sizeOf(context).width >= 800;
      _resolveTargetExit(exits, isTablet);
    }
  }

  void _selectExit(InventoryExitEntity? exit, {bool updateUrl = true}) {
    setState(() => _selectedExit = exit);

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 800;
      if (isTablet) {
        if (exit != null) {
          context.replace('/inventory-exits?selectedId=${exit.id}');
        } else {
          context.replace('/inventory-exits');
        }
      }
    }
  }

  void _resolveTargetExit(List<InventoryExitEntity> exits, bool isTablet) {
    final targetId = _pendingTargetExitId;
    if (targetId == null) return;

    final foundIndex = exits.indexWhere((e) => e.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetExitId = null;
      _selectExit(exits[foundIndex], updateUrl: isTablet);
      if (!isTablet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedExit != null) {
            _showDetailBottomSheet(context, _selectedExit!);
          }
        });
      } else if (_isTableView) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedExit != null) {
            _openDesktopDetailSheet(_selectedExit!);
          }
        });
      }
    }
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString('inventory_exit_draft');
    if (mounted) {
      setState(() {
        _hasDraft = draftString != null && draftString.isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable, aislar atajos globales
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Atajo [/] -> Enfocar buscador
    if (key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Atajo [N] -> Nueva Salida
    if (key == LogicalKeyboardKey.keyN) {
      _onNewExit();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar salidas
    if (key == LogicalKeyboardKey.keyR) {
      context.read<InventoryExitsCubit>().loadExits(isRefresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando historial de salidas...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajo [Escape] -> Limpiar búsqueda o cerrar detalle
    if (key == LogicalKeyboardKey.escape) {
      if (_selectedExit != null) {
        setState(() => _selectedExit = null);
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        _screenFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar salidas
    final state = context.read<InventoryExitsCubit>().state;
    if (state.exits.isNotEmpty) {
      final exits = state.exits;
      final currentIndex =
          _selectedExit != null
              ? exits.indexWhere((e) => e.id == _selectedExit!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, exits.length - 1);
        _selectExit(exits[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, exits.length - 1);
        _selectExit(exits[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        final exit = _selectedExit ?? exits.first;
        final isTablet = MediaQuery.sizeOf(context).width >= 800;
        if (isTablet) {
          _openDesktopDetailSheet(exit);
        } else {
          _showDetailBottomSheet(context, exit);
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onNewExit() async {
    await context.push('/inventory-exits/form');
    _checkDraft();
  }

  Future<void> _openDesktopDetailSheet(InventoryExitEntity exit) async {
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    _selectExit(exit, updateUrl: true);

    await showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Cerrar detalle',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screenWidth = MediaQuery.sizeOf(dialogContext).width;
        final drawerWidth = screenWidth >= 1440 ? 640.0 : 580.0;

        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: drawerWidth,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.background,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 24,
                    offset: Offset(-4, 0),
                  ),
                ],
              ),
              child: InventoryExitDetailSheet(
                exitData: exit,
                isBottomSheet: false,
                loadItems: () => _loadItems(exit),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, secAnim, child) {
        final curvedAnim = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(curvedAnim),
          child: child,
        );
      },
    );
    _isSideSheetOpen = false;
  }

  Future<List<InventoryExitItemModel>> _loadItems(
    InventoryExitEntity exitData,
  ) async {
    final getItemsUseCase = sl<GetExitItemsUseCase>();
    final itemsList = await getItemsUseCase.call(exitData.id);
    return itemsList.map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variant = r['product_variants'] as Map<String, dynamic>?;
      final variantId = r['variant_id'] as String?;

      final vavList =
          variant?['variant_attribute_values'] as List<dynamic>? ?? [];
      final List<String> attrValues = [];
      for (var vav in vavList) {
        final av = vav['attribute_values'] as Map<String, dynamic>?;
        if (av != null && av['value'] != null) {
          attrValues.add(av['value'].toString());
        }
      }
      final attrsText = attrValues.join(' · ');

      final bool usesBatches = prod?['uses_batches'] == true;

      String? finalImageUrl;
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (imagesList.isNotEmpty) {
        final variantImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
          (img) => img['variant_id'] == variantId,
          orElse: () => <String, dynamic>{},
        );
        if (variantImage.isNotEmpty && variantImage['image_url'] != null) {
          finalImageUrl = variantImage['image_url'] as String;
        } else {
          final mainImage = imagesList.cast<Map<String, dynamic>>().firstWhere(
            (img) => img['is_main'] == true,
            orElse: () => imagesList.first as Map<String, dynamic>,
          );
          finalImageUrl = mainImage['image_url'] as String?;
        }
      }

      return InventoryExitItemModel(
        id: r['id'] as String? ?? '',
        exitId: exitData.id,
        productId: prod?['id'] as String? ?? '',
        variantId: variantId ?? '',
        productName: prod?['name'] as String? ?? '—',
        variantAttrs: attrsText.isNotEmpty ? attrsText : '',
        quantity: (r['quantity'] as num).toDouble(),
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        usesBatches: usesBatches,
        imageUrl: finalImageUrl,
        sku: variant?['sku'] as String?,
      );
    }).toList();
  }

  void _showDetailBottomSheet(
    BuildContext context,
    InventoryExitEntity exitData,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => InventoryExitDetailSheet(
            exitData: exitData,
            isBottomSheet: true,
            loadItems: () => _loadItems(exitData),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

    return BlocConsumer<InventoryExitsCubit, InventoryExitsState>(
      listener: (context, state) {
        if (state.errorMessage != null && !state.isLoading) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        }
        if (_pendingTargetExitId != null && state.exits.isNotEmpty) {
          _resolveTargetExit(state.exits, isDesktopOrTablet);
        }
      },
      builder: (context, state) {
        final cubit = context.read<InventoryExitsCubit>();

        final double totalCost = state.exits.fold<double>(
          0,
          (s, e) => s + e.totalCost,
        );
        final int totalUnits = state.exits.fold<int>(
          0,
          (s, e) => s + e.itemCount,
        );

        return AdminLayout(
          title: 'Salidas de Inventario',
          showBackButton: true,
          onSettingsSelected: (val) {
            if (val != 'pdf') return;
            if (state.exits.isNotEmpty) {
              final startDate = state.startDate;
              final endDate = state.endDate;
              final selectedRange =
                  (startDate != null && endDate != null)
                      ? DateTimeRange(start: startDate, end: endDate)
                      : null;
              InventoryExitsPdfGenerator.shareReport(
                exits: state.exits,
                dateRange: selectedRange,
              );
            }
          },
          actions: const [],
          floatingActionButton:
              !isDesktopOrTablet
                  ? FloatingActionButton.extended(
                    onPressed: _onNewExit,
                    icon: Icon(
                      _hasDraft
                          ? Icons.edit_note_rounded
                          : Icons.remove_circle_outline_rounded,
                    ),
                    label: Text(
                      _hasDraft ? 'Borrador' : 'Nueva Salida',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor:
                        _hasDraft ? const Color(0xFFF59E0B) : AppColors.danger,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  )
                  : null,

          bottomNavigationBar: state.exits.isEmpty || state.totalPages < 1
              ? null
              : _buildPagination(context, state, cubit, isTablet: true),

          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 800;

                // Si es tablet y la salida seleccionada ya no existe en la lista filtrada, deseleccionar
                if (isTablet && _selectedExit != null && !_isTableView) {
                  final exists = state.exits.any(
                    (e) => e.id == _selectedExit!.id,
                  );
                  if (!exists && state.exits.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() => _selectedExit = null);
                      }
                    });
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 1. Aviso de Borrador ──────────────────────────────
                    if (_hasDraft)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.edit_document,
                              color: AppColors.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Tienes un borrador de salida en progreso.',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _onNewExit,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.warning.withValues(
                                  alpha: 0.2,
                                ),
                                foregroundColor: AppColors.warning,
                              ),
                              child: const Text('Continuar'),
                            ),
                          ],
                        ),
                      ),

                    // ── 2. Bento KPI Ribbon ───────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _InventoryExitsBentoKpiBar(
                        count: state.exits.length,
                        totalCount: state.totalRecords,
                        totalCost: totalCost,
                        totalUnits: totalUnits,
                        isDesktop: isTablet,
                      ),
                    ),

                    // ── 3. Toolbar Pro Unificado (Buscador, Fecha, Vista, Refresh, CTA) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: _InventoryExitsToolbar(
                        searchCtrl: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        onSearchChanged: (v) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (mounted) {
                                cubit.updateSearch(v);
                              }
                            },
                          );
                        },
                        onClearSearch: () {
                          _searchDebounce?.cancel();
                          _searchCtrl.clear();
                          cubit.updateSearch('');
                        },
                        state: state,
                        isDesktop: isTablet,
                        isTableView: _isTableView,
                        onToggleTableView:
                            (val) => setState(() => _isTableView = val),
                        onRefresh: () {
                          cubit.loadExits(isRefresh: true);
                        },
                        hasDraft: _hasDraft,
                        onNewExit: _onNewExit,
                      ),
                    ),

                    // ── 4. Encabezado de Navegación y Contador ────────────
                    if (!state.isLoading && state.exits.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              '${state.exits.length} ${state.exits.length == 1 ? "salida" : "salidas"} en esta página',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isTablet) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: const Text(
                                  '↑ ↓ navegar',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Text(
                                'Pág. ${state.currentPage + 1} / ${state.totalPages}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── 5. Contenido Principal: Tabla Pro o Split/Cards ───
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child:
                            (state.isLoading && state.exits.isEmpty)
                                ? (_isTableView && isTablet)
                                    ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: AppTableShimmer(),
                                    )
                                    : const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: KardexSkeleton(),
                                    )
                                : state.exits.isEmpty
                                ? AppEmptyState(
                                  key: const ValueKey('empty_state'),
                                  icon: Icons.inventory_2_outlined,
                                  title: 'Sin Resultados',
                                  message:
                                      state.searchQuery.isEmpty &&
                                              state.startDate == null &&
                                              state.endDate == null
                                          ? 'No hay salidas registradas'
                                          : 'Sin resultados para los filtros aplicados',
                                )
                                : (_isTableView && isTablet)
                                ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: InventoryExitsTableView(
                                    exits: state.exits,
                                    selectedExit: _selectedExit,
                                    onSelectExit:
                                        (e) => _openDesktopDetailSheet(e),
                                    onRefresh:
                                        () => cubit.loadExits(isRefresh: true),
                                  ),
                                )
                                : isTablet
                                ? _buildTabletGridLayout(context, state, cubit)
                                : _buildMobileCardsLayout(
                                  context,
                                  state,
                                  cubit,
                                ),
                      ),
                    ),

                    // ── 6. Paginación Inferior Fija (AdminPageBlocks) ────────
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPagination(
    BuildContext context,
    InventoryExitsState state,
    InventoryExitsCubit cubit, {
    bool isTablet = false,
  }) {
    if (state.totalPages < 1 || state.exits.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      alignment: Alignment.center,
      child: SafeArea(
        top: false,
        bottom: !isTablet,
        child: AdminPageBlocks(
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: (page) => cubit.changePage(page),
        ),
      ),
    );
  }

  Widget _buildTabletGridLayout(
    BuildContext context,
    InventoryExitsState state,
    InventoryExitsCubit cubit,
  ) {
    return RefreshIndicator(
      color: AppColors.danger,
      onRefresh: () => cubit.loadExits(isRefresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 440,
          mainAxisExtent: 180,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: state.exits.length,
        itemBuilder: (context, i) {
          final exit = state.exits[i];
          return _ExitCard(
            exitData: exit,
            isSelected: _selectedExit?.id == exit.id,
            onTap: () => _openDesktopDetailSheet(exit),
          );
        },
      ),
    );
  }

  Widget _buildMobileCardsLayout(
    BuildContext context,
    InventoryExitsState state,
    InventoryExitsCubit cubit,
  ) {
    return RefreshIndicator(
      color: AppColors.danger,
      onRefresh: () => cubit.loadExits(isRefresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: state.exits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final exit = state.exits[i];
          return _ExitCard(
            exitData: exit,
            isSelected: false,
            onTap: () => _showDetailBottomSheet(context, exit),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BENTO KPI BAR
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryExitsBentoKpiBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalCost;
  final int totalUnits;
  final bool isDesktop;

  const _InventoryExitsBentoKpiBar({
    required this.count,
    required this.totalCount,
    required this.totalCost,
    required this.totalUnits,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _BentoExitKpiCard(
        title: 'Total Salidas',
        value: totalCount > 0 ? '$totalCount' : '$count',
        subtitle: 'Salidas registradas',
        icon: Icons.outbox_rounded,
        iconBgColor: AppColors.primaryLight,
        iconColor: AppColors.primary,
      ),
      _BentoExitKpiCard(
        title: 'Costo Total Salidas',
        value: 'S/ ${totalCost.toStringAsFixed(2)}',
        subtitle: 'Costo total de salidas',
        icon: Icons.payments_rounded,
        iconBgColor: const Color(0xFFFEF2F2),
        iconColor: AppColors.dangerDark,
        valueColor: AppColors.dangerDark,
      ),
      _BentoExitKpiCard(
        title: 'Unidades Despachadas',
        value: '$totalUnits uds.',
        subtitle: 'Productos descargados',
        icon: Icons.inventory_2_rounded,
        iconBgColor: AppColors.tealLight,
        iconColor: AppColors.tealDark,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
        ],
      );
    }

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(width: 220, child: cards[index]),
      ),
    );
  }
}

class _BentoExitKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color? valueColor;

  const _BentoExitKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOOLBAR PRO UNIFICADO
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryExitsToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final InventoryExitsState state;
  final bool isDesktop;
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final VoidCallback onRefresh;
  final bool hasDraft;
  final VoidCallback onNewExit;

  const _InventoryExitsToolbar({
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.state,
    required this.isDesktop,
    required this.isTableView,
    required this.onToggleTableView,
    required this.onRefresh,
    required this.hasDraft,
    required this.onNewExit,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryExitsCubit>();

    Widget datePicker = DateFilterCalendar(
      height: 40,
      borderRadius: BorderRadius.circular(10),
      dateRange:
          state.startDate != null && state.endDate != null
              ? DateTimeRange(start: state.startDate!, end: state.endDate!)
              : null,
      onDateRangeSelected: (picked) {
        cubit.updateDateRange(picked.start, picked.end);
      },
      onClear: () => cubit.updateDateRange(null, null),
    );

    Widget viewToggle = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Vista en Tabla Pro [V]',
            icon: Icon(
              Icons.table_rows_rounded,
              size: 18,
              color: isTableView ? AppColors.dangerDark : AppColors.textMuted,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  isTableView ? AppColors.surface : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              fixedSize: const Size(32, 32),
            ),
            onPressed: () => onToggleTableView(true),
          ),
          IconButton(
            tooltip: 'Vista en Tarjetas [V]',
            icon: Icon(
              Icons.grid_view_rounded,
              size: 18,
              color: !isTableView ? AppColors.dangerDark : AppColors.textMuted,
            ),
            style: IconButton.styleFrom(
              backgroundColor:
                  !isTableView ? AppColors.surface : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              fixedSize: const Size(32, 32),
            ),
            onPressed: () => onToggleTableView(false),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x050F172A),
              blurRadius: 4,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _SearchField(
                controller: searchCtrl,
                focusNode: searchFocusNode,
                hint: 'Buscar motivo o notas... [/]',
                onChanged: onSearchChanged,
                onSubmitted: onSearchChanged,
                onClear: onClearSearch,
              ),
            ),
            const SizedBox(width: 8),
            datePicker,
            const SizedBox(width: 10),
            viewToggle,
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: AppColors.textSecondary,
                tooltip: 'Refrescar salidas [R]',
                style: IconButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
                onPressed: onRefresh,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: onNewExit,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  hasDraft
                      ? Icons.edit_note_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: 18,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasDraft ? 'Continuar Borrador' : 'Nueva Salida',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Text(
                        'N',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Móvil
    return Column(
      children: [
        _SearchField(
          controller: searchCtrl,
          focusNode: searchFocusNode,
          hint: 'Buscar motivo o notas...',
          onChanged: onSearchChanged,
          onSubmitted: onSearchChanged,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: datePicker),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onRefresh,
              style: IconButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// AUXILIAR WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 19,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, val, _) {
              if (val.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        '/',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ExitCard extends StatefulWidget {
  final InventoryExitEntity exitData;
  final VoidCallback onTap;
  final bool isSelected;

  const _ExitCard({
    required this.exitData,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  State<_ExitCard> createState() => _ExitCardState();
}

class _ExitCardState extends State<_ExitCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final exitData = widget.exitData;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppColors.danger.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.danger.withValues(alpha: 0.5)
                : _isHovered
                    ? AppColors.teal.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
            width: (widget.isSelected || _isHovered) ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: widget.isSelected ? 0.08 : (_isHovered ? 0.06 : 0.025),
              ),
              blurRadius: (widget.isSelected || _isHovered) ? 14 : 8,
              offset: Offset(0, (widget.isSelected || _isHovered) ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          exitData.reason ?? 'Sin motivo especificado',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        icon: Icons.warehouse_rounded,
                        label: exitData.warehouseName ?? 'Almacén Central',
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${exitData.itemCount} ${exitData.itemCount == 1 ? "producto" : "productos"}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            exitData.createdAt != null
                                ? DateFormat(
                                  'dd MMM yyyy - HH:mm',
                                  'es',
                                ).format(exitData.createdAt!.toLocal())
                                : '—',
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'COSTO TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'S/ ${exitData.totalCost.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.dangerDark,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _Pill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: c,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
