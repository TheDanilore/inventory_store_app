import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra flotante de acciones por lote estilo Linear / Stripe.
class ProductsFloatingBulkBar extends StatelessWidget {
  final int selectedCount;
  final bool isDesktop;
  final VoidCallback onExportPdf;
  final VoidCallback onClearSelection;

  const ProductsFloatingBulkBar({
    super.key,
    required this.selectedCount,
    required this.isDesktop,
    required this.onExportPdf,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: isDesktop ? 24 : 16,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 580),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$selectedCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                selectedCount == 1 ? 'seleccionado' : 'seleccionados',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 1,
                height: 20,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 10),

              // Exportar seleccionados a PDF
              TextButton.icon(
                onPressed: onExportPdf,
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                label: const Text(
                  'Exportar PDF',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Botón Deseleccionar todo
              IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white70,
                ),
                tooltip: 'Deseleccionar todos (Esc)',
                onPressed: onClearSelection,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
