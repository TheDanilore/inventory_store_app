import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_purchase_order_by_id_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_detail_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_orders_table_view.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  final String? targetOrderId;

  const PurchaseOrdersScreen({super.key, this.targetOrderId});

  static const _statusLabels = {
    'Todos': 'Todos',
    'PENDING': 'Pendiente',
    'SENT': 'Enviado',
    'PARTIAL': 'Parcial',
    'RECEIVED': 'Recibido',
    'CANCELLED': 'Cancelado',
  };

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  PurchaseOrdersCubit get cubit => context.read<PurchaseOrdersCubit>();
  _PurchaseOrdersViewModel get viewModel =>
      _PurchaseOrdersViewModel(cubit, cubit.state);
  final _searchCtrl = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _screenFocusNode = FocusNode();
  bool _hasDraft = false;
  bool _isTableView = true;
  Timer? _debounce;
  PurchaseOrderModel? _selectedOrder;
  String? _pendingTargetOrderId;
  bool _isFetchingTargetOrder = false;
  final Map<String, List<PurchaseOrderItemEntity>> _itemsCache = {};
  static const int _maxCachedOrderItems = 20;

  // --- REGLA ESTRICTA DE AISLAMIENTO DE FOCO (FOCUS SHIELD) ---
  bool get _isInputFieldFocused {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    return primaryFocus.context?.widget is EditableText;
  }

  @override
  void initState() {
    super.initState();
    _pendingTargetOrderId = widget.targetOrderId;
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = cubit.state;
      if (state is! PurchaseOrdersLoaded || state.orders.isEmpty) {
        cubit.loadOrders(refresh: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant PurchaseOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.targetOrderId != oldWidget.targetOrderId) {
      if (widget.targetOrderId == null) {
        if (_selectedOrder != null) {
          setState(() => _selectedOrder = null);
        }
        return;
      }
      if (widget.targetOrderId == _selectedOrder?.id) {
        return;
      }
      _pendingTargetOrderId = widget.targetOrderId;
      final state = cubit.state;
      if (state is PurchaseOrdersLoaded) {
        final isTablet = MediaQuery.sizeOf(context).width >= 800;
        _resolveTargetOrder(state.orders.cast<PurchaseOrderModel>(), isTablet);
      }
    }
  }

  void _selectOrder(PurchaseOrderModel? po, {bool updateUrl = true}) {
    setState(() {
      _selectedOrder = po;
    });

    if (updateUrl && mounted) {
      final isTablet = MediaQuery.sizeOf(context).width >= 800;
      if (isTablet) {
        if (po != null) {
          context.replace('/purchase-orders?selectedId=${po.id}');
        } else {
          context.replace('/purchase-orders');
        }
      }
    }
  }

  Future<List<PurchaseOrderItemEntity>> _loadOrderItems(String orderId) async {
    if (_itemsCache.containsKey(orderId)) {
      return _itemsCache[orderId]!;
    }
    final res = await sl<FetchPurchaseOrderItemsUseCase>().call(orderId);
    final items = res.fold((l) => <PurchaseOrderItemEntity>[], (r) => r);
    if (items.isNotEmpty) {
      if (_itemsCache.length >= _maxCachedOrderItems) {
        _itemsCache.remove(_itemsCache.keys.first);
      }
      _itemsCache[orderId] = items;
    }
    return items;
  }

  Future<void> _checkDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('po_form_draft_v1');
      if (str != null) {
        final data = jsonDecode(str) as Map<String, dynamic>;
        final items = data['items'] as List?;
        if (mounted) {
          setState(() {
            _hasDraft = items != null && items.isNotEmpty;
          });
        }
      } else {
        if (mounted) setState(() => _hasDraft = false);
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al verificar borrador de orden de compra',
        tag: 'PURCHASE_ORDERS_SCREEN',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _hasDraft = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Si el usuario escribe en un campo editable (buscador, formulario), aislar atajos
    if (_isInputFieldFocused) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final isControlOrMeta = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final key = event.logicalKey;

    // Atajo Ctrl+K o Cmd+K (o '/' en desktop) para enfocar buscador instantáneamente
    if ((isControlOrMeta && key == LogicalKeyboardKey.keyK) ||
        key == LogicalKeyboardKey.slash) {
      _searchFocusNode.requestFocus();
      _searchCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchCtrl.text.length,
      );
      return KeyEventResult.handled;
    }

    // Escape para desenfocar buscador, deseleccionar orden o limpiar búsqueda
    if (key == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      if (_selectedOrder != null) {
        _selectOrder(null, updateUrl: true);
        return KeyEventResult.handled;
      }
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        viewModel.setSearchText('');
        return KeyEventResult.handled;
      }
    }

    // Atajo [N] -> Nueva orden de compra o continuar borrador
    if (key == LogicalKeyboardKey.keyN) {
      context.go('/purchase-orders/form');
      return KeyEventResult.handled;
    }

    // Atajo [R] -> Recargar órdenes de compra
    if (key == LogicalKeyboardKey.keyR) {
      _itemsCache.clear();
      cubit.loadOrders(refresh: true);
      AppSnackbar.show(
        context,
        message: 'Actualizando órdenes de compra...',
        type: SnackbarType.info,
      );
      return KeyEventResult.handled;
    }

    // Atajo [V] -> Alternar Vista (Tabla Pro vs Tarjetas)
    if (key == LogicalKeyboardKey.keyV) {
      setState(() => _isTableView = !_isTableView);
      return KeyEventResult.handled;
    }

    // Atajos [1..6] -> Filtros de estado rápidos
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) {
      viewModel.setStatusFilter('Todos');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) {
      viewModel.setStatusFilter('PENDING');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) {
      viewModel.setStatusFilter('SENT');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) {
      viewModel.setStatusFilter('PARTIAL');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) {
      viewModel.setStatusFilter('RECEIVED');
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) {
      viewModel.setStatusFilter('CANCELLED');
      return KeyEventResult.handled;
    }

    // Flechas arriba y abajo para navegar órdenes en split-view
    final filtered = viewModel.orders.cast<PurchaseOrderModel>();
    final displayOrders =
        (_selectedOrder != null &&
                !filtered.any((o) => o.id == _selectedOrder!.id))
            ? [_selectedOrder!, ...filtered]
            : filtered;

    if (displayOrders.isNotEmpty) {
      final currentIndex =
          _selectedOrder != null
              ? displayOrders.indexWhere((o) => o.id == _selectedOrder!.id)
              : -1;

      if (key == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, displayOrders.length - 1);
        _selectOrder(displayOrders[nextIndex], updateUrl: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, displayOrders.length - 1);
        _selectOrder(displayOrders[prevIndex], updateUrl: true);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status.toUpperCase()) {
      case 'RECEIVED':
        bg = AppColors.successLight;
        text = AppColors.successDark;
        label = 'Recibido';
        icon = Icons.task_alt_rounded;
        break;
      case 'SENT':
        bg = const Color(0xFFEFF6FF);
        text = const Color(0xFF1D4ED8);
        label = 'Enviado';
        icon = Icons.local_shipping_rounded;
        break;
      case 'PARTIAL':
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFB45309);
        label = 'Parcial';
        icon = Icons.pie_chart_outline_rounded;
        break;
      case 'PENDING':
        bg = AppColors.warningLight;
        text = AppColors.warningDark;
        label = 'Pendiente';
        icon = Icons.schedule_rounded;
        break;
      case 'CANCELLED':
        bg = AppColors.dangerLight;
        text = AppColors.danger;
        label = 'Cancelado';
        icon = Icons.cancel_rounded;
        break;
      default:
        bg = Colors.grey.shade100;
        text = AppColors.textSecondary;
        label = status;
        icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, PurchaseOrderModel po) async {
    final cubit = context.read<PurchaseOrdersCubit>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BlocProvider.value(
            value: cubit,
            child: PODetailSheet(
              po: po,
              onPaymentSuccess: () {
                _itemsCache.remove(po.id);
                if (context.mounted) {
                  context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
                }
              },
              loadItems: () => _loadOrderItems(po.id),
              onReceive: () => _handleReceiveOrder(context, po),
              onUpdateStatus: (status) async {
                await viewModel.updateOrderStatus(po.id, status);
              },
            ),
          ),
    );
  }

  void _resolveTargetOrder(List<PurchaseOrderModel> orders, bool isTablet) {
    final targetId = _pendingTargetOrderId;
    if (targetId == null) return;

    final foundIndex = orders.indexWhere((o) => o.id == targetId);
    if (foundIndex != -1) {
      _pendingTargetOrderId = null;
      _selectOrder(orders[foundIndex], updateUrl: isTablet);
      if (!isTablet) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedOrder != null) {
            _showDetail(context, _selectedOrder!);
          }
        });
      }
    } else {
      _pendingTargetOrderId = null;
      _fetchAndSelectOrder(targetId, isTablet);
    }
  }

  Future<void> _fetchAndSelectOrder(String targetId, bool isTablet) async {
    if (_isFetchingTargetOrder) return;
    _isFetchingTargetOrder = true;
    try {
      final res = await sl<GetPurchaseOrderByIdUseCase>().call(targetId);
      if (!mounted) return;
      res.fold(
        (failure) {
          AppSnackbar.show(
            context,
            message: 'No se pudo encontrar la orden de compra asociada.',
            type: SnackbarType.error,
          );
        },
        (map) {
          if (map != null && mounted) {
            final loadedPo = PurchaseOrderModel.fromMap(map);
            _selectOrder(loadedPo, updateUrl: isTablet);
            if (!isTablet) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedOrder != null) {
                  _showDetail(context, _selectedOrder!);
                }
              });
            }
          }
        },
      );
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener orden de compra objetivo: $targetId',
        tag: 'PURCHASE_ORDERS_SCREEN',
        error: e,
        stackTrace: st,
      );
    } finally {
      if (mounted) {
        setState(() => _isFetchingTargetOrder = false);
      } else {
        _isFetchingTargetOrder = false;
      }
    }
  }

  Future<void> _handleReceiveOrder(
    BuildContext context,
    PurchaseOrderModel po,
  ) async {
    final items = await _loadOrderItems(po.id);
    if (!context.mounted) return;

    final entryItems =
        items.map((i) {
          final remaining = i.quantityOrdered - i.quantityReceived;
          final qty = remaining > 0 ? remaining : i.quantityOrdered;
          return InventoryEntryItemEntity(
            productId: i.productId,
            productName: i.productName ?? '—',
            variantId: i.variantId,
            variantLabel: i.variantAttrs.isNotEmpty ? i.variantAttrs : 'Única',
            imageUrl: i.imageUrl,
            usesBatches: i.usesBatches,
            quantity: qty,
            unitCost: i.unitCost,
            batchNumber: i.batchNumber.isNotEmpty ? i.batchNumber : 'DEFAULT',
            expiryDate: i.expiryDate,
          );
        }).toList();

    if (!context.mounted) return;

    final received = await context.push<bool>(
      '/inventory-entries/form?purchaseOrderId=${po.id}',
      extra: {
        'purchaseOrderId': po.id,
        'prefillSupplierId': po.supplierId,
        'prefillSupplierName': po.supplierName,
        'prefillWarehouseId': po.warehouseId,
        'prefillItems': entryItems,
        'prefillDocumentType': po.documentType,
        'prefillDocumentNumber': po.documentNumber,
        'prefillDocumentDate': po.createdAt,
      },
    );

    if (!context.mounted) return;

    if (received == true) {
      _itemsCache.remove(po.id);
      // Si la recepción se guardó con éxito:
      // En móvil, si había un bottom sheet abierto, lo cerramos para ver la lista con el nuevo estado
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route is! PopupRoute);

      await context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
    }
  }

  Widget _buildPagination(
    _PurchaseOrdersViewModel viewModel, {
    bool isTablet = false,
  }) {
    if (viewModel.totalPages <= 1 || viewModel.isLoading) {
      return const SizedBox.shrink();
    }
    return Container(
      height: 58,
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
          currentPage: viewModel.currentPage,
          totalPages: viewModel.totalPages,
          onPageChanged: (p) => viewModel.setPage(p),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = MediaQuery.sizeOf(context).width >= 800;

    return AdminLayout(
      title: 'Órdenes de Compra',
      showBackButton: true,
      actions: isDesktopOrTablet
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Actualizar órdenes',
                onPressed: () {
                  _itemsCache.clear();
                  context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
                },
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: () {
                    context.push('/purchase-orders/form');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Nueva',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
      floatingActionButton: null,
      body: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            return BlocConsumer<PurchaseOrdersCubit, PurchaseOrdersState>(
              listener: (context, state) {
                if (state is PurchaseOrdersLoaded &&
                    _pendingTargetOrderId != null) {
                  _resolveTargetOrder(
                    state.orders.cast<PurchaseOrderModel>(),
                    isTablet,
                  );
                }
              },
              builder: (context, state) {
                final viewModel = _PurchaseOrdersViewModel(
                  context.read<PurchaseOrdersCubit>(),
                  state,
                );
                if (viewModel.errorMessage.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AppSnackbar.show(
                      context,
                      message: viewModel.errorMessage,
                      type: SnackbarType.error,
                    );
                    viewModel.clearError();
                  });
                }

                final filtered = viewModel.orders.cast<PurchaseOrderModel>();
                final totalAmount = viewModel.totalAmountFiltered;
                final pendingCount = viewModel.pendingCountFiltered;

                // Sincronizar selección ordinaria SOLO si no hay una orden objetivo pendiente de resolver
                if (_pendingTargetOrderId == null) {
                  if (filtered.isNotEmpty) {
                    if (_selectedOrder != null) {
                      final index = filtered.indexWhere(
                        (o) => o.id == _selectedOrder!.id,
                      );
                      if (index != -1) {
                        _selectedOrder = filtered[index];
                      }
                      // Si no está en filtered (es foránea o filtrada), SE PRESERVA intacta en _selectedOrder!
                    }
                  } else {
                    _selectedOrder = null;
                  }
                }

                // Si hay una orden foránea seleccionada (ej. Deep Link desde otra página),
                // se fija arriba para que siempre aparezca visible y seleccionada en el panel izquierdo
                final displayOrders =
                    (_selectedOrder != null &&
                            !filtered.any((o) => o.id == _selectedOrder!.id))
                        ? [_selectedOrder!, ...filtered]
                        : filtered;

                final listContent = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Borrador ──────────────────────────────────────────────
                    if (_hasDraft)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
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
                                'Tienes un borrador de compra en progreso.',
                                style: TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            FilledButton.tonal(
                              onPressed: () {
                                context.go('/purchase-orders/form');
                              },
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

                    // ── 1. BENTO KPI BAR PARA COMPRAS ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _PurchaseOrdersBentoKpiBar(
                        orderCount: viewModel.orders.length,
                        totalAmount: totalAmount,
                        pendingCount: pendingCount,
                        isDesktop: isTablet,
                      ),
                    ),

                    // ── 2. TOOLBAR PRO UNIFICADO (Buscador, Filtros, Vista, Refresh, Nueva Orden) ─
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                      child: _PurchaseOrdersToolbar(
                        searchCtrl: _searchCtrl,
                        searchFocusNode: _searchFocusNode,
                        onSearchChanged: (v) {
                          _debounce?.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () => viewModel.setSearchText(v),
                          );
                        },
                        viewModel: viewModel,
                        cubit: cubit,
                        isDesktop: isTablet,
                        isTableView: _isTableView,
                        hasDraft: _hasDraft,
                        onToggleTableView: (val) => setState(() => _isTableView = val),
                        onRefresh: () {
                          _itemsCache.clear();
                          cubit.loadOrders(refresh: true);
                        },
                        onNewOrder: () => context.go('/purchase-orders/form'),
                      ),
                    ),

                    // ── Encabezado de Navegación y Contador (Estilo Pedidos) ────
                    if (!viewModel.isLoading && filtered.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Text(
                              '${filtered.length} ${filtered.length == 1 ? "orden" : "órdenes"} en esta página',
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
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
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
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                'Pág. ${viewModel.currentPage + 1} / ${viewModel.totalPages}',
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

                    // ── Lista / Tabla de Órdenes ──────────────────────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: viewModel.isLoading
                            ? ListView.separated(
                                key: const ValueKey('loading'),
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                                itemCount: 5,
                                separatorBuilder: (_, _) => const SizedBox(height: 10),
                                itemBuilder: (_, _) => const AppShimmer(
                                  width: double.infinity,
                                  height: 90,
                                  borderRadius: 16,
                                ),
                              )
                            : filtered.isEmpty
                                ? const AppEmptyState(
                                    key: ValueKey('empty'),
                                    icon: Icons.shopping_cart_outlined,
                                    title: 'Sin Resultados',
                                    message: 'Sin resultados para los filtros aplicados',
                                  )
                                : (_isTableView && isTablet)
                                    ? PurchaseOrdersTableView(
                                        key: ValueKey(
                                          'table_${viewModel.statusFilter}_${viewModel.currentPage}',
                                        ),
                                        orders: displayOrders,
                                        selectedOrder: _selectedOrder,
                                        onSelectOrder: (po) => _selectOrder(po, updateUrl: true),
                                        onRefresh: () {
                                          _itemsCache.clear();
                                          cubit.loadOrders(refresh: true);
                                        },
                                      )
                                    : RefreshIndicator(
                                        key: ValueKey(
                                          '${viewModel.statusFilter}_${viewModel.currentPage}',
                                        ),
                                        color: AppColors.primary,
                                        onRefresh: () {
                                          _itemsCache.clear();
                                          return cubit.loadOrders(refresh: true);
                                        },
                                        child: ListView.separated(
                                          physics: const AlwaysScrollableScrollPhysics(),
                                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                          itemCount: displayOrders.length,
                                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                                          itemBuilder: (context, index) {
                                            final po = displayOrders[index];
                                            final isSel = isTablet && _selectedOrder?.id == po.id;
                                            return POCard(
                                              po: po,
                                              isSelected: isSel,
                                              onTap: () {
                                                if (isTablet) {
                                                  _selectOrder(po, updateUrl: true);
                                                } else {
                                                  _showDetail(context, po);
                                                }
                                              },
                                            );
                                          },
                                        ),
                                      ),
                      ),
                    ),

                    // ── Paginación ────────────────────────────────────────────
                    _buildPagination(viewModel, isTablet: isTablet),
                  ],
                );

                // ── ESTRUCTURA ADAPTATIVA DESKTOP: TABLA 100% + SLIDE-OVER DRAWER CON BACKDROP ──
                if (isTablet) {
                  final activeOrder = _selectedOrder;
                  final drawerWidth = constraints.maxWidth >= 1440 ? 640.0 : 580.0;

                  return Stack(
                    children: [
                      // 1. Contenido principal 100% full-width
                      Positioned.fill(
                        child: Container(
                          color: AppColors.background,
                          child: listContent,
                        ),
                      ),

                      // 2. Slide-Over Side Sheet Inspector con Backdrop (como pos_sales_view.dart)
                      if (activeOrder != null) ...[
                        // Backdrop con dismiss al hacer clic fuera
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => _selectOrder(null, updateUrl: true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              color: Colors.black.withValues(alpha: 0.28),
                            ),
                          ),
                        ),

                        // Panel lateral deslizante
                        Align(
                          alignment: Alignment.centerRight,
                          child: RepaintBoundary(
                            child: Container(
                              width: drawerWidth,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 28,
                                    spreadRadius: 4,
                                    offset: const Offset(-8, 0),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Cabecera unificada del Slide-Over Drawer
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 12,
                                    ),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Color(0xFFE2E8F0),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // ID con copia rápida en 1-click
                                        InkWell(
                                          onTap: () {
                                            Clipboard.setData(
                                              ClipboardData(text: activeOrder.id),
                                            );
                                            AppSnackbar.show(
                                              context,
                                              message: 'ID copiado al portapapeles',
                                              type: SnackbarType.success,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.receipt_rounded,
                                                  size: 13,
                                                  color: AppColors.teal,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  '#${activeOrder.id.length >= 8 ? activeOrder.id.substring(0, 8).toUpperCase() : activeOrder.id.toUpperCase()}',
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.copy_rounded,
                                                  size: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(activeOrder.status),
                                        const Spacer(),
                                        // Badge atajo [ESC]
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: const Text(
                                            'ESC',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 20,
                                          ),
                                          tooltip: 'Cerrar detalle (Esc)',
                                          onPressed: () => _selectOrder(null, updateUrl: true),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Contenido del detalle con PODetailSheet
                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(milliseconds: 250),
                                      child: PODetailSheet(
                                        key: ValueKey(activeOrder.id),
                                        po: activeOrder,
                                        isDialog: true,
                                        onPaymentSuccess: () {
                                          _itemsCache.remove(activeOrder.id);
                                          if (context.mounted) {
                                            context
                                                .read<PurchaseOrdersCubit>()
                                                .loadOrders(refresh: true);
                                          }
                                        },
                                        loadItems: () => _loadOrderItems(activeOrder.id),
                                        onReceive: () => _handleReceiveOrder(context, activeOrder),
                                        onUpdateStatus: (status) async {
                                          await viewModel.updateOrderStatus(activeOrder.id, status);
                                          if (mounted && _selectedOrder != null) {
                                            setState(() {
                                              _selectedOrder = _selectedOrder!.copyWith(status: status);
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                }

                return listContent;
              },
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bento KPI Bar para Órdenes de Compra (Estilo Stripe / Linear)
// ─────────────────────────────────────────────────────────────────────────────

class _PurchaseOrdersBentoKpiBar extends StatelessWidget {
  final int orderCount;
  final double totalAmount;
  final int pendingCount;
  final bool isDesktop;

  const _PurchaseOrdersBentoKpiBar({
    required this.orderCount,
    required this.totalAmount,
    required this.pendingCount,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [
      _BentoPOKpiCard(
        title: 'Total Órdenes',
        value: '$orderCount',
        subtitle: 'Registradas en el sistema',
        icon: Icons.receipt_long_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primary.withValues(alpha: 0.1),
      ),
      _BentoPOKpiCard(
        title: 'Monto Compras',
        value: 'S/ ${totalAmount.toStringAsFixed(2)}',
        subtitle: 'Volumen total compras',
        icon: Icons.payments_rounded,
        iconColor: AppColors.teal,
        iconBgColor: AppColors.teal.withValues(alpha: 0.1),
      ),
      _BentoPOKpiCard(
        title: 'Por Recibir / Pendientes',
        value: '$pendingCount',
        subtitle: pendingCount > 0 ? 'Requieren atención' : 'Todo al día',
        icon: Icons.pending_actions_rounded,
        iconColor: pendingCount > 0 ? AppColors.warning : AppColors.success,
        iconBgColor: (pendingCount > 0 ? AppColors.warning : AppColors.success)
            .withValues(alpha: 0.1),
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          SizedBox(width: 210, child: cards[0]),
          const SizedBox(width: 10),
          SizedBox(width: 210, child: cards[1]),
          const SizedBox(width: 10),
          SizedBox(width: 210, child: cards[2]),
        ],
      ),
    );
  }
}

class _BentoPOKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const _BentoPOKpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
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

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar Unificado de Compras (Buscador, Dropdown Estado, Calendario, Vista, Refresh, CTA)
// ─────────────────────────────────────────────────────────────────────────────

class _PurchaseOrdersToolbar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final _PurchaseOrdersViewModel viewModel;
  final PurchaseOrdersCubit cubit;
  final bool isDesktop;
  final bool isTableView;
  final bool hasDraft;
  final ValueChanged<bool> onToggleTableView;
  final VoidCallback onRefresh;
  final VoidCallback onNewOrder;

  const _PurchaseOrdersToolbar({
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.viewModel,
    required this.cubit,
    required this.isDesktop,
    required this.isTableView,
    required this.hasDraft,
    required this.onToggleTableView,
    required this.onRefresh,
    required this.onNewOrder,
  });

  String _getStatusLabel(String status) {
    return PurchaseOrdersScreen._statusLabels[status] ?? status;
  }

  Widget _buildKeyHint(String key) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        key,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textMuted,
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: searchCtrl,
        focusNode: searchFocusNode,
        onChanged: onSearchChanged,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Buscar por proveedor, documento o ID...',
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.teal,
            size: 19,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: searchCtrl,
            builder: (context, value, _) {
              if (value.text.isNotEmpty) {
                return IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    color: AppColors.textMuted,
                    size: 16,
                  ),
                  onPressed: () {
                    searchCtrl.clear();
                    viewModel.setSearchText('');
                  },
                );
              }
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildKeyHint('/'),
                  ],
                ),
              );
            },
          ),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
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
            borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown(BuildContext context) {
    final isFiltered = viewModel.statusFilter != 'Todos';

    return PopupMenuButton<String>(
      initialValue: viewModel.statusFilter,
      offset: const Offset(0, 44),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      onSelected: (val) => viewModel.setStatusFilter(val),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'Todos',
          child: Row(
            children: [
              Icon(Icons.list_alt_rounded, size: 16, color: AppColors.textSecondary),
              SizedBox(width: 8),
              Text('Todos los estados', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'PENDING',
          child: Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Pendientes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warningDark)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'SENT',
          child: Row(
            children: [
              Icon(Icons.send_rounded, size: 16, color: Color(0xFF3B82F6)),
              SizedBox(width: 8),
              Text('Enviados', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'PARTIAL',
          child: Row(
            children: [
              Icon(Icons.pie_chart_rounded, size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text('Parciales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'RECEIVED',
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 16, color: AppColors.teal),
              SizedBox(width: 8),
              Text('Recibidos', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tealDark)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'CANCELLED',
          child: Row(
            children: [
              Icon(Icons.cancel_rounded, size: 16, color: AppColors.error),
              SizedBox(width: 8),
              Text('Cancelados', style: TextStyle(fontSize: 13, color: AppColors.error)),
            ],
          ),
        ),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFiltered ? AppColors.teal : const Color(0xFFE2E8F0),
            width: isFiltered ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: 15,
              color: isFiltered ? AppColors.teal : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Estado: ${_getStatusLabel(viewModel.statusFilter)}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isFiltered ? FontWeight.w800 : FontWeight.w600,
                color: isFiltered ? AppColors.tealDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isFiltered ? AppColors.teal : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Vista Tabla Pro [V]',
            icon: Icon(
              Icons.table_rows_rounded,
              size: 16,
              color: isTableView ? AppColors.tealDark : AppColors.textMuted,
            ),
            style: IconButton.styleFrom(
              backgroundColor: isTableView ? AppColors.surface : Colors.transparent,
              padding: const EdgeInsets.all(6),
              elevation: isTableView ? 1 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => onToggleTableView(true),
          ),
          IconButton(
            tooltip: 'Vista Tarjetas [V]',
            icon: Icon(
              Icons.grid_view_rounded,
              size: 16,
              color: !isTableView ? AppColors.tealDark : AppColors.textMuted,
            ),
            style: IconButton.styleFrom(
              backgroundColor: !isTableView ? AppColors.surface : Colors.transparent,
              padding: const EdgeInsets.all(6),
              elevation: !isTableView ? 1 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => onToggleTableView(false),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.teal : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.tealDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(child: _buildSearchField()),
                const SizedBox(width: 10),
                _buildStatusDropdown(context),
                const SizedBox(width: 8),
                DateFilterCalendar(
                  height: 40,
                  borderRadius: BorderRadius.circular(10),
                  dateRange: viewModel.dateRange,
                  onDateRangeSelected: (picked) {
                    viewModel.setDateRange(picked);
                  },
                  onClear: () {
                    viewModel.setDateRange(null);
                  },
                ),
                const SizedBox(width: 10),
                _buildViewToggle(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: AppColors.textSecondary,
                  tooltip: 'Refrescar órdenes [R]',
                  onPressed: onRefresh,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onNewOrder,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text(
                    'Nueva Orden [N]',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchField(),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      ...PurchaseOrdersScreen._statusLabels.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _buildFilterChip(
                            label: entry.value,
                            isSelected: viewModel.statusFilter == entry.key,
                            onTap: () => viewModel.setStatusFilter(entry.key),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      DateFilterCalendar(
                        height: 36,
                        borderRadius: BorderRadius.circular(10),
                        dateRange: viewModel.dateRange,
                        onDateRangeSelected: (picked) {
                          viewModel.setDateRange(picked);
                        },
                        onClear: () {
                          viewModel.setDateRange(null);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _PurchaseOrdersViewModel {
  final PurchaseOrdersCubit cubit;
  final PurchaseOrdersState state;
  _PurchaseOrdersViewModel(this.cubit, this.state);

  String get errorMessage {
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).message;
    }
    return '';
  }

  void clearError() => cubit.clearError();

  bool get isLoading =>
      state is PurchaseOrdersLoading || state is PurchaseOrdersInitial;

  List<dynamic> get orders {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).orders;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).currentOrders;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).currentOrders;
    }
    return [];
  }

  String get searchText {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).searchText;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).searchText;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).searchText;
    }
    return '';
  }

  String get statusFilter {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).statusFilter;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).statusFilter;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).statusFilter;
    }
    return 'Todos';
  }

  DateTimeRange? get dateRange {
    DateTime? start;
    DateTime? end;
    if (state is PurchaseOrdersLoaded) {
      start = (state as PurchaseOrdersLoaded).startDate;
      end = (state as PurchaseOrdersLoaded).endDate;
    } else if (state is PurchaseOrdersLoading) {
      start = (state as PurchaseOrdersLoading).startDate;
      end = (state as PurchaseOrdersLoading).endDate;
    } else if (state is PurchaseOrdersError) {
      start = (state as PurchaseOrdersError).startDate;
      end = (state as PurchaseOrdersError).endDate;
    }
    if (start != null && end != null) {
      return DateTimeRange(start: start, end: end);
    }
    return null;
  }

  int get currentPage {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).currentPage;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).currentPage;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).currentPage;
    }
    return 0;
  }

  int get totalPages {
    if (state is PurchaseOrdersLoaded) {
      return (state as PurchaseOrdersLoaded).totalPages;
    }
    if (state is PurchaseOrdersLoading) {
      return (state as PurchaseOrdersLoading).totalPages;
    }
    if (state is PurchaseOrdersError) {
      return (state as PurchaseOrdersError).totalPages;
    }
    return 1;
  }

  double get totalAmountFiltered {
    double total = 0;
    for (final o in orders) {
      total += (o.totalAmount ?? 0.0) as double;
    }
    return total;
  }

  int get pendingCountFiltered {
    int count = 0;
    for (final o in orders) {
      if (o.status == 'PENDING') count++;
    }
    return count;
  }

  void loadOrders({bool reset = false}) => cubit.loadOrders(refresh: reset);
  void setSearchText(String v) => cubit.setSearchText(v);
  void setStatusFilter(String v) => cubit.setStatusFilter(v);
  void setDateRange(DateTimeRange? v) => cubit.setDateRange(v?.start, v?.end);
  void setPage(int p) => cubit.loadOrders(page: p);
  Future<List<dynamic>> loadItemsForOrder(String id) async {
    final result = await sl<FetchPurchaseOrderItemsUseCase>().call(id);
    return result.fold((l) => [], (r) => r);
  }

  Future<void> updateOrderStatus(String id, String status) async {
    await cubit.updateOrderStatus(id, status);
  }
}
