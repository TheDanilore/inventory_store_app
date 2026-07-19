import 'package:injectable/injectable.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

/// UseCase encargado de construir el mensaje de WhatsApp y lanzar la URL.
/// Pertenece a la capa de dominio porque encapsula la regla de negocio
/// de cómo se comunica el pedido al vendedor.
@injectable
class SendWhatsAppOrderUc {
  Future<bool> call({
    required String whatsappNumber,
    required List<CartItemEntity> items,
    required String orderId,
    required double totalAPagar,
    required int puntosUsados,
  }) async {
    if (whatsappNumber.isEmpty) return false;

    final buffer = StringBuffer();
    buffer.writeln('Hola, me gustaría confirmar mi pedido (#$orderId):');
    buffer.writeln();

    for (final item in items) {
      final variantLabel =
          item.variantLabel != null ? ' Modelo: ${item.variantLabel}' : '';
      buffer.writeln('• ${item.quantity} x ${item.productName}$variantLabel');
    }

    buffer.writeln();
    if (puntosUsados > 0) {
      buffer.writeln('Puntos de billetera usados: $puntosUsados');
    }
    buffer.writeln('*Total a Pagar: S/ ${totalAPagar.toStringAsFixed(2)}*');

    final message = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('https://wa.me/$whatsappNumber?text=$message');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }
}
