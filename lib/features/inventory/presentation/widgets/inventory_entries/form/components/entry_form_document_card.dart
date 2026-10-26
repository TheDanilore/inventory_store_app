import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/components/entry_form_section_card.dart';

/// Tarjeta de datos del comprobante fiscal (Tipo, Serie/Número, Fecha) y notas.
class EntryFormDocumentCard extends StatelessWidget {
  final InventoryEntryFormState state;
  final InventoryEntryFormCubit cubit;
  final TextEditingController documentNumberCtrl;
  final TextEditingController notesCtrl;
  final VoidCallback onPickDate;

  static const Map<String, String> docTypes = {
    'NINGUNO': 'Ninguno',
    'FACTURA': 'Factura',
    'BOLETA': 'Boleta',
    'GUIA_REMISION': 'Guía de remisión',
    'TICKET': 'Ticket',
  };

  const EntryFormDocumentCard({
    super.key,
    required this.state,
    required this.cubit,
    required this.documentNumberCtrl,
    required this.notesCtrl,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    final hasDocument = state.documentType != 'NINGUNO';

    return EntryFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EntryFormSectionTitle(
            icon: Icons.receipt_long_rounded,
            title: 'Comprobante y notas',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey('doctype_${state.documentType}'),
            initialValue: state.documentType,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: entryFormDropdownDecoration(
              'Tipo de documento',
              icon: Icons.description_outlined,
            ),
            items:
                docTypes.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (v) {
              if (v == null) return;
              cubit.setDocumentType(v);
              if (v == 'NINGUNO') {
                documentNumberCtrl.clear();
                cubit.setDocumentNumber(null);
                cubit.setDocumentDate(null);
              }
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                hasDocument
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: TextFormField(
                        controller: documentNumberCtrl,
                        textCapitalization: TextCapitalization.characters,
                        decoration: entryFormDropdownDecoration(
                          'Número de documento (ej. F001-00012345)',
                          icon: Icons.tag_rounded,
                        ),
                        onChanged: cubit.setDocumentNumber,
                        validator: (val) {
                          if (hasDocument &&
                              (val == null || val.trim().isEmpty)) {
                            return 'Debe ingresar el número del documento';
                          }
                          return null;
                        },
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                hasDocument
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: EntryFormDatePickerField(
                        label: 'Fecha de emisión',
                        value: state.documentDate,
                        onPick: onPickDate,
                        onClear: () => cubit.setDocumentDate(null),
                        icon: Icons.edit_calendar_rounded,
                      ),
                    )
                    : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: notesCtrl,
            maxLines: 3,
            maxLength: 300,
            decoration: entryFormDropdownDecoration(
              'Notas adicionales (opcional)',
            ).copyWith(counterText: '', alignLabelWithHint: true),
          ),
        ],
      ),
    );
  }
}
