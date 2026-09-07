import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_purchase_order_items_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/po_detail_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

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
  Timer? _debounce;
  PurchaseOrderModel? _selectedOrder;

  static const _statusLabels = {
    'Todos': 'Todos',
    'PENDING': 'Pendiente',
    'SENT': 'Enviado',
    'PARTIAL': 'Parcial',
    'RECEIVED': 'Recibido',
    'CANCELLED': 'Cancelado',
  };

  static Color? _statusColorForFilter(String key) {
    switch (key) {
      case 'PENDING':
        return AppColors.warning;
      case 'SENT':
        return const Color(0xFF3B82F6);
      case 'PARTIAL':
        return Colors.amber.shade800;
      case 'RECEIVED':
        return AppColors.teal;
      case 'CANCELLED':
        return AppColors.error;
      default:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _checkDraft();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      cubit.loadOrders(refresh: true);
    });
  }

  Future<void> _checkDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('po_form_draft_v1');
    if (str != null) {
      try {
        final data = jsonDecode(str) as Map<String, dynamic>;
        final items = data['items'] as List?;
        setState(() {
          _hasDraft = items != null && items.isNotEmpty;
        });
      } catch (_) {
        if (mounted) setState(() => _hasDraft = false);
      }
    } else {
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

    // '/' para enfocar buscador instantáneamente
    if (event.logicalKey == LogicalKeyboardKey.slash) {
      if (!_searchFocusNode.hasFocus) {
        _searchFocusNode.requestFocus();
        _searchCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _searchCtrl.text.length,
        );
        return KeyEventResult.handled;
      }
    }

    // Escape para desenfocar buscador o deseleccionar orden
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
        return KeyEventResult.handled;
      }
      if (_selectedOrder != null) {
        setState(() => _selectedOrder = null);
        return KeyEventResult.handled;
      }
    }

    // Flechas arriba y abajo para navegar órdenes en split-view
    final filtered = viewModel.orders.cast<PurchaseOrderModel>();
    if (filtered.isNotEmpty && !_searchFocusNode.hasFocus) {
      final currentIndex =
          _selectedOrder != null
              ? filtered.indexWhere((o) => o.id == _selectedOrder!.id)
              : -1;

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final nextIndex = (currentIndex + 1).clamp(0, filtered.length - 1);
        setState(() => _selectedOrder = filtered[nextIndex]);
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        final prevIndex = (currentIndex - 1).clamp(0, filtered.length - 1);
        setState(() => _selectedOrder = filtered[prevIndex]);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  Widget _buildRefreshButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
      },
      icon: const Icon(
        Icons.refresh_rounded,
        size: 16,
        color: AppColors.textSecondary,
      ),
      label: const Text(
        'Actualizar',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        minimumSize: const Size(0, 40),
      ),
    );
  }

  Widget _buildNewOrderButton(BuildContext context, {bool isHeader = false}) {
    if (isHeader) {
      return FilledButton.icon(
        onPressed: () {
          context.go('/admin/purchase-orders/form');
        },
        icon: Icon(
          _hasDraft ? Icons.edit_note_rounded : Icons.add_rounded,
          size: 18,
        ),
        label: Text(
          _hasDraft ? 'Continuar Borrador' : 'Nueva orden',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () {
        context.go('/admin/purchase-orders/form');
      },
      icon: Icon(_hasDraft ? Icons.edit_note_rounded : Icons.add_rounded),
      label: Text(
        _hasDraft ? 'Continuar Borrador' : 'Nueva orden',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor:
          _hasDraft ? const Color(0xFFF59E0B) : AppColors.primary,
      foregroundColor: Colors.white,
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
                if (context.mounted) {
                  context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
                }
              },
              loadItems: () async {
                final res = await sl<FetchPurchaseOrderItemsUseCase>().call(
                  po.id,
                );
                return res.fold((l) => [], (r) => r);
              },
              onReceive: () => _handleReceiveOrder(context, po),
              onUpdateStatus: (status) async {
                await viewModel.updateOrderStatus(po.id, status);
              },
            ),
          ),
    );
  }

  Future<void> _handleReceiveOrder(
    BuildContext context,
    PurchaseOrderModel po,
  ) async {
    final res = await sl<FetchPurchaseOrderItemsUseCase>().call(po.id);
    final items = res.fold((l) => <PurchaseOrderItemEntity>[], (r) => r);
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
      '/admin/inventory-entries/form?purchaseOrderId=${po.id}',
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
          isCompact: isTablet,
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
      actions:
          isDesktopOrTablet
              ? [
                  _buildRefreshButton(context),
                  const SizedBox(width: 8),
                  _buildNewOrderButton(context, isHeader: true),
                ]
              : null,
      floatingActionButton:
          isDesktopOrTablet
              ? null
              : _buildNewOrderButton(context, isHeader: false),
      body: Focus(
        focusNode: _screenFocusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isTablet = constraints.maxWidth >= 800;

            return BlocBuilder<PurchaseOrdersCubit, PurchaseOrdersState>(
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

                // Sincronizar orden seleccionada si existe en la lista filtrada o por query param
                final querySelectedId =
                    GoRouterState.of(context).uri.queryParameters['selectedId'];
                if (filtered.isNotEmpty) {
                  if (_selectedOrder != null) {
                    final index = filtered.indexWhere(
                      (o) => o.id == _selectedOrder!.id,
                    );
                    if (index != -1) {
                      _selectedOrder = filtered[index];
                    } else if (isTablet) {
                      _selectedOrder = filtered.first;
                    }
                  } else if (querySelectedId != null) {
                    final index = filtered.indexWhere(
                      (o) => o.id == querySelectedId,
                    );
                    if (index != -1) {
                      _selectedOrder = filtered[index];
                      if (!isTablet) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && _selectedOrder != null) {
                            _showDetail(context, _selectedOrder!);
                          }
                        });
                      }
                    } else if (isTablet) {
                      _selectedOrder = filtered.first;
                    }
                  } else if (isTablet) {
                    _selectedOrder = filtered.first;
                  }
                } else {
                  _selectedOrder = null;
                }

                final listContent = Column(
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
                                context.go('/admin/purchase-orders/form');
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

                    // ── Ribbon Compacto de KPIs (42dp) ──────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: _CompactKpiRibbon(
                        orderCount: filtered.length,
                        totalAmount: totalAmount,
                        pendingCount: pendingCount,
                      ),
                    ),

                    // ── Filtros y Búsqueda ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _SearchField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocusNode,
                                  hint: 'Buscar proveedor, doc... (Presiona /)',
                                  onChanged: (v) {
                                    _debounce?.cancel();
                                    _debounce = Timer(
                                      const Duration(milliseconds: 300),
                                      () => viewModel.setSearchText(v),
                                    );
                                  },
                                  onSubmitted: (v) {
                                    _debounce?.cancel();
                                    viewModel.setSearchText(v);
                                  },
                                  onClear: () {
                                    _debounce?.cancel();
                                    _searchCtrl.clear();
                                    viewModel.setSearchText('');
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              DateFilterCalendar(
                                height: 40,
                                borderRadius: BorderRadius.circular(10),
                                dateRange: viewModel.dateRange,
                                onDateRangeSelected:
                                    (range) => cubit.setDateRange(
                                      range.start,
                                      range.end,
                                    ),
                                onClear: () => cubit.setDateRange(null, null),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final chips =
                                  _statusLabels.entries.map((e) {
                                    final sel = viewModel.statusFilter == e.key;
                                    final color = _statusColorForFilter(e.key);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        right: 8,
                                        bottom: 6,
                                      ),
                                      child: _POFilterPill(
                                        label: e.value,
                                        isSelected: sel,
                                        activeColor: color,
                                        onTap:
                                            () => viewModel.setStatusFilter(
                                              e.key,
                                            ),
                                      ),
                                    );
                                  }).toList();

                              if (constraints.maxWidth > 600) {
                                return Wrap(children: chips);
                              }

                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                child: Row(children: chips),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

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
                                  border: Border.all(color: AppColors.border),
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
                                border: Border.all(color: AppColors.border),
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

                    // ── Lista de Órdenes ──────────────────────────────────────
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child:
                            viewModel.isLoading
                                ? ListView.separated(
                                  key: const ValueKey('loading'),
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    0,
                                  ),
                                  itemCount: 5,
                                  separatorBuilder:
                                      (_, _) => const SizedBox(height: 10),
                                  itemBuilder:
                                      (_, _) => AppShimmer(
                                        width: double.infinity,
                                        height: 90,
                                        borderRadius: 16,
                                      ),
                                )
                                : filtered.isEmpty
                                ? AppEmptyState(
                                  key: const ValueKey('empty'),
                                  icon: Icons.shopping_cart_outlined,
                                  title: 'Sin Resultados',
                                  message:
                                      'Sin resultados para los filtros aplicados',
                                )
                                : RefreshIndicator(
                                  key: ValueKey(
                                    '${viewModel.statusFilter}_${viewModel.currentPage}',
                                  ),
                                  color: AppColors.primary,
                                  onRefresh:
                                      () => cubit.loadOrders(refresh: true),
                                  child: ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      isTablet ? 16 : 80,
                                    ),
                                    itemCount: filtered.length,
                                    separatorBuilder:
                                        (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final po = filtered[index];
                                      final isSel =
                                          isTablet &&
                                          _selectedOrder?.id == po.id;
                                      return POCard(
                                        po: po,
                                        isSelected: isSel,
                                        onTap: () {
                                          if (isTablet) {
                                            setState(() {
                                              _selectedOrder = po;
                                            });
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

                // ── ESTRUCTURA DOS PANELES (SPLIT VIEW ERP) ──────────────────
                if (isTablet) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: listContent),
                      Container(width: 1, color: AppColors.border),
                      Expanded(
                        flex: 6,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child:
                              _selectedOrder == null
                                  ? const AppEmptyState(
                                    key: ValueKey('empty_detail'),
                                    icon: Icons.receipt_long_rounded,
                                    title: 'Ninguna Orden Seleccionada',
                                    message:
                                        'Selecciona una orden del panel izquierdo o navega con las flechas ↑/↓.',
                                  )
                                  : Padding(
                                    key: ValueKey(_selectedOrder!.id),
                                    padding: const EdgeInsets.all(16.0),
                                    child: PODetailSheet(
                                      po: _selectedOrder!,
                                      isDialog: true,
                                      onPaymentSuccess: () {
                                        if (context.mounted) {
                                          context
                                              .read<PurchaseOrdersCubit>()
                                              .loadOrders(refresh: true);
                                        }
                                      },
                                      loadItems: () async {
                                        final res = await sl<
                                              FetchPurchaseOrderItemsUseCase
                                            >()
                                            .call(_selectedOrder!.id);
                                        return res.fold((l) => [], (r) => r);
                                      },
                                      onReceive:
                                          () => _handleReceiveOrder(
                                            context,
                                            _selectedOrder!,
                                          ),
                                      onUpdateStatus: (status) async {
                                        await viewModel.updateOrderStatus(
                                          _selectedOrder!.id,
                                          status,
                                        );
                                        if (mounted && _selectedOrder != null) {
                                          setState(() {
                                            _selectedOrder = _selectedOrder!
                                                .copyWith(status: status);
                                          });
                                        }
                                      },
                                    ),
                                  ),
                        ),
                      ),
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
// Ribbon Compacto de KPIs (Estilo Stripe / Linear, altura fija 42dp)
// ─────────────────────────────────────────────────────────────────────────────

class _CompactKpiRibbon extends StatelessWidget {
  final int orderCount;
  final double totalAmount;
  final int pendingCount;

  const _CompactKpiRibbon({
    required this.orderCount,
    required this.totalAmount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            const Text(
              'Órdenes: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$orderCount',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 16, color: AppColors.border),
            const SizedBox(width: 14),

            const Icon(Icons.payments_rounded, size: 16, color: AppColors.teal),
            const SizedBox(width: 6),
            const Text(
              'Total Pág: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              'S/ ${totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(width: 14),
            Container(width: 1, height: 16, color: AppColors.border),
            const SizedBox(width: 14),

            Icon(
              Icons.pending_actions_rounded,
              size: 16,
              color: pendingCount > 0 ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: 6),
            const Text(
              'Pendientes: ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$pendingCount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color:
                    pendingCount > 0 ? AppColors.warning : AppColors.success,
              ),
            ),
          ],
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
        border: Border.all(color: AppColors.border),
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
          hintStyle: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 18,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 36,
            minHeight: 40,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
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
                ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.slateLight.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  '/',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
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

class _POFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? activeColor;

  const _POFilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = activeColor ?? AppColors.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? effectiveColor.withValues(alpha: 0.12)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? effectiveColor : AppColors.border,
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected && activeColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: effectiveColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? effectiveColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
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
