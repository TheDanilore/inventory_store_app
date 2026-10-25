import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

/// Modal responsivo (BottomSheet en Móvil, Dialog en Desktop/Tablet)
/// para desplegar y navegar a las operaciones clave vinculadas a un almacén:
/// 1. Stock e Inventario (filtrado por este almacén)
/// 2. Punto de Venta / Mostrador (POS)
/// 3. Turnos y Arqueos de Caja (Cash Shifts)
/// 4. Cuentas Financieras y Tesorería
class WarehouseOperationsSheet extends StatelessWidget {
  final WarehouseEntity warehouse;

  const WarehouseOperationsSheet({super.key, required this.warehouse});

  static Future<void> show(BuildContext context, WarehouseEntity warehouse) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog(
        context: context,
        builder:
            (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: WarehouseOperationsSheet(warehouse: warehouse),
              ),
            ),
      );
    } else {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => WarehouseOperationsSheet(warehouse: warehouse),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wh = warehouse;
    final idSnippet =
        wh.id.length > 8
            ? wh.id.substring(0, 8).toUpperCase()
            : wh.id.toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle superior en móvil ───────────────────────────
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Cabecera: Almacén + Estado + Cerrar ─────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color:
                          wh.isActive
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            wh.isActive
                                ? AppColors.primary.withValues(alpha: 0.2)
                                : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Icon(
                      Icons.store_mall_directory_rounded,
                      color:
                          wh.isActive ? AppColors.primary : AppColors.textMuted,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wh.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              'ID: #$idSnippet',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    wh.isActive
                                        ? AppColors.successLight.withValues(
                                          alpha: 0.6,
                                        )
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                wh.isActive ? 'ACTIVO' : 'INACTIVO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      wh.isActive
                                          ? AppColors.successDark
                                          : AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cerrar',
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      padding: const EdgeInsets.all(8),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),

              if (wh.address != null && wh.address!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          wh.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),
              const Text(
                'ACCESOS OPERATIVOS DEL ALMACÉN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // ── Opción 1: Ver Stock e Inventario ─────────────────────
              _OperationOptionCard(
                icon: Icons.inventory_2_outlined,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primary.withValues(alpha: 0.08),
                title: 'Stock e Inventario',
                subtitle:
                    'Consultar existencias, catálogo y lotes en este almacén',
                actionLabel: 'Ver stock',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/inventory?warehouseId=${wh.id}');
                },
              ),
              const SizedBox(height: 10),

              // ── Opción 2: Punto de Venta / Mostrador (POS) ───────────
              _OperationOptionCard(
                icon: Icons.point_of_sale_rounded,
                iconColor: const Color(0xFF0D9488),
                iconBgColor: const Color(0xFF0D9488).withValues(alpha: 0.08),
                title: 'Punto de Venta (Mostrador)',
                subtitle: 'Abrir mostrador de cobro y ventas en este almacén',
                actionLabel: 'Abrir POS',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/pos?warehouseId=${wh.id}');
                },
              ),
              const SizedBox(height: 10),

              // ── Opción 3: Turnos y Arqueos de Caja ────────────────────
              _OperationOptionCard(
                icon: Icons.query_builder_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFD97706).withValues(alpha: 0.08),
                title: 'Turnos y Arqueos de Caja',
                subtitle:
                    'Ver historial de turnos, aperturas, cierres y balance',
                actionLabel: 'Ver turnos',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/all-cash-shifts');
                },
              ),
              const SizedBox(height: 10),

              // ── Opción 4: Cuentas Financieras y Tesorería ─────────────
              _OperationOptionCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: const Color(0xFF4F46E5),
                iconBgColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                title: 'Cuentas y Tesorería',
                subtitle:
                    'Consultar cuentas de caja, bancos y movimientos contables',
                actionLabel: 'Ver cuentas',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/financial-accounts');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;

  const _OperationOptionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        hoverColor: const Color(0xFFF8FAFC),
        splashColor: iconColor.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: iconColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
