import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';

class QuickCreateCustomerDialog extends StatefulWidget {
  final String? initialQuery;

  const QuickCreateCustomerDialog({super.key, this.initialQuery});

  static Future<CustomerEntity?> show(
    BuildContext context, {
    String? initialQuery,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet<CustomerEntity>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: QuickCreateCustomerDialog(initialQuery: initialQuery),
            ),
          ),
        ),
      );
    }

    return showDialog<CustomerEntity>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
        ),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: QuickCreateCustomerDialog(initialQuery: initialQuery),
        ),
      ),
    );
  }

  @override
  State<QuickCreateCustomerDialog> createState() =>
      _QuickCreateCustomerDialogState();
}

class _QuickCreateCustomerDialogState extends State<QuickCreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _docNumberCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _docType = 'DNI';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _parseInitialQuery();
  }

  void _parseInitialQuery() {
    final query = widget.initialQuery?.trim() ?? '';
    if (query.isEmpty) return;

    final isNumeric = RegExp(r'^\d+$').hasMatch(query);
    if (isNumeric) {
      if (query.length == 11) {
        _docType = 'RUC';
        _docNumberCtrl.text = query;
      } else {
        _docType = 'DNI';
        _docNumberCtrl.text = query.length > 8 ? query.substring(0, 8) : query;
      }
    } else {
      _nameCtrl.text = query;
    }
  }

  @override
  void dispose() {
    _docNumberCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final createCustomerUC = sl<CreateCustomerUseCase>();
      final newCustomer = await createCustomerUC.call(
        fullName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        documentNumber: _docNumberCtrl.text.trim().isEmpty
            ? null
            : _docNumberCtrl.text.trim(),
        documentType: _docType,
      );

      if (mounted) {
        Navigator.pop(context, newCustomer);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          final err = e.toString().toLowerCase();
          if (err.contains('unique') || err.contains('duplicate') || err.contains('document_number')) {
            _errorMessage = 'Ya existe un cliente registrado con este documento.';
          } else {
            _errorMessage = 'No se pudo registrar el cliente. Intente nuevamente.';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isMobile) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            // Encabezado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: AppColors.teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nuevo Cliente en POS',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Alta exprés para ticket o comprobante',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  tooltip: 'Cerrar (Esc)',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Selector Tipo de Documento
            Text(
              'Tipo de Documento',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['DNI', 'RUC', 'CE', 'OTRO'].map((type) {
                final isSelected = _docType == type;
                return ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: AppColors.teal.withValues(alpha: 0.15),
                  backgroundColor: AppColors.background,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.teal : AppColors.textSecondary,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.teal
                        : Colors.grey.shade300,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _docType = type;
                        _docNumberCtrl.clear();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // N° de Documento
            AppTextField(
              controller: _docNumberCtrl,
              label: 'N° de Documento ($_docType)',
              hintText: _docType == 'DNI'
                  ? 'Ej: 45892134 (8 dígitos)'
                  : _docType == 'RUC'
                      ? 'Ej: 20601234567 (11 dígitos)'
                      : 'Número de documento',
              icon: Icons.badge_outlined,
              keyboardType: _docType == 'DNI' || _docType == 'RUC'
                  ? TextInputType.number
                  : TextInputType.text,
              inputFormatters: [
                if (_docType == 'DNI') ...[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ] else if (_docType == 'RUC') ...[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
              ],
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  final text = val.trim();
                  if (_docType == 'DNI' && text.length != 8) {
                    return 'El DNI debe tener exactamente 8 dígitos';
                  }
                  if (_docType == 'RUC' && text.length != 11) {
                    return 'El RUC debe tener exactamente 11 dígitos';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Nombre / Razón Social
            AppTextField(
              controller: _nameCtrl,
              label: _docType == 'RUC'
                  ? 'Razón Social / Empresa *'
                  : 'Nombre Completo del Cliente *',
              hintText: _docType == 'RUC'
                  ? 'Ej: Agroinsumos del Norte S.A.C.'
                  : 'Ej: Juan Carlos Pérez Ramos',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'El nombre o razón social es obligatorio';
                }
                if (val.trim().length < 2) {
                  return 'El nombre es muy corto';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Teléfono / WhatsApp
            AppTextField(
              controller: _phoneCtrl,
              label: 'Teléfono / WhatsApp (Opcional)',
              hintText: 'Ej: 987654321',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              validator: (val) {
                if (val != null && val.trim().isNotEmpty) {
                  if (val.trim().length < 6) {
                    return 'Ingresa un número telefónico válido';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Botones de Acción
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(
                    _isLoading ? 'Guardando…' : 'Guardar y Asignar',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
