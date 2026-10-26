import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'po_form_section_widgets.dart';

class POFormDocumentSection extends StatelessWidget {
  final String documentType;
  final TextEditingController documentNumberCtrl;
  final DateTime? documentDate;
  final TextEditingController notesCtrl;
  final ValueChanged<String> onDocumentTypeChanged;
  final VoidCallback onPickDocumentDate;
  final VoidCallback onClearDocumentDate;

  static const List<String> docTypes = [
    'NINGUNO',
    'FACTURA',
    'BOLETA',
    'GUIA_REMISION',
    'TICKET',
  ];

  const POFormDocumentSection({
    super.key,
    required this.documentType,
    required this.documentNumberCtrl,
    required this.documentDate,
    required this.notesCtrl,
    required this.onDocumentTypeChanged,
    required this.onPickDocumentDate,
    required this.onClearDocumentDate,
  });

  @override
  Widget build(BuildContext context) {
    return POFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const POFormSectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Documento (Opcional)',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('doc_$documentType'),
                  initialValue: documentType,
                  isExpanded: true,
                  icon: const Icon(Icons.expand_more_rounded),
                  decoration: poFormDropdownDecoration('Tipo Doc.'),
                  items:
                      docTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(
                                type,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (v) {
                    if (v != null) onDocumentTypeChanged(v);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: documentNumberCtrl,
                  maxLength: 50,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\-\.\/\s]'),
                    ),
                  ],
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: InputDecoration(
                    labelText: 'Número / Serie',
                    counterText: '',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  validator: (v) {
                    if (v != null && v.trim().length > 50) {
                      return 'Máximo 50 caracteres';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          POFormDatePickerField(
            label: 'Fecha Emisión Físico',
            value: documentDate,
            onPick: onPickDocumentDate,
            onClear: onClearDocumentDate,
            icon: Icons.edit_calendar_rounded,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notesCtrl,
            maxLines: 3,
            maxLength: 500,
            keyboardType: TextInputType.multiline,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              labelText: 'Notas adicionales',
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            validator: (v) {
              if (v != null && v.trim().length > 500) {
                return 'Máximo 500 caracteres';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}
