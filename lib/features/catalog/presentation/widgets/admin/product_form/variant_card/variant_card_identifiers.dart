import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

class VariantCardIdentifiers extends StatelessWidget {
  final TextEditingController skuCtrl;
  final TextEditingController barcodeCtrl;
  final TextEditingController reorderPointCtrl;
  final VoidCallback onFieldChanged;

  const VariantCardIdentifiers({
    super.key,
    required this.skuCtrl,
    required this.barcodeCtrl,
    required this.reorderPointCtrl,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila SKU + Código de Barras
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: 'SKU',
                controller: skuCtrl,
                icon: Icons.qr_code_2_rounded,
                hintText: 'Ej: PROD-001',
                validator: (val) {
                  if (val != null && val.isNotEmpty && val.trim().isEmpty) {
                    return 'SKU inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: 'Código de Barras (Opcional)',
                controller: barcodeCtrl,
                icon: Icons.barcode_reader,
                hintText: 'Ej: 7751234567890',
                suffixIcon: Tooltip(
                  message: 'Escanear código con cámara o pistola',
                  child: IconButton(
                    icon: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.teal,
                      size: 20,
                    ),
                    onPressed: () async {
                      final code = await PosCameraScannerDialog.showForRawCode(
                        context,
                        title: 'Escanear Código de Variante',
                      );
                      if (code != null && code.isNotEmpty) {
                        barcodeCtrl.text = code;
                        onFieldChanged();
                        AppFeedbackService.lightImpact();
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Punto de Reorden
        AppTextField(
          label: 'Punto de Reorden',
          controller: reorderPointCtrl,
          icon: Icons.warning_amber_rounded,
          keyboardType: TextInputType.number,
          hintText: 'Ej: 5',
          helperText: 'Alerta de stock bajo para esta variante',
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (val) {
            if (val != null && val.trim().isNotEmpty) {
              final n = int.tryParse(val.trim());
              if (n == null || n < 0) {
                return 'No negativo';
              }
            }
            return null;
          },
        ),
      ],
    );
  }
}
