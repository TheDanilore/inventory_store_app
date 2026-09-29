import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/inventory/data/models/inventory_entry_item_model.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_entry_items_usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entries/inventory_entries_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entry_detail_sheet.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/inventory_entries_table_view.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_table_shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class InventoryEntriesScreen extends StatefulWidget {
  final String? targetEntryId;

  const InventoryEntriesScreen({super.key, this.targetEntryId});

  @override
  State<InventoryEntriesScreen> createState() => _InventoryEntriesScreenState();
}

class _InventoryEntriesScreenState extends State<InventoryEntriesScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _hasDraft = false;
  bool _isTableView = true;
  bool _isSideSheetOpen = false;
  InventoryEntryEntity? _selectedEntry; // State for Master-Detail / Table selection
  String? _pendingTargetEntryId;
  bool _isFetchingTargetEntry = false;

  @override
  void initState() {
    super.initState();
    _pendingTargetEntryId = widget.targetEntryId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InventoryEntriesCubit>().init();
    });
  }

  @override
  void didUpdateWidget(covariant InventoryEntriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetEntryId != oldWidget.targetEntryId) {
      if (widget.targetEntryId == null) {
        if (_selectedEntry != null) {
          setState(() => _selectedEntry = null);
        }
        return;
      }
      if (widget.targetEntryId == _selectedEntry?.id) {
        return;
      }
      _pendingTargetEntryId = widget.targetEntryId;
      final state = context.read<InventoryEntriesCubit>().state;
      if (state is InventoryEntriesLoaded) {
        final isTablet = MediaQuery.sizeOf(context).width >= 800;
        _resolveTargetEntry(state.entries, isTablet);
      }
    }
  }

  void _selectEntry(InventoryEntryEntity? entry, {bool updateUrl = true}) {
    setState(() => _selectedEntry = entry);

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 800;
      if (isTablet) {
        if (entry != null) {
          context.replace('/inventory-entries?selectedId=${entry.id}');
        } else {
          context.replace('/inventory-entries');
        }
      }
    }
  }

  void _resolveTargetEntry(List<InventoryEntryEntity> entries, bool isTablet) {
    final targetId = _pendingTargetEntryId;
    if (targetId == null) return;

    final foundIndex = entries.indexWhere((e) => e.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetEntryId = null;
      _selectEntry(entries[foundIndex], updateUrl: isTablet);
      if (!isTablet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedEntry != null) {
            _showDetailBottomSheet(context, _selectedEntry!);
          }
        });
      } else if (_isTableView) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedEntry != null) {
            _openDesktopDetailSheet(_selectedEntry!);
          }
        });
      }
    } else {
      _pendingTargetEntryId = null;
      _fetchAndSelectEntry(targetId, isTablet);
    }
  }

  Future<void> _fetchAndSelectEntry(String targetId, bool isTablet) async {
    if (_isFetchingTargetEntry) return;
    _isFetchingTargetEntry = true;
    try {
      final entry = await sl<InventoryEntriesRepository>().getEntryById(
        targetId,
      );
      if (!mounted) return;
      if (entry != null) {
        _selectEntry(entry, updateUrl: isTablet);
        if (!isTablet) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedEntry != null) {
              _showDetailBottomSheet(context, _selectedEntry!);
            }
          });
        } else if (_isTableView) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedEntry != null) {
              _openDesktopDetailSheet(_selectedEntry!);
            }
          });
        }
      } else {
        AppSnackbar.show(
          context,
          message: 'No se pudo encontrar la entrada de inventario asociada.',
          type: SnackbarType.error,
        );
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) {
        setState(() => _isFetchingTargetEntry = false);
      } else {
        _isFetchingTargetEntry = false;
      }
    }
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final itemsString = prefs.getString('inventory_entry_draft');
    if (mounted) {
      setState(() {
        _hasDraft =
            itemsString != null &&
            itemsString.isNotEmpty &&
            itemsString != '[]';
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

    // Atajo [N] -> Nueva Entrada
    if (key == LogicalKeyboardKey.keyN) {
      _onNewEntry();
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar entradas
    if (key == LogicalKeyboardKey.keyR) {
      context.read<InventoryEntriesCubit>().loadEntries(page: 0);
      AppSnackbar.show(
        context,
        message: 'Actualizando historial de entradas...',
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
      if (_selectedEntry != null) {
        setState(() => _selectedEntry = null);
        return KeyEventResult.handled;
      }
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar entradas en split-view
    final state = context.read<InventoryEntriesCubit>().state;
    if (state is InventoryEntriesLoaded &&
        state.entries.isNotEmpty &&
        !_isTableView) {
      final entries = state.entries;
      final currentIndex =
          _selectedEntry != null
              ? entries.indexWhere((e) => e.id == _selectedEntry!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, entries.length - 1);
        _selectEntry(entries[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, entries.length - 1);
        _selectEntry(entries[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _onNewEntry() async {
    await context.push('/inventory-entries/form');
    _checkDraft();
  }

  Future<void> _openDesktopDetailSheet(InventoryEntryEntity entry) async {
    if (!mounted || _isSideSheetOpen) return;
    _isSideSheetOpen = true;
    _selectEntry(entry, updateUrl: true);

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
              child: InventoryEntryDetailSheet(
                entry: entry,
                isBottomSheet: false,
                loadItems: () => _loadEntryItems(entry.id, null),
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

  Future<List<InventoryEntryItemModel>> _loadEntryItems(
    String entryId,
    Map<String, dynamic>? productData,
  ) async {
    final getEntryItems = sl<GetEntryItemsUseCase>();
    final itemsDynamic = await getEntryItems.call(entryId);
    return itemsDynamic.map((r) {
      final prod = r['products'] as Map<String, dynamic>?;
      final variantData = r['product_variants'] as Map<String, dynamic>?;
      final variantId = r['variant_id'] as String?;

      final vavList =
          variantData?['variant_attribute_values'] as List<dynamic>? ?? [];
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

      // 1. Buscar en las imágenes del producto la asociada a la variante
      final imagesList = prod?['product_images'] as List<dynamic>? ?? [];
      if (variantId != null && variantId.isNotEmpty && imagesList.isNotEmpty) {
        for (final img in imagesList) {
          if (img is Map<String, dynamic> &&
              img['variant_id'] == variantId &&
              (img['image_url'] as String?)?.isNotEmpty == true) {
            finalImageUrl = img['image_url'] as String;
            break;
          }
        }
      }

      // 2. Si es nulo, buscar en las imágenes anidadas en product_variants
      if (finalImageUrl == null || finalImageUrl.isEmpty) {
        final variantImagesList =
            variantData?['product_images'] as List<dynamic>? ?? [];
        for (final img in variantImagesList) {
          if (img is Map<String, dynamic> &&
              (img['image_url'] as String?)?.isNotEmpty == true) {
            finalImageUrl = img['image_url'] as String;
            if (img['is_main'] == true) break;
          }
        }
      }

      // 3. Herencia automática: si la variante no tiene imagen propia, usar la imagen principal del producto
      if (finalImageUrl == null || finalImageUrl.isEmpty) {
        if (imagesList.isNotEmpty) {
          for (final img in imagesList) {
            if (img is Map<String, dynamic> &&
                (img['image_url'] as String?)?.isNotEmpty == true) {
              finalImageUrl = img['image_url'] as String;
              if (img['is_main'] == true) break;
            }
          }
        }
      }

      return InventoryEntryItemModel(
        id: r['id'] as String? ?? '',
        entryId: entryId,
        productId: prod?['id'] as String? ?? '',
        variantId: variantId ?? '',
        productName: prod?['name'] as String? ?? '—',
        variantAttrs: attrsText.isNotEmpty ? attrsText : '',
        quantity: (r['quantity'] as num).toDouble(),
        unitCost: (r['unit_cost'] as num).toDouble(),
        batchNumber: r['batch_number'] as String? ?? 'DEFAULT',
        expiryDate:
            r['expiry_date'] != null
                ? DateTime.tryParse(r['expiry_date'] as String)
                : null,
        usesBatches: usesBatches,
        imageUrl: finalImageUrl,
      );
    }).toList();
  }

  void _onEntryTapped(
    BuildContext context,
    InventoryEntryEntity entry,
    bool isTablet,
  ) {
    if (isTablet) {
      if (_isTableView) {
        _openDesktopDetailSheet(entry);
      } else {
        _selectEntry(entry, updateUrl: true);
      }
    } else {
      _showDetailBottomSheet(context, entry);
    }
  }

  void _showDetailBottomSheet(
    BuildContext context,
    InventoryEntryEntity entry,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => InventoryEntryDetailSheet(
            entry: entry,
            isBottomSheet: true,
            loadItems: () => _loadEntryItems(entry.id, null),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

    return BlocConsumer<InventoryEntriesCubit, InventoryEntriesState>(
      listener: (context, state) {
        if (state is InventoryEntriesError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
        if (state is InventoryEntriesLoaded && _pendingTargetEntryId != null) {
          _resolveTargetEntry(state.entries, isDesktopOrTablet);
        }
      },
      builder: (context, state) {
        final loadedState = state is InventoryEntriesLoaded ? state : null;

        if (loadedState == null && state is InventoryEntriesError) {
          return Center(child: Text('Error: ${state.message}'));
        }

        final currentState =
            loadedState ??
            const InventoryEntriesLoaded(
              entries: [],
              searchQuery: '',
              warehouseFilter: 'Todos',
              availableWarehouses: ['Todos'],
              currentPage: 0,
              totalCount: 0,
              totalPages: 1,
            );

        final isLoading = state is InventoryEntriesLoading;

        // Sincronización de selección ordinaria
        if (_pendingTargetEntryId == null) {
          if (currentState.entries.isNotEmpty) {
            if (_selectedEntry != null) {
              final index = currentState.entries.indexWhere(
                (e) => e.id == _selectedEntry!.id,
              );
              if (index != -1) {
                _selectedEntry = currentState.entries[index];
              }
            } else if (isDesktopOrTablet && !_isTableView) {
              _selectedEntry = currentState.entries.first;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedEntry != null) {
                  _selectEntry(_selectedEntry, updateUrl: true);
                }
              });
            }
          } else {
            _selectedEntry = null;
          }
        }

        final displayEntries =
            (_selectedEntry != null &&
                    !currentState.entries.any(
                      (e) => e.id == _selectedEntry!.id,
                    ))
                ? [_selectedEntry!, ...currentState.entries]
                : currentState.entries;

        final double totalAmount = currentState.entries.fold<double>(
          0,
          (s, e) => s + e.totalAmount,
        );

        return AdminLayout(
          title: 'Historial de Entradas',
          showBackButton: true,
          actions: [
            if (isDesktopOrTablet)
              ElevatedButton.icon(
                onPressed: _onNewEntry,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                ),
                icon: Icon(
                  _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
                  size: 16,
                ),
                label: Text(
                  _hasDraft
                      ? 'Continuar Borrador [N]'
                      : 'Nueva Entrada [N]',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
          floatingActionButton:
              !isDesktopOrTablet
                  ? FloatingActionButton.extended(
                    onPressed: _onNewEntry,
                    icon: Icon(
                      _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
                    ),
                    label: Text(
                      _hasDraft ? 'Borrador' : 'Nueva Entrada',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor:
                        _hasDraft
                            ? const Color(0xFFF59E0B)
                            : AppColors.primary,
                    foregroundColor: Colors.white,
                  )
                  : null,
          body: Focus(
            focusNode: _screenFocusNode,
            autofocus: true,
            onKeyEvent: _handleKeyEvent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 800;

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
                                'Tienes un borrador de entrada en progreso.',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: _onNewEntry,
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
                      child: _InventoryEntriesBentoKpiBar(
                        count: currentState.entries.length,
                        totalCount: currentState.totalCount,
                        totalAmount: totalAmount,
                        isDesktop: isTablet,
                      ),
                    ),

                    // ── 3. Toolbar Pro Unificado (Buscador, Almacén, Fecha, Vista, Refresh) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: _InventoryEntriesToolbar(
                        searchCtrl: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        onSearchChanged: (v) {
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              if (mounted) {
                                context
                                    .read<InventoryEntriesCubit>()
                                    .setSearchQuery(v);
                              }
                            },
                          );
                        },
                        onClearSearch: () {
                          _searchDebounce?.cancel();
                          _searchCtrl.clear();
                          context.read<InventoryEntriesCubit>().setSearchQuery(
                            '',
                          );
                        },
                        state: currentState,
                        isDesktop: isTablet,
                        isTableView: _isTableView,
                        onToggleTableView:
                            (val) => setState(() => _isTableView = val),
                        onRefresh: () {
                          context.read<InventoryEntriesCubit>().loadEntries(
                            page: 0,
                          );
                        },
                      ),
                    ),

                    // ── 4. Encabezado de Navegación y Contador ────────────
                    if (!isLoading && currentState.entries.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              '${currentState.entries.length} ${currentState.entries.length == 1 ? "entrada" : "entradas"} en esta página',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isTablet && !_isTableView) ...[
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
                                'Pág. ${currentState.currentPage + 1} / ${currentState.totalPages}',
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
                            isLoading
                                ? (_isTableView && isTablet)
                                    ? const Padding(
                                      padding: EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        0,
                                      ),
                                      child: AppTableShimmer(),
                                    )
                                    : const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                      ),
                                      child: _EntriesSkeleton(),
                                    )
                                : currentState.entries.isEmpty
                                ? const AppEmptyState(
                                  key: ValueKey('empty'),
                                  icon: Icons.inbox_outlined,
                                  title: 'Sin Resultados',
                                  message:
                                      'Sin resultados para los filtros aplicados',
                                )
                                : (_isTableView && isTablet)
                                ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: InventoryEntriesTableView(
                                    entries: displayEntries,
                                    selectedEntry: _selectedEntry,
                                    onSelectEntry:
                                        (e) => _openDesktopDetailSheet(e),
                                    onRefresh: () {
                                      context
                                          .read<InventoryEntriesCubit>()
                                          .loadEntries(page: 0);
                                    },
                                  ),
                                )
                                : isTablet
                                ? _buildTabletSplitLayout(
                                  context,
                                  currentState,
                                  displayEntries,
                                )
                                : _buildMobileCardsLayout(
                                  context,
                                  currentState,
                                  displayEntries,
                                ),
                      ),
                    ),

                    // ── 6. Paginación Inferior ────────────────────────────
                    _buildPagination(
                      context,
                      currentState,
                      isLoading,
                      isTablet: isTablet,
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabletSplitLayout(
    BuildContext context,
    InventoryEntriesLoaded state,
    List<InventoryEntryEntity> displayEntries,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Panel izquierdo: Lista de tarjetas
        Expanded(
          flex: 4,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: displayEntries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final entry = displayEntries[i];
              return _EntryCard(
                entry: entry,
                isSelected: _selectedEntry?.id == entry.id,
                onTap: () => _onEntryTapped(context, entry, true),
              );
            },
          ),
        ),
        Container(width: 1, color: AppColors.border),
        // Panel derecho: Detalle
        Expanded(
          flex: 6,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                _selectedEntry == null
                    ? const AppEmptyState(
                      key: ValueKey('empty_detail'),
                      icon: Icons.receipt_long_rounded,
                      title: 'Ninguna Entrada Seleccionada',
                      message:
                          'Selecciona una entrada del panel izquierdo para ver sus detalles.',
                    )
                    : Container(
                      key: ValueKey(_selectedEntry!.id),
                      margin: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InventoryEntryDetailSheet(
                        entry: _selectedEntry!,
                        isBottomSheet: false,
                        loadItems:
                            () => _loadEntryItems(_selectedEntry!.id, null),
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCardsLayout(
    BuildContext context,
    InventoryEntriesLoaded state,
    List<InventoryEntryEntity> displayEntries,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: displayEntries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final entry = displayEntries[i];
        return _EntryCard(
          entry: entry,
          isSelected: false,
          onTap: () => _onEntryTapped(context, entry, false),
        );
      },
    );
  }

  Widget _buildPagination(
    BuildContext context,
    InventoryEntriesLoaded state,
    bool isLoading, {
    bool isTablet = false,
  }) {
    if (state.totalPages <= 1 || isLoading) {
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
          isCompact: isTablet,
          currentPage: state.currentPage,
          totalPages: state.totalPages,
          onPageChanged: context.read<InventoryEntriesCubit>().goToPage,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BENTO KPI BAR
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryEntriesBentoKpiBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalAmount;
  final bool isDesktop;

  const _InventoryEntriesBentoKpiBar({
    required this.count,
    required this.totalCount,
    required this.totalAmount,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.move_to_inbox_rounded,
                  size: 15,
                  color: AppColors.tealDark,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Entradas',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    '$count de $totalCount',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 1, height: 24, color: const Color(0xFFE2E8F0)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 15,
                  color: AppColors.successDark,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Inversión en Página',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  Text(
                    'S/ ${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.successDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TOOLBAR PRO UNIFICADO
// ══════════════════════════════════════════════════════════════════════════════

class _InventoryEntriesToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final InventoryEntriesLoaded state;
  final bool isDesktop;
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final VoidCallback onRefresh;

  const _InventoryEntriesToolbar({
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.state,
    required this.isDesktop,
    required this.isTableView,
    required this.onToggleTableView,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<InventoryEntriesCubit>();

    Widget warehouseDropdown = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: state.warehouseFilter,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          onChanged: (val) {
            if (val != null) cubit.setWarehouseFilter(val);
          },
          items:
              state.availableWarehouses.map((w) {
                return DropdownMenuItem<String>(
                  value: w,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(w),
                    ],
                  ),
                );
              }).toList(),
        ),
      ),
    );

    Widget datePicker = DateFilterCalendar(
      height: 40,
      borderRadius: BorderRadius.circular(10),
      dateRange: state.dateRange,
      onDateRangeSelected: cubit.setDateRange,
      onClear: () => cubit.setDateRange(null),
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
              color: isTableView ? AppColors.tealDark : AppColors.textMuted,
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
              color: !isTableView ? AppColors.tealDark : AppColors.textMuted,
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
        ),
        child: Row(
          children: [
            Expanded(
              child: _SearchField(
                controller: searchCtrl,
                focusNode: searchFocusNode,
                hint: 'Buscar proveedor, comprobante... [/]',
                onChanged: onSearchChanged,
                onSubmitted: onSearchChanged,
                onClear: onClearSearch,
              ),
            ),
            const SizedBox(width: 10),
            warehouseDropdown,
            const SizedBox(width: 8),
            datePicker,
            const SizedBox(width: 10),
            viewToggle,
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              color: AppColors.textSecondary,
              tooltip: 'Refrescar entradas [R]',
              onPressed: onRefresh,
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
          hint: 'Buscar proveedor o comprobante...',
          onChanged: onSearchChanged,
          onSubmitted: onSearchChanged,
          onClear: onClearSearch,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: warehouseDropdown),
            const SizedBox(width: 8),
            datePicker,
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ENTRY CARD
// ══════════════════════════════════════════════════════════════════════════════

class _EntryCard extends StatelessWidget {
  final InventoryEntryEntity entry;
  final VoidCallback onTap;
  final bool isSelected;

  const _EntryCard({
    required this.entry,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy HH:mm');
    final hasDoc =
        entry.documentType != 'NINGUNO' &&
        entry.documentNumber != null &&
        entry.documentNumber!.isNotEmpty;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.teal.withValues(alpha: 0.04)
                    : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.teal : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: isSelected ? 0.04 : 0.015,
                ),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (isSelected)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3.5,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(14),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.move_to_inbox_rounded,
                            color: AppColors.tealDark,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.supplierName ?? 'Sin proveedor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                entry.createdAt != null
                                    ? fmt.format(entry.createdAt!)
                                    : '—',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'S/ ${entry.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${entry.itemCount} prod. (${entry.totalQuantity.toInt()} uds.)',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (entry.warehouseName != null)
                          _Pill(
                            icon: Icons.storefront_rounded,
                            label: entry.warehouseName!,
                            color: AppColors.textSecondary,
                            bgColor: AppColors.background,
                          ),
                        _Pill(
                          icon: Icons.payments_rounded,
                          label: entry.paymentMode ?? 'Contado',
                          color: AppColors.successDark,
                          bgColor: AppColors.successLight,
                        ),
                        if (hasDoc)
                          _Pill(
                            icon: Icons.receipt_rounded,
                            label:
                                '${entry.documentType}: ${entry.documentNumber}',
                            color: AppColors.textSecondary,
                            bgColor: AppColors.background,
                          ),
                        if (entry.purchaseOrderId != null)
                          _Pill(
                            icon: Icons.link_rounded,
                            label:
                                'Orden #${entry.purchaseOrderId!.length >= 8 ? entry.purchaseOrderId!.substring(0, 8).toUpperCase() : entry.purchaseOrderId!.toUpperCase()}',
                            color: const Color(0xFF7E22CE),
                            bgColor: const Color(0xFFFAF5FF),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 40,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.isNotEmpty;
              final isDesktop = MediaQuery.sizeOf(context).width >= 800;

              if (hasText) {
                return IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  onPressed: onClear,
                  tooltip: 'Limpiar búsqueda',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                );
              }

              if (isDesktop) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.slateLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Text(
                    'Ctrl K',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EntriesSkeleton extends StatelessWidget {
  const _EntriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const AppShimmer(width: 38, height: 38, borderRadius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 140, height: 16, borderRadius: 4),
                        SizedBox(height: 8),
                        AppShimmer(width: 90, height: 12, borderRadius: 4),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      AppShimmer(width: 70, height: 18, borderRadius: 4),
                      SizedBox(height: 8),
                      AppShimmer(width: 50, height: 12, borderRadius: 4),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  AppShimmer(width: 90, height: 24, borderRadius: 6),
                  SizedBox(width: 8),
                  AppShimmer(width: 120, height: 24, borderRadius: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
