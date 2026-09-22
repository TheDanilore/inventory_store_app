import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

class ProfileEditFormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController docNumCtrl;
  final String docType;
  final ValueChanged<String> onDocTypeChanged;
  final VoidCallback onSave;

  const ProfileEditFormSection({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.docNumCtrl,
    required this.docType,
    required this.onDocTypeChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final int maxDocLength = switch (docType) {
      'DNI' => 8,
      'RUC' => 11,
      _ => 15,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          children: [
            AppTextField(
              controller: nameCtrl,
              label: 'Nombre Completo',
              icon: Icons.person_outline_rounded,
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isEmpty) return 'El nombre no puede estar vacío';
                if (text.length < 3) return 'Debe tener al menos 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: phoneCtrl,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                LengthLimitingTextInputFormatter(15),
              ],
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isNotEmpty && text.length < 6) {
                  return 'Número de teléfono no válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 1,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue:
                        ['DNI', 'RUC', 'CE', 'PASAPORTE'].contains(docType)
                            ? docType
                            : 'DNI',
                    decoration: const InputDecoration(
                      labelText: 'Tipo Doc',
                      prefixIcon: Icon(Icons.badge_outlined),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                    ),
                    items:
                        ['DNI', 'RUC', 'CE', 'PASAPORTE']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) onDocTypeChanged(val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    controller: docNumCtrl,
                    label: 'Nº Documento',
                    icon: Icons.pin_outlined,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(maxDocLength),
                    ],
                    validator: (val) {
                      final text = (val ?? '').trim();
                      if (text.isNotEmpty) {
                        if (docType == 'DNI' && text.length != 8) {
                          return 'El DNI debe tener 8 dígitos';
                        }
                        if (docType == 'RUC' && text.length != 11) {
                          return 'El RUC debe tener 11 dígitos';
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text(
                  'Guardar cambios',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordChangeCard extends StatefulWidget {
  final TextEditingController newPasswordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool isUpdating;
  final VoidCallback onSave;

  const PasswordChangeCard({
    super.key,
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.isUpdating,
    required this.onSave,
  });

  @override
  State<PasswordChangeCard> createState() => _PasswordChangeCardState();
}

class _PasswordChangeCardState extends State<PasswordChangeCard> {
  final _pwFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _pwFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: widget.newPasswordCtrl,
              obscureText: _obscurePassword,
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isEmpty) return 'Ingresa la nueva contraseña';
                if (text.length < 8) {
                  return 'La contraseña debe tener mínimo 8 caracteres';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: widget.confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isEmpty) return 'Confirma la nueva contraseña';
                if (text != widget.newPasswordCtrl.text.trim()) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed:
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    widget.isUpdating
                        ? null
                        : () {
                          if (_pwFormKey.currentState!.validate()) {
                            widget.onSave();
                          }
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon:
                    widget.isUpdating
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  widget.isUpdating
                      ? 'Actualizando...'
                      : 'Actualizar contraseña',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
