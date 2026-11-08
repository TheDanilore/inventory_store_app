import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/data/models/purchase_order_model.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:url_launcher/url_launcher.dart';

/// Helper desacoplado para construir y compartir órdenes de compra por WhatsApp.
class PurchaseOrderWhatsAppHelper {
  PurchaseOrderWhatsAppHelper._();

  static Future<bool> shareOrder({
    required BuildContext context,
    required PurchaseOrderModel po,
    required List<PurchaseOrderItemEntity>? items,
  }) async {
    final shortCode =
        '#${po.id.length >= 8 ? po.id.substring(0, 8).toUpperCase() : po.id.toUpperCase()}';

    final itemsText =
        items != null && items.isNotEmpty
            ? items
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

*Proveedor:* ${po.supplierName}
*Fecha Emisión:* ${DateFormat('dd/MM/yyyy', 'es').format(po.createdAt)}
*Total Orden:* S/ ${po.totalAmount.toStringAsFixed(2)}

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
        return true;
      } else {
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message: 'No se pudo abrir WhatsApp.',
            type: SnackbarType.error,
          );
        }
        return false;
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al abrir WhatsApp para la orden ${po.id}',
        tag: 'PO_WHATSAPP_HELPER',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir WhatsApp: $e',
          type: SnackbarType.error,
        );
      }
      return false;
    }
  }
}

