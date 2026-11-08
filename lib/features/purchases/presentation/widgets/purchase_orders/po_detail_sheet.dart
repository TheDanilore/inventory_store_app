import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_order_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_order_payment_method_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_header_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_items_list.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_sticky_footer.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_supplier_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/purchase_order_whatsapp_helper.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/dialogs/order_payment_dialog.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/dialogs/po_edit_payment_method_dialog.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_order_export_sheet.dart';

export 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_sticky_footer.dart';
export 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/dialogs/order_payment_dialog.dart';

/// Hoja de detalle de orden de compra de alto rendimiento.
///
/// Implementa:
/// - **Zero-Shimmer (Frame-0)**: Muestra inmediatamente `initialItems` desde caché L1.
/// - **Bajo Consumo de RAM/GPU**: Árbol modular descompuesto con [RepaintBoundary].
/// - **Mantenibilidad Clean Architecture**: Componentes atómicos desacoplados.
class PODetailSheet extends StatefulWidget {
  final PurchaseOrderModel po;
  final List<PurchaseOrderItemEntity>? initialItems;
  final Future<List<PurchaseOrderItemEntity>> Function() loadItems;
  final VoidCallback onReceive;
  final Future<void> Function(String) onUpdateStatus;
  final VoidCallback? onPaymentSuccess;
  final bool isDialog;

  const PODetailSheet({
    super.key,
    required this.po,
    this.initialItems,
    required this.loadItems,
    required this.onReceive,
    required this.onUpdateStatus,
    this.onPaymentSuccess,
    this.isDialog = false,
  });

  @override
  State<PODetailSheet> createState() => _PODetailSheetState();
}

class _PODetailSheetState extends State<PODetailSheet> {
  List<PurchaseOrderItemEntity>? _items;
  late bool _isLoadingItems = widget.initialItems == null;
  bool _isProcessingAction = false;

  late String _paymentMethod = widget.po.paymentMethod;
  late String _status = widget.po.status;
  late double _amountPaid = widget.po.amountPaid;

  double get _pending => widget.po.totalAmount - _amountPaid;
  bool get _canEditPaymentMethod =>
      (_status == 'SENT' || _status == 'PENDING') && _amountPaid == 0;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    _fetchItems();
  }

  @override
  void didUpdateWidget(covariant PODetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.po.id != widget.po.id) {
      _paymentMethod = widget.po.paymentMethod;
      _status = widget.po.status;
      _amountPaid = widget.po.amountPaid;
      _items = widget.initialItems;
      _isLoadingItems = widget.initialItems == null;
      _fetchItems();
    } else {
      if (oldWidget.po.status != widget.po.status) {
        _status = widget.po.status;
      }
      if (oldWidget.po.paymentMethod != widget.po.paymentMethod) {
        _paymentMethod = widget.po.paymentMethod;
      }
      if (oldWidget.po.amountPaid != widget.po.amountPaid) {
        _amountPaid = widget.po.amountPaid;
      }
    }
  }

  Future<void> _fetchItems() async {
    try {
      final items = await widget.loadItems();
      if (mounted) {
        setState(() {
          _items = items;
          _isLoadingItems = false;
        });
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al cargar detalles de la orden ${widget.po.id}',
        tag: 'PO_DETAIL_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _isLoadingItems = false);
        AppSnackbar.show(
          context,
          message: 'Error al cargar detalles: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _openExportSheet() {
    final paymentStatus =
        _amountPaid >= widget.po.totalAmount
            ? 'PAID'
            : (_amountPaid > 0 ? 'PARTIAL' : 'UNPAID');

    final currentPo = PurchaseOrderModel(
      id: widget.po.id,
      createdAt: widget.po.createdAt,
      supplierId: widget.po.supplierId,
      supplierName: widget.po.supplierName,
      warehouseId: widget.po.warehouseId,
      warehouseName: widget.po.warehouseName,
      status: _status,
      totalAmount: widget.po.totalAmount,
      paymentMethod: _paymentMethod,
      paymentStatus: paymentStatus,
      amountPaid: _amountPaid,
      dueDate: widget.po.dueDate,
      discountAmount: widget.po.discountAmount,
      taxAmount: widget.po.taxAmount,
      documentType: widget.po.documentType,
      documentNumber: widget.po.documentNumber,
      notes: widget.po.notes,
      itemCount: widget.po.itemCount,
    );

    PurchaseOrderExportSheet.show(
      context,
      po: currentPo,
      initialItems: _items,
      loadItems: widget.loadItems,
    );
  }

  Future<void> _handleUpdateStatus(String newStatus) async {
    if (_isProcessingAction) return;

    setState(() => _isProcessingAction = true);
    try {
      await widget.onUpdateStatus(newStatus);
      if (mounted) {
        setState(() => _status = newStatus);
        AppSnackbar.show(
          context,
          message: 'Estado actualizado correctamente.',
          type: SnackbarType.success,
        );
        if (!widget.isDialog) {
          Navigator.pop(context, true);
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al actualizar estado a $newStatus para orden ${widget.po.id}',
        tag: 'PO_DETAIL_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al actualizar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _confirmMarkSent() async {
    AppFeedbackService.lightImpact();
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Marcar como Enviada',
      message:
          '¿Estás seguro de que deseas marcar esta orden de compra como enviada al proveedor?',
      confirmText: 'Sí, marcar',
      cancelText: 'Cancelar',
      confirmColor: AppColors.primary,
    );
    if (confirmed == true && mounted) {
      await _handleUpdateStatus('SENT');
    }
  }

  Future<void> _confirmCancelOrder() async {
    AppFeedbackService.heavyImpact();
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Anular Orden',
      message:
          '¿Estás seguro de que deseas anular esta orden de compra? Esta acción no se puede deshacer.',
      confirmText: 'Sí, anular',
      cancelText: 'Cancelar',
      confirmColor: AppColors.danger,
    );
    if (confirmed == true && mounted) {
      await _handleUpdateStatus('CANCELLED');
    }
  }

  Future<void> _showPaymentDialog() async {
    List<SupplierFinancialAccountOption> accounts = [];
    final accountsRes = await sl<GetFinancialAccountsUseCase>().call();
    accountsRes.fold(
      (failure) => LoggerService.e(
        'Error al cargar cuentas: ${failure.message}',
        tag: 'PO_DETAIL_SHEET',
      ),
      (list) => accounts = list,
    );

    if (!mounted) return;
    if (accounts.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'No hay cuentas financieras activas disponibles.',
        type: SnackbarType.warning,
      );
      return;
    }

    final result = await OrderPaymentDialog.show(
      context,
      supplierName: widget.po.supplierName,
      pending: _pending,
      accounts: accounts,
    );

    if (result != null && mounted) {
      final supplierId = widget.po.supplierId;
      if (supplierId == null) {
        AppSnackbar.show(
          context,
          message: 'Error: La orden no tiene un proveedor asociado.',
          type: SnackbarType.error,
        );
        return;
      }

      context.read<PurchaseOrdersCubit>().registerOrderPayment(
        RegisterOrderPaymentParams(
          orderId: widget.po.id,
          supplierId: supplierId,
          amount: result.amount,
          accountId: result.accountId,
          shiftId: result.shiftId,
        ),
      );
    }
  }

  Future<void> _showEditPaymentMethodDialog() async {
    final newMethod = await POEditPaymentMethodDialog.show(
      context,
      currentMethod: _paymentMethod,
    );

    if (newMethod != null && newMethod != _paymentMethod && mounted) {
      final supplierId = widget.po.supplierId;
      if (supplierId == null) {
        AppSnackbar.show(
          context,
          message: 'Error: La orden no tiene un proveedor asociado.',
          type: SnackbarType.error,
        );
        return;
      }

      context.read<PurchaseOrdersCubit>().updateOrderPaymentMethod(
        UpdateOrderPaymentMethodParams(
          orderId: widget.po.id,
          supplierId: supplierId,
          newMethod: newMethod,
          oldMethod: _paymentMethod,
          orderAmount: widget.po.totalAmount,
        ),
      );
    }
  }

  Future<void> _sendWhatsAppMessage() async {
    final launched = await PurchaseOrderWhatsAppHelper.shareOrder(
      context: context,
      po: widget.po,
      items: _items,
    );

    if (launched && _status == 'PENDING' && mounted) {
      final changeStatus = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('¿Actualizar a ENVIADO?'),
              content: const Text(
                'Has compartido la orden de compra por WhatsApp. ¿Deseas actualizar el estado de la orden a "Enviado"?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Mantener Pendiente'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Sí, cambiar a Enviado'),
                ),
              ],
            ),
      );

      if (changeStatus == true && mounted) {
        await _handleUpdateStatus('SENT');
      }
    }
  }

  Future<void> _handleEditOrder() async {
    if (!widget.isDialog && context.canPop()) {
      Navigator.pop(context);
    }
    final edited = await context.push<bool>(
      '/purchase-orders/form?editOrderId=${widget.po.id}',
    );
    if (edited == true && mounted) {
      widget.onPaymentSuccess?.call();
      context.read<PurchaseOrdersCubit>().loadOrders(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shortCode =
        '#${widget.po.id.length >= 8 ? widget.po.id.substring(0, 8).toUpperCase() : widget.po.id.toUpperCase()}';

    return BlocListener<PurchaseOrdersCubit, PurchaseOrdersState>(
      listener: (context, state) {
        if (state is PurchaseOrderActionLoading) {
          setState(() => _isProcessingAction = true);
        } else if (state is PurchaseOrderActionSuccess) {
          setState(() {
            _isProcessingAction = false;
            if (state.orderId == widget.po.id) {
              if (state.newAmountPaid != null) {
                _amountPaid += state.newAmountPaid!;
              }
              if (state.newPaymentMethod != null) {
                _paymentMethod = state.newPaymentMethod!;
              }
            }
          });
          if (state.orderId == widget.po.id) {
            AppSnackbar.show(
              context,
              message: state.message,
              type: SnackbarType.success,
            );
            widget.onPaymentSuccess?.call();
          }
        } else if (state is PurchaseOrderActionError) {
          setState(() => _isProcessingAction = false);
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
        }
      },
      child: Material(
        color: AppColors.background,
        borderRadius:
            widget.isDialog
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(28)),
        child: SizedBox(
          height:
              widget.isDialog
                  ? double.infinity
                  : MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isDialog) const AppSheetDragHandle(),
              if (_isProcessingAction)
                const LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                ),

              // Cabecera modular
              PODetailHeaderBar(
                shortCode: shortCode,
                fullId: widget.po.id,
                status: _status,
                isDialog: widget.isDialog,
                isProcessing: _isProcessingAction,
                onExport: _openExportSheet,
                onClose: () => Navigator.of(context).pop(),
              ),

              const SizedBox(height: 4),

              // Contenido scrolleable virtualizado
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // Tarjeta de proveedor y finanzas
                      RepaintBoundary(
                        child: PODetailSupplierCard(
                          supplierName: widget.po.supplierName,
                          documentType: widget.po.documentType,
                          documentNumber: widget.po.documentNumber,
                          paymentMethod: _paymentMethod,
                          canEditPaymentMethod: _canEditPaymentMethod,
                          onEditPaymentMethod: _showEditPaymentMethodDialog,
                          createdAt: widget.po.createdAt,
                          totalAmount: widget.po.totalAmount,
                          amountPaid: _amountPaid,
                          status: _status,
                          pending: _pending,
                          isProcessingAction: _isProcessingAction,
                          onShowPaymentDialog: _showPaymentDialog,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'Productos Solicitados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Lista de productos con soporte Zero-Shimmer sobre caché L1
                      PODetailItemsList(
                        items: _items,
                        isLoading: _isLoadingItems,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Pie de página sticky con aislamiento de repintado
              RepaintBoundary(
                child: PODetailStickyFooter(
                  status: _status,
                  isProcessing: _isProcessingAction,
                  isDialog: widget.isDialog,
                  onReceive: widget.onReceive,
                  onMarkSent: _confirmMarkSent,
                  onSendWhatsApp: _sendWhatsAppMessage,
                  onCancel: _confirmCancelOrder,
                  onEdit:
                      (_status == 'PENDING' && _amountPaid == 0)
                          ? _handleEditOrder
                          : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
