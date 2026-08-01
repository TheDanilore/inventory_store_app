import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_order_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/update_order_payment_method_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/purchase_orders/purchase_orders_state.dart';

import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/detail_sheet_header.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/purchase_orders/financial_summary_card.dart';
import 'package:inventory_store_app/core/widgets/product_item_card.dart';

class PODetailSheet extends StatefulWidget {
  final PurchaseOrderModel po;
  final Future<List<PurchaseOrderItemEntity>> Function() loadItems;
  final VoidCallback onReceive;
  final Future<void> Function(String) onUpdateStatus;
  final VoidCallback? onPaymentSuccess;
  final bool isDialog;

  const PODetailSheet({
    super.key,
    required this.po,
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
  bool _isLoadingItems = true;
  bool _isProcessingAction = false;

  // ── Estado local "espejo" de los campos editables ──────────────────
  // widget.po es inmutable y viene del padre; si solo leemos de ahí,
  // los cambios hechos dentro de este sheet (método de pago, pago
  // registrado, estado) no se reflejan hasta que el padre vuelve a
  // construir el widget con una copia nueva de la orden (ej. tras un
  // refresh manual). Para que el sheet se actualice al instante,
  // guardamos copias locales y las mutamos con setState() apenas la
  // operación tiene éxito, en vez de depender únicamente del
  // Navigator.pop(context, true) para refrescar.
  late String _paymentMethod = widget.po.paymentMethod;
  late String _status = widget.po.status;
  late double _amountPaid = widget.po.amountPaid;

  double get _pending => widget.po.totalAmount - _amountPaid;

  @override
  void initState() {
    super.initState();
    _fetchItems();
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
    } catch (e) {
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
        Navigator.pop(context, true);
      }
    } catch (e) {
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

  /// Confirmación de cancelación con feedback háptico y diálogo.
  Future<void> _confirmCancelOrder() async {
    HapticFeedback.heavyImpact();
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
      (failure) => developer.log('Error al cargar cuentas: ${failure.message}'),
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

    String selectedAccountId = accounts.first.id;

    final amountCtrl = TextEditingController(text: _pending.toStringAsFixed(2));

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
                  Icon(Icons.payments_rounded, color: AppColors.success),
                  SizedBox(width: 8),
                  Text(
                    'Registrar Pago de Orden',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proveedor: ${widget.po.supplierName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Deuda Pendiente: S/ ${_pending.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cuenta Origen (Caja / Banco):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedAccountId,
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
                      items:
                          accounts.map((acc) {
                            return DropdownMenuItem<String>(
                              value: acc.id,
                              child: Text(
                                '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 13),
                              ),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedAccountId = val);
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      'Monto a pagar (S/):',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Confirmar Pago'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && mounted) {
      final payAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
      if (payAmount <= 0) {
        AppSnackbar.show(
          context,
          message: 'Ingrese un monto válido mayor a 0.',
          type: SnackbarType.error,
        );
        return;
      }

      final selAccFinal = accounts.firstWhere(
        (a) => a.id == selectedAccountId,
        orElse: () => accounts.first,
      );
      final accBalanceFinal = selAccFinal.balance;
      if (accBalanceFinal < payAmount) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                'Saldo insuficiente en la cuenta "${selAccFinal.name}". Saldo disponible: S/ ${accBalanceFinal.toStringAsFixed(2)}, Monto a pagar: S/ ${payAmount.toStringAsFixed(2)}.',
            type: SnackbarType.error,
          );
        }
        return;
      }

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
          amount: payAmount,
          accountId: selectedAccountId,
          shiftId: null, // El RPC de backend se encargará de resolver el shiftId
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
*Fecha Emisión:* ${DateFormat('dd/MM/yyyy').format(widget.po.createdAt)}
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
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir WhatsApp: $e',
          type: SnackbarType.error,
        );
      }
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
              ? BorderRadius.circular(20)
              : const BorderRadius.vertical(top: Radius.circular(28)),
      child: Container(
        height:
            widget.isDialog ? null : MediaQuery.of(context).size.height * 0.85,
        constraints:
            widget.isDialog
                ? BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                )
                : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag Handle (solo móvil/bottomsheet) ──
            if (!widget.isDialog) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_isProcessingAction)
              const LinearProgressIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.border,
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Copiar ID completo (${widget.po.id})',
                    child: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.po.id));
                        AppSnackbar.show(
                          context,
                          message: 'ID de orden copiado: ${widget.po.id}',
                          type: SnackbarType.info,
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Detalle de Orden $shortCode',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.copy_rounded,
                              size: 15,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusPill(
                    label: _statusLabel(_status),
                    color: _statusColor(_status),
                  ),
                  const Spacer(),
                ],
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
                    // Exportar PDF
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Tooltip(
                          message: 'Exportar orden en PDF',
                          child: TextButton.icon(
                            onPressed:
                                _isProcessingAction
                                    ? null
                                    : () {
                                      AppSnackbar.show(
                                        context,
                                        message: 'Función de PDF próximamente',
                                        type: SnackbarType.info,
                                      );
                                    },
                            icon: const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            label: const Text(
                              'Exportar PDF',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

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
                          // Label PROVEEDOR con contraste mejorado
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PROVEEDOR',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Tooltip(
                                message: 'Copiar ID completo (${widget.po.id})',
                                child: InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: widget.po.id),
                                    );
                                    AppSnackbar.show(
                                      context,
                                      message:
                                          'ID de orden copiado: ${widget.po.id}',
                                      type: SnackbarType.info,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          shortCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.copy_rounded,
                                          size: 13,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
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
                                amount: _status == 'CANCELLED' ? 0.0 : _pending,
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
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.success,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
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

                    if (_isLoadingItems)
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        itemBuilder:
                            (_, _) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: AppShimmer(
                                width: double.infinity,
                                height: 76,
                                borderRadius: 12,
                              ),
                            ),
                      )
                    else if (_items == null || _items!.isEmpty)
                      const Text(
                        'No hay productos en esta orden.',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    else
                      ...List.generate(_items!.length, (index) {
                        final item = _items![index];
                        final isFullyReceived = item.fullyReceived;
                        final progress =
                            item.quantityOrdered > 0
                                ? item.quantityReceived / item.quantityOrdered
                                : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ProductItemCard(
                            imageUrl: item.imageUrl,
                            productName: item.productName ?? '—',
                            variantLabel: item.variantAttrs,
                            // Progress bar de recepción (Mejora #4)
                            progressWidget: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: AppColors.border,
                                    color:
                                        isFullyReceived
                                            ? AppColors.success
                                            : AppColors.warning,
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Recibido: ${item.quantityReceived.toInt()} / ${item.quantityOrdered.toInt()}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isFullyReceived
                                            ? AppColors.success
                                            : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                            trailing: ItemPriceTrailing(
                              text: 'S/ ${item.subtotal.toStringAsFixed(2)}',
                            ),
                            animationDelay: Duration(milliseconds: 60 * index),
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Sticky Footer
            _StickyFooter(
              status: _status,
              isProcessing: _isProcessingAction,
              onReceive: widget.onReceive,
              onMarkSent: () => _handleUpdateStatus('SENT'),
              onSendWhatsApp: _sendWhatsAppMessage,
              onCancel: _confirmCancelOrder,
            ),
          ],
        ),
      ),
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Footer con AnimatedSwitcher
// ─────────────────────────────────────────────────────────────────────────────

class _StickyFooter extends StatelessWidget {
  final String status;
  final bool isProcessing;
  final VoidCallback onReceive;
  final VoidCallback onMarkSent;
  final VoidCallback onSendWhatsApp;
  final VoidCallback onCancel;

  const _StickyFooter({
    required this.status,
    required this.isProcessing,
    required this.onReceive,
    required this.onMarkSent,
    required this.onSendWhatsApp,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    // Sin acciones disponibles: no renderizar footer
    final showCancel = status != 'CANCELLED' && status != 'RECEIVED';
    final showReceive = status == 'SENT' || status == 'PARTIAL';
    final showMarkSent = status == 'PENDING';

    if (!showCancel && !showReceive && !showMarkSent) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botón de acción primaria con AnimatedSwitcher
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder:
                (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
            child: _buildPrimaryButton(context),
          ),

          // Botón destructivo siempre debajo
          if (showCancel) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: isProcessing ? null : onCancel,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: Text(
                  'Anular Orden',
                  style: TextStyle(
                    color:
                        isProcessing ? AppColors.textMuted : AppColors.danger,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(BuildContext context) {
    if (status == 'SENT' || status == 'PARTIAL') {
      return SizedBox(
        key: const ValueKey('receive'),
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.inventory_rounded, size: 20),
          label: const Text(
            'Recepcionar Mercadería',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: isProcessing ? null : onReceive,
        ),
      );
    }

    if (status == 'PENDING') {
      return Column(
        key: const ValueKey('pendingActions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat_rounded, size: 20),
              label: const Text(
                'Enviar a Proveedor (WhatsApp)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isProcessing ? null : onSendWhatsApp,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: isProcessing ? null : onMarkSent,
              child: const Text(
                'Marcar como ENVIADA',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    // RECEIVED o CANCELLED: sin acción primaria
    return const SizedBox.shrink(key: ValueKey('none'));
  }
}
