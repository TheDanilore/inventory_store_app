import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/orders/data/utils/order_pdf_generator.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:url_launcher/url_launcher.dart';

enum ReceiptFormat { ticket, a4 }

/// Barra superior de acciones rápidas para comprobantes: Impresión, WhatsApp, Correo, Descarga y Compartir.
class ReceiptActionBar extends StatefulWidget {
  final OrderEntity order;
  final List<OrderItemEntity> items;
  final ReceiptFormat selectedFormat;
  final bool isSaleSuccess;
  final String shortId;
  final AppConfigCubit config;

  const ReceiptActionBar({
    super.key,
    required this.order,
    required this.items,
    required this.selectedFormat,
    required this.isSaleSuccess,
    required this.shortId,
    required this.config,
  });

  @override
  State<ReceiptActionBar> createState() => _ReceiptActionBarState();
}

class _ReceiptActionBarState extends State<ReceiptActionBar> {
  bool _isProcessing = false;
  String? _processingLabel;

  Future<void> _handlePrint() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Preparando impresión...';
    });

    try {
      if (widget.selectedFormat == ReceiptFormat.ticket) {
        await OrderPdfGenerator.printTicket(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
        );
      } else {
        await OrderPdfGenerator.printA4(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
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
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleWhatsApp() async {
    final text = OrderPdfGenerator.buildWhatsAppText(
      widget.order,
      items: widget.items,
      businessName: widget.config.businessName,
      taxId: widget.config.businessTaxId,
    );

    String phone = widget.order.profilePhone ?? '';
    phone = phone.replaceAll(RegExp(r'\D'), '');

    if (phone.isEmpty) {
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
    final text = OrderPdfGenerator.buildWhatsAppText(
      widget.order,
      items: widget.items,
      businessName: widget.config.businessName,
      taxId: widget.config.businessTaxId,
    );

    final subject = Uri.encodeComponent(
      'Comprobante de Pedido #${widget.shortId} - ${widget.config.businessName}',
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

  Future<void> _handleDownload() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Guardando PDF...';
    });

    try {
      if (widget.selectedFormat == ReceiptFormat.ticket) {
        await OrderPdfGenerator.saveTicket(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
        );
      } else {
        await OrderPdfGenerator.saveA4(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
        );
      }
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Comprobante PDF guardado con éxito.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al guardar comprobante: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  Future<void> _handleShare() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _processingLabel = 'Preparando para compartir...';
    });

    try {
      if (widget.selectedFormat == ReceiptFormat.ticket) {
        await OrderPdfGenerator.shareTicket(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
        );
      } else {
        await OrderPdfGenerator.shareA4(
          widget.order,
          items: widget.items,
          businessName: widget.config.businessName,
          taxId: widget.config.businessTaxId,
          address: widget.config.businessAddress,
          phone: widget.config.businessPhone,
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
          _isProcessing = false;
          _processingLabel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: _isProcessing ? null : _handlePrint,
              icon:
                  _isProcessing &&
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

          // Fila 2: DESCARGAR + COMPARTIR
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  label: 'DESCARGAR',
                  icon: Icons.download_rounded,
                  color: const Color(0xFFD97706),
                  textColor: Colors.white,
                  isLoading:
                      _isProcessing &&
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
                      _isProcessing &&
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
