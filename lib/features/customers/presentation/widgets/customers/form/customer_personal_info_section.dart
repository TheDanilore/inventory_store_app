import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_form_fields.dart';

/// Sección de información personal: Nombre, Teléfono, Tipo y Número de Documento
class CustomerPersonalInfoSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController docNumberCtrl;
  final String docType;
  final ValueChanged<String> onDocTypeChanged;

  const CustomerPersonalInfoSection({
    super.key,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.docNumberCtrl,
    required this.docType,
    required this.onDocTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomerSectionHeader(
          icon: Icons.person_rounded,
          title: 'Datos personales',
        ),
        const SizedBox(height: 12),

        const CustomerFieldLabel('Nombre completo *'),
        CustomerStyledField(
          controller: nameCtrl,
          hint: 'Ej: Juan Pérez López',
          prefixIcon: Icons.badge_rounded,
          textCapitalization: TextCapitalization.words,
          validator:
              (v) =>
                  (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
        ),
        const SizedBox(height: 14),

        const CustomerFieldLabel('Teléfono'),
        CustomerStyledField(
          controller: phoneCtrl,
          hint: 'Ej: 987654321',
          prefixIcon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(12),
          ],
        ),
        const SizedBox(height: 14),

        const CustomerFieldLabel('Documento de identidad'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de Tipo de documento
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: docType,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DNI', child: Text('DNI')),
                    DropdownMenuItem(value: 'RUC', child: Text('RUC')),
                    DropdownMenuItem(value: 'CE', child: Text('CE')),
                    DropdownMenuItem(
                      value: 'Pasaporte',
                      child: Text('Pasaporte', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) onDocTypeChanged(v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Campo de número de documento
            Expanded(
              child: CustomerStyledField(
                controller: docNumberCtrl,
                hint: 'Número de documento',
                prefixIcon: Icons.numbers_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(
                    docType == 'DNI'
                        ? 8
                        : docType == 'RUC'
                        ? 11
                        : 15,
                  ),
                ],
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  if (docType == 'DNI' && text.length != 8) {
                    return 'DNI debe tener 8 dígitos';
                  }
                  if (docType == 'RUC' && text.length != 11) {
                    return 'RUC debe tener 11 dígitos';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
