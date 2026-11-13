import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductSalesChannelsCard extends StatelessWidget {
  const ProductSalesChannelsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen: (p, c) => p.salesChannels != c.salesChannels,
      builder: (context, state) {
        final channels = state.salesChannels;

        const posKey = 'pos';
        const fbKey = 'facebook_marketplace';
        final isPosActive = channels[posKey] ?? false;
        final isFbActive = channels[fbKey] ?? false;
        final activeCount = (isPosActive ? 1 : 0) + (isFbActive ? 1 : 0);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CANALES DE VENTA',
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color:
                          isDark
                              ? const Color(0xFFE2E8F0)
                              : const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          activeCount > 0
                              ? const Color(0xFF0066FF).withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      activeCount == 0
                          ? 'Inactivo'
                          : (activeCount == 1
                              ? '1 activo'
                              : '$activeCount activos'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color:
                            activeCount > 0
                                ? const Color(0xFF0066FF)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Canal 1: Punto de Venta
              _SalesChannelTile(
                title: 'Punto de Venta',
                activeSubtitle: 'Disponible en caja',
                inactiveSubtitle: 'No disponible en caja',
                icon: Icons.point_of_sale_rounded,
                isActive: isPosActive,
                isDark: isDark,
                accentColor: const Color(0xFF0066FF),
                onTap: () => cubit.toggleSalesChannel(posKey),
              ),

              const SizedBox(height: 8),

              // Canal 2: Facebook Marketplace
              _SalesChannelTile(
                title: 'Facebook Marketplace',
                activeSubtitle: 'Habilitado para publicar con Capi',
                inactiveSubtitle: 'No publicar en Marketplace',
                icon: Icons.storefront_rounded,
                isActive: isFbActive,
                isDark: isDark,
                accentColor: const Color(0xFF1877F2),
                onTap: () => cubit.toggleSalesChannel(fbKey),
              ),

              const SizedBox(height: 12),

              // Nota informativa
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color:
                          isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Activa "Facebook Marketplace" para que Capi prepare y gestione su publicación.',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SalesChannelTile extends StatelessWidget {
  final String title;
  final String activeSubtitle;
  final String inactiveSubtitle;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final Color accentColor;
  final VoidCallback onTap;

  const _SalesChannelTile({
    required this.title,
    required this.activeSubtitle,
    required this.inactiveSubtitle,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color:
              isActive
                  ? accentColor.withValues(alpha: 0.05)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isActive
                    ? accentColor.withValues(alpha: 0.25)
                    : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive ? accentColor : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isActive ? accentColor : const Color(0xFFCBD5E1),
                  width: 1.8,
                ),
              ),
              child:
                  isActive
                      ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                      : null,
            ),
            const SizedBox(width: 12),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color:
                    isActive
                        ? accentColor.withValues(alpha: 0.1)
                        : (isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color:
                    isActive
                        ? accentColor
                        : (isDark
                            ? const Color(0xFF64748B)
                            : const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color:
                          isActive
                              ? (isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A))
                              : (isDark
                                  ? const Color(0xFF64748B)
                                  : const Color(0xFF94A3B8)),
                    ),
                  ),
                  Text(
                    isActive ? activeSubtitle : inactiveSubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isActive
                              ? accentColor.withValues(alpha: 0.8)
                              : const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color:
                    isActive
                        ? const Color(0xFF059669).withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isActive ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color:
                      isActive
                          ? const Color(0xFF059669)
                          : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
