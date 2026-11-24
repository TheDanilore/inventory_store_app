import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/shortcut_utils.dart';
import 'package:inventory_store_app/core/widgets/adaptive_surface_card.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';
import 'package:inventory_store_app/core/widgets/hover_shortcut_tooltip.dart';

class ProfileEditFormSection extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController docNumCtrl;
  final String docType;
  final ValueChanged<String> onDocTypeChanged;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final bool isWideLayout;

  const ProfileEditFormSection({
    super.key,
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.docNumCtrl,
    required this.docType,
    required this.onDocTypeChanged,
    required this.onSave,
    this.onCancel,
    this.isWideLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final int maxDocLength = switch (docType) {
      'DNI' => 8,
      'RUC' => 11,
      _ => 15,
    };
    final isDark = AppColors.isDark(context);

    final docFields = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue:
                ['DNI', 'RUC', 'CE', 'PASAPORTE'].contains(docType)
                    ? docType
                    : 'DNI',
            dropdownColor: AppColors.surfElevated(context),
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.txtPrimary(context),
            ),
            iconEnabledColor: AppColors.txtSecondary(context),
            decoration: InputDecoration(
              labelText: 'Tipo Doc',
              prefixIcon: Icon(
                Icons.badge_outlined,
                color: AppColors.txtSecondary(context),
                size: 20,
              ),
              filled: true,
              fillColor: AppColors.inputFill(context),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.brdSubtle(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: AppColors.brdSubtle(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.brandPrimary(context),
                  width: 1.8,
                ),
              ),
            ),
            items:
                ['DNI', 'RUC', 'CE', 'PASAPORTE']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
            onChanged: (val) {
              if (val != null) {
                AppFeedbackService.selectionClick();
                onDocTypeChanged(val);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: AppTextField(
            controller: docNumCtrl,
            label: 'Nº Documento',
            icon: Icons.pin_outlined,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
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
    );

    final phoneField = AppTextField(
      controller: phoneCtrl,
      label: 'Teléfono',
      icon: Icons.phone_outlined,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
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
    );

    return AdaptiveSurfaceCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: nameCtrl,
              label: 'Nombre Completo',
              icon: Icons.person_outline_rounded,
              textCapitalization: TextCapitalization.words,
              validator: (val) {
                final text = (val ?? '').trim();
                if (text.isEmpty) return 'El nombre no puede estar vacío';
                if (text.length < 3) return 'Debe tener al menos 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 14),
            if (isWideLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: phoneField),
                  const SizedBox(width: 12),
                  Expanded(flex: 3, child: docFields),
                ],
              )
            else ...[
              phoneField,
              const SizedBox(height: 14),
              docFields,
            ],
            const SizedBox(height: 20),
            if (isWideLayout && onCancel != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  HoverShortcutTooltip(
                    message: 'Cancelar edición',
                    shortcut: 'Esc',
                    child: OutlinedButton(
                      onPressed: () {
                        AppFeedbackService.lightImpact();
                        onCancel!();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.txtSecondary(context),
                        side: BorderSide(color: AppColors.brdSubtle(context)),
                        minimumSize: const Size(110, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  HoverShortcutTooltip(
                    message: 'Guardar cambios',
                    shortcut: '${AppShortcutLabels.modPlus}S',
                    child: ElevatedButton.icon(
                      onPressed: () {
                        AppFeedbackService.mediumImpact();
                        onSave();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? AppColors.successDark : AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: const Size(176, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Guardar cambios',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AppFeedbackService.mediumImpact();
                    onSave();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDark ? AppColors.successDark : AppColors.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Guardar cambios',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
  final bool isWideLayout;

  const PasswordChangeCard({
    super.key,
    required this.newPasswordCtrl,
    required this.confirmPasswordCtrl,
    required this.isUpdating,
    required this.onSave,
    this.isWideLayout = false,
  });

  @override
  State<PasswordChangeCard> createState() => _PasswordChangeCardState();
}

class _PasswordChangeCardState extends State<PasswordChangeCard> {
  final _pwFormKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _strengthScore = 0;

  @override
  void initState() {
    super.initState();
    _updateStrength(widget.newPasswordCtrl.text);
  }

  void _updateStrength(String value) {
    int score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]').hasMatch(value)) score++;
    if (_strengthScore != score) {
      setState(() => _strengthScore = score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final newPassField = AppTextField(
      controller: widget.newPasswordCtrl,
      label: 'Nueva contraseña',
      icon: Icons.lock_outline_rounded,
      obscureText: _obscurePassword,
      onChanged: _updateStrength,
      suffixIcon: IconButton(
        tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
        icon: Icon(
          _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.txtSecondary(context),
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
      validator: (val) {
        final text = (val ?? '').trim();
        if (text.isEmpty) return 'Ingresa la nueva contraseña';
        if (text.length < 8) {
          return 'La contraseña debe tener mínimo 8 caracteres';
        }
        return null;
      },
    );

    final confirmPassField = AppTextField(
      controller: widget.confirmPasswordCtrl,
      label: 'Confirmar contraseña',
      icon: Icons.lock_reset_outlined,
      obscureText: _obscureConfirm,
      suffixIcon: IconButton(
        tooltip: _obscureConfirm ? 'Mostrar' : 'Ocultar',
        icon: Icon(
          _obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
          color: AppColors.txtSecondary(context),
          size: 20,
        ),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
      ),
      validator: (val) {
        final text = (val ?? '').trim();
        if (text.isEmpty) return 'Confirma la nueva contraseña';
        if (text != widget.newPasswordCtrl.text.trim()) {
          return 'Las contraseñas no coinciden';
        }
        return null;
      },
    );

    final strengthColor = switch (_strengthScore) {
      0 => AppColors.brdSubtle(context),
      1 => AppColors.dangerText(context),
      2 => AppColors.warningText(context),
      3 => AppColors.infoText(context),
      _ => AppColors.successText(context),
    };

    final strengthLabel = switch (_strengthScore) {
      0 => 'Mínimo 8 caracteres',
      1 => 'Débil — agrega mayúsculas y números',
      2 => 'Aceptable — puedes reforzarla con símbolos',
      3 => 'Segura',
      _ => 'Muy segura',
    };

    return AdaptiveSurfaceCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Form(
        key: _pwFormKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isWideLayout)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: newPassField),
                  const SizedBox(width: 12),
                  Expanded(child: confirmPassField),
                ],
              )
            else ...[
              newPassField,
              const SizedBox(height: 14),
              confirmPassField,
            ],
            const SizedBox(height: 12),
            Row(
              children: List.generate(4, (index) {
                final filled = index < _strengthScore;
                return Expanded(
                  child: AnimatedContainer(
                    duration:
                        disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    height: 4,
                    margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                    decoration: BoxDecoration(
                      color:
                          filled
                              ? strengthColor
                              : AppColors.surfHover(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 6),
            Text(
              strengthLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color:
                    _strengthScore == 0
                        ? AppColors.txtMuted(context)
                        : strengthColor,
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment:
                  widget.isWideLayout ? Alignment.centerRight : Alignment.center,
              child: SizedBox(
                width: widget.isWideLayout ? null : double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed:
                      widget.isUpdating
                          ? null
                          : () {
                            if (_pwFormKey.currentState!.validate()) {
                              AppFeedbackService.mediumImpact();
                              widget.onSave();
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(210, 50),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
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
