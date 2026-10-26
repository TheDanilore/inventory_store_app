import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:url_launcher/url_launcher.dart';

enum ReceiptFormat { ticket, a4 }

/// Panel interactivo de comprobación, impresión y envío de comprobantes de venta.
///
/// Implementado sobre [AdaptiveDetailSheet]:
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
  bool _isProcessingAction = false;
  String? _processingLabel;

  @override
  void initState() {
    super.initState();
    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      _items = widget.initialItems!;
    } else {
      _loadOrderItems();
    }
  }

  Future<void> _loadOrderItems() async {
    setState(() {
      _isLoadingItems = true;
      _itemsError = null;
    });

    try {
      final repository = sl<OrdersRepository>();
      final result = await repository.getOrderItems(widget.order.id);
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

  // ── ACCIONES RÁPIDAS ────────────────────────────────────────────────────────

  Future<void> _handlePrint() async {
    if (_isProcessingAction) return;
    setState(() {
      _isProcessingAction = true;
      _processingLabel = 'Preparando impresión...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      if (_selectedFormat == ReceiptFormat.ticket) {
        await OrderPdfGenerator.printTicket(
          widget.order,
          items: _items,
          businessName: config.businessName,
          taxId: config.businessTaxId,
          address: config.businessAddress,
          phone: config.businessPhone,
        );
      } else {
        await OrderPdfGenerator.printA4(
          widget.order,
          items: _items,
          businessName: config.businessName,
          taxId: config.businessTaxId,
          address: config.businessAddress,
          phone: config.businessPhone,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al enviar a imprimir: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleWhatsApp() async {
    final config = context.read<AppConfigCubit>();
    final text = OrderPdfGenerator.buildWhatsAppText(
      widget.order,
      items: _items,
      businessName: config.businessName,
      taxId: config.businessTaxId,
    );

    // Revisar si la orden tiene teléfono registrado
    String phone = widget.order.profilePhone ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty) {
      // Preguntar teléfono o abrir directo
      _promptPhoneNumber(text);
      return;
    }

    _launchWhatsAppUrl(phone, text);
  }

  void _promptPhoneNumber(String text) {
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.chat_rounded, color: Color(0xFF22C55E), size: 22),
                SizedBox(width: 8),
                Text('Enviar por WhatsApp', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingresa el número de WhatsApp del cliente:',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_rounded, size: 18),
                    hintText: 'Ej. 987654321',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogCtx).pop();
                  _launchWhatsAppUrl('', text);
                },
                child: const Text('Abrir sin número'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
                onPressed: () {
                  final raw = phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                  Navigator.of(dialogCtx).pop();
                  _launchWhatsAppUrl(raw, text);
                },
                child: const Text('Enviar'),
              ),
            ],
          ),
    );
  }

  Future<void> _launchWhatsAppUrl(String phone, String text) async {
    final encoded = Uri.encodeComponent(text);
    final String urlStr =
        phone.isNotEmpty
            ? 'https://wa.me/$phone?text=$encoded'
            : 'https://wa.me/?text=$encoded';

    final uri = Uri.parse(urlStr);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Texto del comprobante copiado al portapapeles.',
            type: SnackbarType.info,
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Texto del comprobante copiado al portapapeles.',
          type: SnackbarType.info,
        );
      }
    }
  }

  Future<void> _handleEmail() async {
    final config = context.read<AppConfigCubit>();
    final text = OrderPdfGenerator.buildWhatsAppText(
      widget.order,
      items: _items,
      businessName: config.businessName,
      taxId: config.businessTaxId,
    );

    final subject = Uri.encodeComponent(
      'Comprobante de Pedido #$_shortId - ${config.businessName}',
    );
    final body = Uri.encodeComponent(text);
    final emailUri = Uri.parse('mailto:?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Resumen copiado para redactar correo.',
            type: SnackbarType.info,
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Resumen copiado para redactar correo.',
          type: SnackbarType.info,
        );
      }
    }
  }

  Future<void> _handleSaveTicket() async {
    if (_isProcessingAction) return;
    setState(() {
      _isProcessingAction = true;
      _processingLabel = 'Guardando Ticket...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      await OrderPdfGenerator.saveTicket(
        widget.order,
        items: _items,
        businessName: config.businessName,
        taxId: config.businessTaxId,
        address: config.businessAddress,
        phone: config.businessPhone,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Ticket PDF guardado con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar Ticket: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleSaveA4() async {
    if (_isProcessingAction) return;
    setState(() {
      _isProcessingAction = true;
      _processingLabel = 'Guardando A4...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      await OrderPdfGenerator.saveA4(
        widget.order,
        items: _items,
        businessName: config.businessName,
        taxId: config.businessTaxId,
        address: config.businessAddress,
        phone: config.businessPhone,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Comprobante A4 PDF guardado con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar comprobante A4: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleDownload() async {
    if (_selectedFormat == ReceiptFormat.ticket) {
      await _handleSaveTicket();
    } else {
      await _handleSaveA4();
    }
  }

  Future<void> _handleShare() async {
    if (_isProcessingAction) return;
    setState(() {
      _isProcessingAction = true;
      _processingLabel = 'Preparando para compartir...';
    });

    try {
      final config = context.read<AppConfigCubit>();
      if (_selectedFormat == ReceiptFormat.ticket) {
        await OrderPdfGenerator.shareTicket(
          widget.order,
          items: _items,
          businessName: config.businessName,
          taxId: config.businessTaxId,
          address: config.businessAddress,
          phone: config.businessPhone,
        );
      } else {
        await OrderPdfGenerator.shareA4(
          widget.order,
          items: _items,
          businessName: config.businessName,
          taxId: config.businessTaxId,
          address: config.businessAddress,
          phone: config.businessPhone,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al compartir comprobante: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
          _processingLabel = null;
        });
      }
    }
  }

  // ── BUILD UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
          // ── BARRA DE ACCIONES SUPERIORES (Estilo exacto de la referencia) ──
          _buildActionButtonsBar(),

          const SizedBox(height: 16),

          // ── SELECTOR DE FORMATO (TICKET / A4) ──
          _buildFormatSelector(),

          const SizedBox(height: 16),

          // ── VISTA PREVIA DEL DOCUMENTO ("para comprobar o asi") ──
          if (_isLoadingItems)
            _buildLoadingPreview()
          else if (_itemsError != null)
            _buildErrorPreview()
          else
            _buildDocumentPreviewCard(),
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

  // ── BOTONES DE ACCIÓN RÁPIDA ────────────────────────────────────────────────

  Widget _buildActionButtonsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Botón Principal: REIMPRIMIR / IMPRIMIR (Negro / Carbón)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _isProcessingAction ? null : _handlePrint,
              icon:
                  _isProcessingAction &&
                          _processingLabel?.contains('impresión') == true
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print_rounded, size: 18),
              label: Text(
                widget.isSaleSuccess ? 'REIMPRIMIR' : 'IMPRIMIR',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Fila 1: WHATSAPP (Verde) + CORREO (Naranja)
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  label: 'WHATSAPP',
                  icon: Icons.chat_rounded,
                  color: const Color(0xFF22C55E),
                  textColor: Colors.white,
                  onTap: _handleWhatsApp,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  label: 'CORREO',
                  icon: Icons.mail_rounded,
                  color: const Color(0xFFF97316),
                  textColor: Colors.white,
                  onTap: _handleEmail,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fila 2: DESCARGAR + COMPARTIR (Diálogo nativo de compartir para apps móviles)
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  label: 'DESCARGAR',
                  icon: Icons.download_rounded,
                  color: const Color(0xFFD97706),
                  textColor: Colors.white,
                  isLoading:
                      _isProcessingAction &&
                      _processingLabel?.contains('Guardando') == true,
                  onTap: _handleDownload,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickActionButton(
                  label: 'COMPARTIR',
                  icon: Icons.share_rounded,
                  color: const Color(0xFF6366F1),
                  textColor: Colors.white,
                  isLoading:
                      _isProcessingAction &&
                      _processingLabel?.contains('compartir') == true,
                  onTap: _handleShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SELECTOR DE FORMATO ─────────────────────────────────────────────────────

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

  // ── VISTA PREVIA DEL DOCUMENTO ──────────────────────────────────────────────

  Widget _buildDocumentPreviewCard() {
    final config = context.read<AppConfigCubit>();
    final businessName =
        config.businessName.isNotEmpty ? config.businessName : 'DANILORE ONE';
    final taxId = config.businessTaxId;
    final address = config.businessAddress;
    final phone = config.businessPhone;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child:
            _selectedFormat == ReceiptFormat.ticket
                ? _buildTicketPreviewContent(
                  businessName: businessName,
                  taxId: taxId,
                  address: address,
                  phone: phone,
                )
                : _buildA4PreviewContent(
                  businessName: businessName,
                  taxId: taxId,
                  address: address,
                  phone: phone,
                ),
      ),
    );
  }

  Widget _buildTicketPreviewContent({
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) {
    final opGravada =
        widget.order.subtotalAmount > 0
            ? widget.order.subtotalAmount
            : double.parse(
              (widget.order.totalAmount / 1.18).toStringAsFixed(2),
            );
    final igvAmount =
        widget.order.taxAmount > 0
            ? widget.order.taxAmount
            : double.parse(
              (widget.order.totalAmount - opGravada).toStringAsFixed(2),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Encabezado
        Center(
          child: Text(
            businessName.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        if (taxId.isNotEmpty) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              'RUC: $taxId',
              style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
            ),
          ),
        ],
        if (address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              address,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ),
        ],
        if (phone.isNotEmpty) ...[
          const SizedBox(height: 2),
          Center(
            child: Text(
              'Telf: $phone',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
            ),
          ),
        ],

        const SizedBox(height: 12),
        _dashedDivider(),
        const SizedBox(height: 8),

        // Meta del Ticket
        Center(
          child: Text(
            widget.order.documentType == 'FACTURA'
                ? 'FACTURA ELECTRÓNICA'
                : (widget.order.documentType == 'BOLETA'
                    ? 'BOLETA DE VENTA ELECTRÓNICA'
                    : 'NOTA DE VENTA'),
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
        Center(
          child: Text(
            widget.order.displayReceiptNumber,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(height: 6),

        _ticketRow(
          'FECHA:',
          DateFormat('dd/MM/yyyy HH:mm', 'es').format(_orderTime),
        ),
        _ticketRow('CLIENTE:', widget.order.displayCustomerName),
        if (widget.order.customerDocumentNumber != null &&
            widget.order.customerDocumentNumber!.isNotEmpty)
          _ticketRow(
            '${widget.order.customerDocumentType ?? "DOC"}:',
            widget.order.customerDocumentNumber!,
          ),
        if (widget.order.customerAddress != null &&
            widget.order.customerAddress!.isNotEmpty)
          _ticketRow('DIRECCIÓN:', widget.order.customerAddress!),
        _ticketRow('PAGO:', widget.order.paymentMethod),
        if (widget.order.paymentReference != null &&
            widget.order.paymentReference!.isNotEmpty)
          _ticketRow('REF. OPERACIÓN:', widget.order.paymentReference!),
        if (_isCreditOrder)
          _ticketRow(
            'CONDICIÓN:',
            widget.order.paymentStatus.toUpperCase() == 'PARTIAL'
                ? 'CRÉDITO (PAGO PARCIAL)'
                : 'AL CRÉDITO (PENDIENTE)',
          ),

        const SizedBox(height: 8),
        _dashedDivider(),
        const SizedBox(height: 8),

        // Tabla de Items
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'CANT x DESCRIPCIÓN',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
            Text(
              'IMPORTE',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        ..._items.map((item) {
          String displayName = item.productName ?? 'Producto';
          final vLabel = item.variantLabel.trim();
          if (item.hasVariantAttributes && vLabel.isNotEmpty) {
            displayName += ' ($vLabel)';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '${item.quantity} x $displayName',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'S/ ${item.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),
        _dashedDivider(),
        const SizedBox(height: 8),

        // Totales
        _ticketRow('OP. GRAVADA:', 'S/ ${opGravada.toStringAsFixed(2)}'),
        _ticketRow('I.G.V. (18%):', 'S/ ${igvAmount.toStringAsFixed(2)}'),
        if (widget.order.discountAmount > 0)
          _ticketRow(
            'DESCUENTO:',
            '- S/ ${widget.order.discountAmount.toStringAsFixed(2)}',
          ),
        if (widget.order.pointsUsed > 0)
          _ticketRow('PUNTOS USADOS:', '- ${widget.order.pointsUsed} pts'),

        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL A PAGAR:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              'S/ ${widget.order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _dashedDivider(),
        const SizedBox(height: 12),

        // Código de barras / QR representativo
        Center(
          child: SizedBox(
            height: 38,
            width: 170,
            child: BarcodeWidget(
              barcode: Barcode.code128(),
              data: _shortId,
              drawText: false,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '#$_shortId',
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '¡Gracias por su compra!',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildA4PreviewContent({
    required String businessName,
    required String taxId,
    required String address,
    required String phone,
  }) {
    final a4OpGravada =
        widget.order.subtotalAmount > 0
            ? widget.order.subtotalAmount
            : double.parse(
              (widget.order.totalAmount / 1.18).toStringAsFixed(2),
            );
    final a4IgvAmount =
        widget.order.taxAmount > 0
            ? widget.order.taxAmount
            : double.parse(
              (widget.order.totalAmount - a4OpGravada).toStringAsFixed(2),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cabecera institucional
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    businessName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (taxId.isNotEmpty)
                    Text(
                      'RUC: $taxId',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  if (address.isNotEmpty)
                    Text(
                      address,
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  if (phone.isNotEmpty)
                    Text(
                      'Telf: $phone',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF0F172A), width: 1.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                children: [
                  if (taxId.isNotEmpty)
                    Text(
                      'R.U.C. $taxId',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  Text(
                    widget.order.documentType == 'FACTURA'
                        ? 'FACTURA ELECTRÓNICA'
                        : (widget.order.documentType == 'BOLETA'
                            ? 'BOLETA ELECTRÓNICA'
                            : 'NOTA DE VENTA'),
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.order.displayReceiptNumber,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Bloque del cliente
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cliente: ${widget.order.displayCustomerName}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.order.customerDocumentNumber != null &&
                  widget.order.customerDocumentNumber!.isNotEmpty)
                Text(
                  '${widget.order.customerDocumentType ?? "Documento"}: ${widget.order.customerDocumentNumber}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF475569),
                  ),
                ),
              if (widget.order.customerAddress != null &&
                  widget.order.customerAddress!.isNotEmpty)
                Text(
                  'Dirección: ${widget.order.customerAddress}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: Color(0xFF475569),
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                'Fecha: ${DateFormat('dd/MM/yyyy HH:mm', 'es').format(_orderTime)}  |  Pago: ${widget.order.paymentMethod}${_isCreditOrder ? " (Al Crédito)" : ""}',
                style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Tabla A4
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                color: const Color(0xFF1E293B),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: Row(
                  children: const [
                    SizedBox(
                      width: 24,
                      child: Text(
                        'CANT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'DESCRIPCIÓN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ..._items.map((it) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4.5,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${it.quantity}',
                          style: const TextStyle(fontSize: 8.5),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          it.productName ?? 'Producto',
                          style: const TextStyle(fontSize: 8.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'S/ ${it.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Total
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 190,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('OP. GRAVADA:', style: TextStyle(fontSize: 8.5)),
                    Text(
                      'S/ ${a4OpGravada.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'I.G.V. (18%):',
                      style: TextStyle(fontSize: 8.5),
                    ),
                    Text(
                      'S/ ${a4IgvAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 6, color: Color(0xFFE2E8F0)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'S/ ${widget.order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _ticketRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashedDivider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashSpace = 3.0;
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFCBD5E1)),
              ),
            );
          }),
        );
      },
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

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  final bool isLoading;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.textColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: FilledButton.icon(
        onPressed: isLoading ? null : onTap,
        icon:
            isLoading
                ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : Icon(icon, size: 17, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textColor,
            letterSpacing: 0.5,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
