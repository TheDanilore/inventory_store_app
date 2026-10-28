import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_order_items_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_a4_preview.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_action_bar.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/orders/receipt/receipt_ticket_preview.dart';

/// Panel interactivo de comprobación, impresión y envío de comprobantes de venta.
///
/// Implementado sobre [AdaptiveDetailSheet] con política Zero-Shimmer (Caché L1 Síncrono):
/// - **Desktop**: Side-sheet flotante deslizable a la derecha con desenfoque de fondo.
/// - **Mobile**: Bottom Sheet táctil con drag handle.
class OrderReceiptExportSheet extends StatefulWidget {
  final OrderEntity order;
  final List<OrderItemEntity>? initialItems;
  final bool isSaleSuccess;
  final String? customTitle;

  const OrderReceiptExportSheet({
    super.key,
    required this.order,
    this.initialItems,
    this.isSaleSuccess = false,
    this.customTitle,
  });

  static Future<T?> show<T>(
    BuildContext context, {
    required OrderEntity order,
    List<OrderItemEntity>? initialItems,
    bool isSaleSuccess = false,
    String? customTitle,
  }) {
    return AdaptiveDetailSheet.show<T>(
      context,
      desktopWidth: 480,
      breakpoint: 900,
      barrierLabel: 'Cerrar comprobante',
      builder:
          (dialogCtx) => OrderReceiptExportSheet(
            order: order,
            initialItems: initialItems,
            isSaleSuccess: isSaleSuccess,
            customTitle: customTitle,
          ),
    );
  }

  @override
  State<OrderReceiptExportSheet> createState() =>
      _OrderReceiptExportSheetState();
}

class _OrderReceiptExportSheetState extends State<OrderReceiptExportSheet> {
  ReceiptFormat _selectedFormat = ReceiptFormat.ticket;
  List<OrderItemEntity> _items = [];
  bool _isLoadingItems = false;
  String? _itemsError;

  @override
  void initState() {
    super.initState();
    _initializeItems();
  }

  /// Política Zero-Shimmer: Resolución síncrona en memoria antes del primer frame.
  void _initializeItems() {
    // 1. Prioridad: Ítems inyectados directamente (ej. desde POS o OrderDetail)
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items = widget.initialItems!;
      _isLoadingItems = false;
      return;
    }

    // 2. Prioridad: Caché L1 en memoria del repositorio (Zero-Shimmer / 0ms)
    final cached = sl<OrdersRepository>().getCachedOrderItems(widget.order.id);
    if (cached != null && cached.isNotEmpty) {
      _items = cached;
      _isLoadingItems = false;
      return;
    }

    // 3. Fallback: Consulta asíncrona mediante Caso de Uso de Dominio
    _loadOrderItems();
  }

  Future<void> _loadOrderItems() async {
    setState(() {
      _isLoadingItems = true;
      _itemsError = null;
    });

    try {
      final getOrderItemsUc = sl<GetOrderItemsUc>();
      final result = await getOrderItemsUc(widget.order.id);
      if (!mounted) return;

      result.fold(
        (failure) {
          setState(() {
            _isLoadingItems = false;
            _itemsError = failure.message;
          });
        },
        (items) {
          setState(() {
            _isLoadingItems = false;
            _items = items;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingItems = false;
          _itemsError = e.toString();
        });
      }
    }
  }

  String get _shortId {
    final id = widget.order.id;
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id;
  }

  DateTime get _orderTime {
    return (widget.order.createdAt ?? DateTime.now()).toUtc().subtract(
      const Duration(hours: 5),
    );
  }

  String get _voucherBadgeLabel {
    final docType = widget.order.documentType.toUpperCase();
    final receiptNum = widget.order.displayReceiptNumber;
    if (docType == 'FACTURA') {
      return 'Factura $receiptNum';
    } else if (docType == 'BOLETA') {
      return 'Boleta $receiptNum';
    } else {
      return 'Nota de Venta $receiptNum';
    }
  }

  bool get _isCreditOrder {
    final method = widget.order.paymentMethod.toUpperCase();
    final payStatus = widget.order.paymentStatus.toUpperCase();
    final status = widget.order.status.toUpperCase();
    return method.contains('CREDIT') ||
        payStatus == 'PENDING' ||
        payStatus == 'PARTIAL' ||
        status == 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigCubit>();
    final businessName =
        config.businessName.isNotEmpty ? config.businessName : 'DANILORE ONE';
    final taxId = config.businessTaxId;
    final address = config.businessAddress;
    final phone = config.businessPhone;

    final titleText =
        widget.customTitle ??
        (widget.isSaleSuccess
            ? 'Venta registrada (#$_shortId)'
            : 'Comprobante de Venta');

    return DetailSheetFrame(
      title: titleText,
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_rounded,
                  size: 11,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 4),
                Text(
                  _voucherBadgeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('dd/MM/yyyy HH:mm', 'es').format(_orderTime),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (widget.isSaleSuccess
                  ? const Color(0xFF22C55E)
                  : AppColors.primary)
              .withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          widget.isSaleSuccess
              ? Icons.check_circle_rounded
              : Icons.print_rounded,
          color:
              widget.isSaleSuccess
                  ? const Color(0xFF16A34A)
                  : AppColors.primary,
          size: 20,
        ),
      ),
      bodyPadding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── BARRA DE ACCIONES RÁPIDAS ──
          ReceiptActionBar(
            order: widget.order,
            items: _items,
            selectedFormat: _selectedFormat,
            isSaleSuccess: widget.isSaleSuccess,
            shortId: _shortId,
            config: config,
          ),

          const SizedBox(height: 16),

          // ── SELECTOR DE FORMATO (TICKET / A4) ──
          _buildFormatSelector(),

          const SizedBox(height: 16),

          // ── VISTA PREVIA DEL DOCUMENTO ──
          if (_isLoadingItems)
            _buildLoadingPreview()
          else if (_itemsError != null)
            _buildErrorPreview()
          else
            Center(
              child:
                  _selectedFormat == ReceiptFormat.ticket
                      ? ReceiptTicketPreview(
                        order: widget.order,
                        items: _items,
                        businessName: businessName,
                        taxId: taxId,
                        address: address,
                        phone: phone,
                        shortId: _shortId,
                        orderTime: _orderTime,
                        isCreditOrder: _isCreditOrder,
                      )
                      : ReceiptA4Preview(
                        order: widget.order,
                        items: _items,
                        businessName: businessName,
                        taxId: taxId,
                        address: address,
                        phone: phone,
                        shortId: _shortId,
                        orderTime: _orderTime,
                        isCreditOrder: _isCreditOrder,
                      ),
            ),
        ],
      ),
      footer: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              child: Text(
                widget.isSaleSuccess ? 'Nueva Venta / Cerrar' : 'Cerrar',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FormatTabButton(
              label: 'TICKET (80mm)',
              icon: Icons.receipt_long_rounded,
              isSelected: _selectedFormat == ReceiptFormat.ticket,
              onTap: () {
                if (_selectedFormat != ReceiptFormat.ticket) {
                  setState(() => _selectedFormat = ReceiptFormat.ticket);
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _FormatTabButton(
              label: 'FORMATO A4',
              icon: Icons.article_rounded,
              isSelected: _selectedFormat == ReceiptFormat.a4,
              onTap: () {
                if (_selectedFormat != ReceiptFormat.a4) {
                  setState(() => _selectedFormat = ReceiptFormat.a4);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'Cargando detalle del comprobante...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorPreview() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              'No se pudieron cargar los productos: $_itemsError',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loadOrderItems,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD97706) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? const [
                    BoxShadow(
                      color: Color(0x1AD97706),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
