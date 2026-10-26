import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_items_list.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_sticky_footer.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/dialogs/order_payment_dialog.dart';
export 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/components/po_detail_sticky_footer.dart';
export 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/dialogs/order_payment_dialog.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_order_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_order_payment_method_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';

import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/detail_sheet_header.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/financial_summary_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/purchase_order_export_sheet.dart';

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

  // ── Estado local "espejo" de los campos editables ──────────────────
  late String _paymentMethod = widget.po.paymentMethod;
  late String _status = widget.po.status;
  late double _amountPaid = widget.po.amountPaid;

  double get _pending => widget.po.totalAmount - _amountPaid;

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
        'Error al actualizar estado a $newStatus para la orden ${widget.po.id}',
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

  /// Confirmación para marcar como enviada con feedback háptico y diálogo.
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

  /// Confirmación de cancelación con feedback háptico y diálogo.
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

  bool get _canEditPaymentMethod =>
      (_status == 'SENT' || _status == 'PENDING') && _amountPaid == 0;

  Future<void> _showEditPaymentMethodDialog() async {
    String selectedMethod = _paymentMethod;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.edit_outlined, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Editar Método de Pago',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Seleccione la nueva forma de pago acordada:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedMethod,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'EFECTIVO',
                        child: Text('Efectivo'),
                      ),
                      DropdownMenuItem(
                        value: 'TARJETA',
                        child: Text('Tarjeta / Transferencia'),
                      ),
                      DropdownMenuItem(
                        value: 'CRÉDITO',
                        child: Text('Línea de Crédito'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedMethod = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      if (selectedMethod == _paymentMethod) return;
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
          newMethod: selectedMethod,
          oldMethod: _paymentMethod,
          orderAmount: widget.po.totalAmount,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return AppColors.warning;
      case 'SENT':
        return Colors.blue.shade400;
      case 'PARTIAL':
        return Colors.orange.shade400;
      case 'RECEIVED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING':
        return 'Pendiente';
      case 'SENT':
        return 'Enviado';
      case 'PARTIAL':
        return 'Parcial';
      case 'RECEIVED':
        return 'Recibido';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status;
    }
  }

  Future<void> _sendWhatsAppMessage() async {
    final shortCode =
        '#${widget.po.id.length >= 8 ? widget.po.id.substring(0, 8).toUpperCase() : widget.po.id.toUpperCase()}';

    final itemsText =
        _items != null && _items!.isNotEmpty
            ? _items!
                .map((i) {
                  final qty = i.quantityOrdered.toInt();
                  final price = 'S/ ${i.unitCost.toStringAsFixed(2)}';
                  final sub = 'S/ ${i.subtotal.toStringAsFixed(2)}';
                  final variant =
                      i.variantAttrs.isNotEmpty ? ' (${i.variantAttrs})' : '';
                  return '• *${i.productName ?? 'Producto'}$variant*\n   $qty x $price = *$sub*';
                })
                .join('\n\n')
            : 'Detalle de productos adjunto';

    final message = '''
📋 *ORDEN DE COMPRA $shortCode*

*Proveedor:* ${widget.po.supplierName}
*Fecha Emisión:* ${DateFormat('dd/MM/yyyy', 'es').format(widget.po.createdAt)}
*Total Orden:* S/ ${widget.po.totalAmount.toStringAsFixed(2)}

📦 *DETALLE DE PRODUCTOS:*
$itemsText

----------------------------------
Por favor confirmar recepción y fecha estimada de entrega. ¡Gracias!
''';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse('https://wa.me/?text=$encodedMessage');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);

        if (_status == 'PENDING' && mounted) {
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
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se pudo abrir WhatsApp.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al abrir WhatsApp para la orden ${widget.po.id}',
        tag: 'PO_DETAIL_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir WhatsApp: $e',
          type: SnackbarType.error,
        );
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration:
                    widget.isDialog
                        ? const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                        )
                        : null,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;

                    return Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Copiar ID completo (${widget.po.id})',
                          child: InkWell(
                            onTap: () {
                              Clipboard.setData(
                                ClipboardData(text: widget.po.id),
                              );
                              AppSnackbar.show(
                                context,
                                message: 'ID de orden copiado: ${widget.po.id}',
                                type: SnackbarType.info,
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  shortCode,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(
                          label: _statusLabel(_status),
                          color: _statusColor(_status),
                        ),
                        const Spacer(),
                        if (isNarrow) ...[
                          IconButton(
                            onPressed:
                                _isProcessingAction ? null : _openExportSheet,
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Exportar / Imprimir Orden',
                            visualDensity: VisualDensity.compact,
                          ),
                        ] else ...[
                          Tooltip(
                            message: 'Comprobar, imprimir o exportar orden',
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isProcessingAction ? null : _openExportSheet,
                              icon: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              label: const Text(
                                'Exportar / Imprimir',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                side: BorderSide(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                        if (widget.isDialog) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
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
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            tooltip: 'Cerrar detalle (Esc)',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 4),

              // ── Contenido scrolleable ──────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      // ── Card Proveedor y Finanzas ──────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Label PROVEEDOR
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'PROVEEDOR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  'Doc: ${widget.po.documentType.isNotEmpty ? widget.po.documentType : "N/A"}${widget.po.documentNumber != null && widget.po.documentNumber!.isNotEmpty ? " • ${widget.po.documentNumber}" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.po.supplierName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),

                            const Divider(height: 24, color: AppColors.border),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'MÉTODO DE PAGO',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          _paymentMethod,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        if (_canEditPaymentMethod) ...[
                                          const SizedBox(width: 4),
                                          InkWell(
                                            onTap:
                                                _isProcessingAction
                                                    ? null
                                                    : _showEditPaymentMethodDialog,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: const Padding(
                                              padding: EdgeInsets.all(2.0),
                                              child: Icon(
                                                Icons.edit_rounded,
                                                size: 16,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'FECHA EMISIÓN',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'dd/MM/yyyy HH:mm',
                                        'es',
                                      ).format(widget.po.createdAt.toLocal()),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // ── Card financiera con animación de conteo ──
                            FinancialSummaryCard(
                              columns: [
                                FinancialColumn(
                                  label: 'TOTAL',
                                  amount: widget.po.totalAmount,
                                  amountColor:
                                      _status == 'CANCELLED'
                                          ? AppColors.textMuted
                                          : AppColors.primary,
                                ),
                                FinancialColumn(
                                  label: 'PAGADO',
                                  amount: _amountPaid,
                                  amountColor: AppColors.success,
                                ),
                                FinancialColumn(
                                  label: 'DEUDA',
                                  amount:
                                      _status == 'CANCELLED' ? 0.0 : _pending,
                                  amountColor:
                                      (_status != 'CANCELLED' && _pending > 0)
                                          ? AppColors.danger
                                          : AppColors.textSecondary,
                                  alignment: CrossAxisAlignment.end,
                                ),
                              ],
                            ),
                            if (_status != 'CANCELLED' && _pending > 0) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.payments_rounded,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  label: Text(
                                    'Registrar Pago / Abono (S/ ${_pending.toStringAsFixed(2)})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 40),
                                    side: const BorderSide(
                                      color: AppColors.success,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed:
                                      _isProcessingAction
                                          ? null
                                          : _showPaymentDialog,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Lista de Items ─────────────────────────────
                      const Text(
                        'Productos Solicitados',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      PODetailItemsList(
                        items: _items,
                        isLoading: _isLoadingItems,
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Sticky Footer
              PODetailStickyFooter(
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
            ],
          ),
        ),
      ),
    );
  }
}
