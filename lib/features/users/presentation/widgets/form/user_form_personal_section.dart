import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_components.dart';

class UserFormPersonalSection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController docCtrl;
  final TextEditingController phoneCtrl;
  final String docType;
  final ValueChanged<String?> onDocTypeChanged;

  const UserFormPersonalSection({
    super.key,
    required this.nameCtrl,
    required this.docCtrl,
    required this.phoneCtrl,
    required this.docType,
    required this.onDocTypeChanged,
  });

  String? _required(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return 'Ingresa $fieldName';
    return null;
  }

  String? _validateDocument(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final clean = value.trim();
    if (docType == 'DNI') {
      if (clean.length != 8) return 'El DNI debe tener 8 dígitos';
    } else if (docType == 'RUC') {
      if (clean.length != 11) return 'El RUC debe tener 11 dígitos';
    } else if (clean.length < 4) {
      return 'Mínimo 4 caracteres';
    }
    return null;
  }

  int get _documentMaxLength =>
      docType == 'DNI' ? 8 : (docType == 'RUC' ? 11 : 15);

  List<TextInputFormatter> get _documentFormatters {
    if (docType == 'DNI' || docType == 'RUC') {
      return [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(_documentMaxLength),
      ];
    }
    return [
      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
      LengthLimitingTextInputFormatter(_documentMaxLength),
    ];
  }

  Widget _buildDocTypePicker() {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: docType,
              isDense: true,
              borderRadius: BorderRadius.circular(12),
              icon: Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: Colors.grey.shade600,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              items:
                  const ['DNI', 'RUC', 'CE', 'PAS']
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
              onChanged: onDocTypeChanged,
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 22, color: Colors.grey.shade300),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return UserFormSectionCard(
      title: 'Datos personales',
      subtitle: 'Identificación y contacto del colaborador.',
      icon: Icons.badge_rounded,
      children: [
        UserFormCustomTextField(
          controller: nameCtrl,
          label: 'Nombre completo o razón social',
          required: true,
          hint: 'Ej. Juan Pérez',
          textCapitalization: TextCapitalization.words,
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: (v) => _required(v, 'el nombre'),
        ),
        const SizedBox(height: 18),
        UserFormTwoColumns(
          breakpoint: 480,
          gap: 16,
          left: UserFormCustomTextField(
            controller: docCtrl,
            label: 'Documento de identidad',
            optional: true,
            hint:
                docType == 'DNI'
                    ? '8 dígitos'
                    : docType == 'RUC'
                    ? '11 dígitos'
                    : 'N° de documento',
            prefix: _buildDocTypePicker(),
            keyboardType:
                (docType == 'DNI' || docType == 'RUC')
                    ? TextInputType.number
                    : TextInputType.text,
            inputFormatters: _documentFormatters,
            textInputAction: TextInputAction.next,
            validator: _validateDocument,
          ),
          right: UserFormCustomTextField(
            controller: phoneCtrl,
            label: 'Teléfono o WhatsApp',
            optional: true,
            hint: 'Ej. 987654321',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(15),
            ],
          ),
        ),
      ],
    );
  }
}
