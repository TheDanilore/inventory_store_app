import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

class InventoryBatchDetailPane extends StatelessWidget {
  final InventoryBatchItem batch;
  final VoidCallback? onClose;
  final bool isEmbedded;

  const InventoryBatchDetailPane({
    super.key,
    required this.batch,
    this.onClose,
    this.isEmbedded = true,
  });

  /// Muestra el detalle del lote como un Apple-style Modal BottomSheet en Móvil
  static Future<void> showAsBottomSheet(
    BuildContext context,
    InventoryBatchItem batch,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BatchDetailBottomSheet(batch: batch),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig(batch);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            isEmbedded
                ? BorderRadius.circular(AppColors.radiusLg)
                : BorderRadius.zero,
        border:
            isEmbedded
                ? Border.all(color: AppColors.border.withValues(alpha: 0.8))
                : null,
        boxShadow: isEmbedded ? AppColors.cardShadow(opacity: 0.03) : null,
      ),
      child: ClipRRect(
        borderRadius:
            isEmbedded
                ? BorderRadius.circular(AppColors.radiusLg)
                : BorderRadius.zero,
        child: Column(
          children: [
            // ── Cabecera Superior del Inspector ──
            _buildInspectorHeader(context, statusConfig),

            // ── Contenido con Scroll ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero del Producto
                    _buildProductHero(context),

                    const SizedBox(height: 18),

                    // Alerta Semántica de Estado de Caducidad
                    _buildStatusBanner(statusConfig),

                    const SizedBox(height: 18),

                    // Cuadrícula de Métricas Clave (Stock & Vencimiento)
                    _buildMetricGrid(context, statusConfig),

                    const SizedBox(height: 18),

                    // Datos Operativos del Lote (Almacén, Proveedor, Código)
                    _buildOperationalData(context),

                    const SizedBox(height: 24),

                    // Botones de Acción Rápida (Power User CTAs)
                    _buildQuickActions(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorHeader(
    BuildContext context,
    _StatusConfig statusConfig,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusConfig.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: statusConfig.color.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusConfig.icon, size: 14, color: statusConfig.color),
                const SizedBox(width: 6),
                Text(
                  statusConfig.label,
                  style: TextStyle(
                    color: statusConfig.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Botón de Copiar Lote Rápido
          Tooltip(
            message: 'Copiar código de lote',
            child: IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
              onPressed: () => _copyBatchCode(context),
              splashRadius: 18,
            ),
          ),
          if (onClose != null)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              onPressed: onClose,
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Widget _buildProductHero(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar del producto
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child:
                batch.imageUrl != null && batch.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                      imageUrl: batch.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => Container(
                            color: AppColors.background,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                      errorWidget:
                          (context, url, error) => const Icon(
                            Icons.broken_image_outlined,
                            size: 28,
                            color: AppColors.textMuted,
                          ),
                    )
                    : const Icon(
                      Icons.inventory_2_outlined,
                      size: 32,
                      color: AppColors.textMuted,
                    ),
          ),
        ),
        const SizedBox(width: 16),
        // Textos y variante
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                batch.productName ??
                    'Producto ${batch.productId.substring(0, 8)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (batch.variantAttrs != null &&
                      batch.variantAttrs!.isNotEmpty &&
                      batch.variantAttrs != 'Única')
                    _TagBadge(
                      label: batch.variantAttrs!,
                      icon: Icons.style_outlined,
                    ),
                  if (batch.sku != null && batch.sku!.isNotEmpty)
                    _TagBadge(
                      label: 'SKU: ${batch.sku!}',
                      icon: Icons.qr_code_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(_StatusConfig statusConfig) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusConfig.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusConfig.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(statusConfig.icon, size: 22, color: statusConfig.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusConfig.bannerTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: statusConfig.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusConfig.bannerDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: statusConfig.color.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricGrid(BuildContext context, _StatusConfig statusConfig) {
    return Row(
      children: [
        // Stock disponible
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.inventory_2_rounded,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Stock Disponible',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${batch.availableQuantity}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'unidades',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Fecha de Caducidad
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: statusConfig.color,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Vencimiento',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _formatDate(batch.expiryDate),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusConfig.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalData(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Datos de Rastreo y Origen',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          _DataRow(
            label: 'Código de Lote',
            value:
                batch.batchNumber == 'DEFAULT'
                    ? 'Sin número de lote'
                    : batch.batchNumber,
            isMonospace: true,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14),
              color: AppColors.primary,
              tooltip: 'Copiar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: () => _copyBatchCode(context),
            ),
          ),
          const Divider(height: 16, color: AppColors.divider),
          _DataRow(
            label: 'Almacén',
            value: batch.warehouseName ?? 'Almacén Principal',
            icon: Icons.warehouse_rounded,
          ),
          const Divider(height: 16, color: AppColors.divider),
          _DataRow(
            label: 'Proveedor',
            value: batch.supplierName ?? 'Sin proveedor asignado',
            icon: Icons.local_shipping_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CTA 1: Ver Kárdex
        ElevatedButton.icon(
          onPressed: () {
            context.push(
              '/admin/kardex?productId=${batch.productId}&variantId=${batch.variantId}&batchId=${batch.id}&batchNumber=${Uri.encodeComponent(batch.batchNumber)}&productName=${Uri.encodeComponent(batch.productName ?? '')}&variantName=${Uri.encodeComponent(batch.variantAttrs ?? batch.sku ?? '')}',
            );
          },
          icon: const Icon(Icons.receipt_long_rounded, size: 18),
          label: const Text('Ver Movimientos en Kárdex'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 10),
        // CTA 2: Ver Detalle del Producto en Catálogo
        OutlinedButton.icon(
          onPressed: () {
            context.push(
              '/admin/product/${batch.productId}?variantId=${batch.variantId}',
            );
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Abrir Ficha de Producto'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _copyBatchCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: batch.batchNumber));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Código de lote "${batch.batchNumber}" copiado'),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'Sin fecha';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
  }

  _StatusConfig _getStatusConfig(InventoryBatchItem b) {
    switch (b.status) {
      case 'vencido':
        final days = b.daysRemaining != null ? b.daysRemaining!.abs() : 0;
        return _StatusConfig(
          color: AppColors.danger,
          icon: Icons.block_rounded,
          label: 'LOTE VENCIDO',
          bannerTitle: 'Producto fuera de vigencia',
          bannerDescription:
              days == 0
                  ? 'Venció el día de hoy. No comercializar.'
                  : 'Venció hace $days días. Retirar de stock comercial.',
        );
      case 'critico':
        final d = b.daysRemaining ?? 0;
        return _StatusConfig(
          color: AppColors.warning,
          icon: Icons.warning_amber_rounded,
          label: d == 0 ? 'VENCE HOY' : 'VENCE EN $d DÍAS',
          bannerTitle: 'Lote en estado crítico',
          bannerDescription:
              'Prioridad de salida inmediata (PEPS / FIFO) antes del vencimiento.',
        );
      case 'proximo':
        return _StatusConfig(
          color: AppColors.info,
          icon: Icons.schedule_rounded,
          label: 'VENCE EN ${b.daysRemaining} DÍAS',
          bannerTitle: 'Caducidad próxima (< 90 días)',
          bannerDescription:
              'Monitorear rotación y coordinar promociones de salida.',
        );
      case 'normal':
        return _StatusConfig(
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
          label: 'ESTADO ÓPTIMO',
          bannerTitle: 'Lote en condiciones normales',
          bannerDescription: 'Vigencia prolongada y apto para venta regular.',
        );
      default:
        return _StatusConfig(
          color: AppColors.textSecondary,
          icon: Icons.remove_circle_outline_rounded,
          label: 'SIN VENCIMIENTO',
          bannerTitle: 'Sin control de caducidad',
          bannerDescription: 'Este producto no registra fecha de caducidad.',
        );
    }
  }
}

class _StatusConfig {
  final Color color;
  final IconData icon;
  final String label;
  final String bannerTitle;
  final String bannerDescription;

  _StatusConfig({
    required this.color,
    required this.icon,
    required this.label,
    required this.bannerTitle,
    required this.bannerDescription,
  });
}

class _TagBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const _TagBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final bool isMonospace;
  final Widget? trailing;

  const _DataRow({
    required this.label,
    required this.value,
    this.icon,
    this.isMonospace = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    );
  }
}

class _BatchDetailBottomSheet extends StatelessWidget {
  final InventoryBatchItem batch;

  const _BatchDetailBottomSheet({required this.batch});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle Apple HIG
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: InventoryBatchDetailPane(
                batch: batch,
                isEmbedded: false,
                onClose: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
