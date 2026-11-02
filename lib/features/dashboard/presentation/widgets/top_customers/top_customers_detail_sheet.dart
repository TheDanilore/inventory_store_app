import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal adaptativo unificado para ver detalles rápidos y acciones de un cliente VIP
class TopCustomerDetailSheet extends StatelessWidget {
  final CustomerEntity customer;

  const TopCustomerDetailSheet({super.key, required this.customer});

  static Future<void> show(BuildContext context, CustomerEntity customer) {
    return AdaptiveDetailSheet.show<void>(
      context,
      desktopWidth: 480,
      breakpoint: 720,
      barrierLabel: 'Cerrar detalle de cliente',
      builder: (_) => TopCustomerDetailSheet(customer: customer),
    );
  }

  Future<void> _callPhone(BuildContext context, String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo abrir la aplicación de llamadas.',
          type: SnackbarType.warning,
        );
      }
    } catch (e, st) {
      LoggerService.e(
        'Error al lanzar llamada telefónica',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    try {
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      // Prefijo Perú 51 por defecto si son 9 dígitos locales
      final formattedNumber =
          cleanPhone.length == 9 ? '51$cleanPhone' : cleanPhone;
      final uri = Uri.parse('https://wa.me/$formattedNumber');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo abrir WhatsApp.',
          type: SnackbarType.warning,
        );
      }
    } catch (e, st) {
      LoggerService.e('Error al lanzar WhatsApp', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  customer.fullName.isNotEmpty
                      ? customer.fullName[0].toUpperCase()
                      : 'C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.fullName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      customer.documentNumber != null &&
                              customer.documentNumber!.isNotEmpty
                          ? '${customer.documentType ?? 'DOC'}: ${customer.documentNumber}'
                          : 'Cliente Destacado VIP',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Estadísticas de compra del cliente
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark ? AppColors.darkSurfaceElevated : AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Comprado',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isDark
                                  ? const Color(0xFF94A3B8)
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'S/ ${customer.totalRevenue.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color:
                              isDark
                                  ? const Color(0xFF34D399)
                                  : AppColors.tealDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pedidos Despachados',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${customer.orderCount} órdenes',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Acciones de comunicación
          Row(
            children: [
              if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPhone(context, customer.phone!),
                    icon: const Icon(Icons.phone_rounded, size: 18),
                    label: const Text('Llamar'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _openWhatsApp(context, customer.phone!),
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                    ),
                    label: const Text('WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/customers');
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Ver en Clientes'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
