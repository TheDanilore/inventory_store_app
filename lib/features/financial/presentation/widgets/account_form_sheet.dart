import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_side_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';

class AccountFormSheet extends StatefulWidget {
  final FinancialAccountEntity? account;
  final bool isSlideOver;

  const AccountFormSheet({
    super.key,
    this.account,
    this.isSlideOver = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    FinancialAccountEntity? account,
  }) {
    final cubit = context.read<FinancialAccountsCubit>();
    return AdaptiveSideSheet.show<bool>(
      context: context,
      desktopWidth: 460.0,
      builder: (dialogCtx, isSlideOver) => BlocProvider.value(
        value: cubit,
        child: AccountFormSheet(
          account: account,
          isSlideOver: isSlideOver,
        ),
      ),
    );
  }

  @override
  State<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<AccountFormSheet> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'CAJA';
  bool _isActive = true;
  bool _saving = false;

  static const _types = [
    {'type': 'CAJA', 'label': 'Caja Física', 'icon': Icons.point_of_sale_rounded},
    {'type': 'BANCO', 'label': 'Cuenta Bancaria', 'icon': Icons.account_balance_rounded},
    {'type': 'DIGITAL', 'label': 'Billetera Digital', 'icon': Icons.phone_android_rounded},
    {'type': 'OTRO', 'label': 'Otra', 'icon': Icons.savings_rounded},
  ];

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.account!.name;
      _type = widget.account!.type;
      _isActive = widget.account!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final balanceText = _balanceCtrl.text.trim().replaceAll(',', '.');
      final balance =
          balanceText.isNotEmpty ? double.tryParse(balanceText) ?? 0.0 : 0.0;

      await context.read<FinancialAccountsCubit>().saveAccount(
        name: _nameCtrl.text.trim(),
        type: _type,
        isActive: _isActive,
        initialBalance: balance,
        accountId: widget.account?.id,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              'Error al guardar cuenta: ${e.toString().replaceAll('Exception: ', '')}',
          type: SnackbarType.error,
        );
      }
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSlideOver) {
      return _buildSlideOverLayout();
    }
    return _buildBottomSheetLayout();
  }

  // ── Desktop / Tablet: Slide-over Right Side Sheet Layout ───────────────────
  Widget _buildSlideOverLayout() {
    return Column(
      children: [
        // Encabezado del Side Sheet con botón de cierre explícito y atajo [Esc]
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.tealDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Editar Cuenta' : 'Nueva Cuenta Financiera',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEditing
                          ? 'Modifica los parámetros de la cuenta'
                          : 'Registra una caja, banco o billetera digital',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar [Esc]',
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Cuerpo con scroll
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: _buildFormFields(),
            ),
          ),
        ),

        // Barra inferior fija con acciones primarias y secundarias
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _saving
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
                    _saving
                        ? 'Guardando...'
                        : (_isEditing ? 'Guardar Cambios' : 'Crear Cuenta'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mobile: Bottom Sheet Layout (Apple HIG) ───────────────────────────────
  Widget _buildBottomSheetLayout() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing ? 'Editar Cuenta' : 'Nueva Cuenta',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: _buildFormFields(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? 'Guardar Cambios' : 'Crear Cuenta',
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

  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Nombre de la cuenta *'),
        TextFormField(
          controller: _nameCtrl,
          decoration: _inputDeco('Ej: BCP Soles, Caja Chica, Yape Principal'),
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) return 'El nombre es obligatorio';
            if (trimmed.length < 2) return 'El nombre debe tener al menos 2 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 16),

        _fieldLabel('Tipo de cuenta *'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _types.map((item) {
            final itemType = item['type'] as String;
            final itemLabel = item['label'] as String;
            final itemIcon = item['icon'] as IconData;
            final selected = _type == itemType;

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => setState(() => _type = itemType),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.teal : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.teal : AppColors.border,
                      width: selected ? 1.5 : 1.0,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        itemIcon,
                        size: 16,
                        color: selected ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        itemLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        if (!_isEditing) ...[
          _fieldLabel('Balance inicial (S/)'),
          TextFormField(
            controller: _balanceCtrl,
            decoration: _inputDeco('0.00').copyWith(
              prefixIcon: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  'S/ ',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              final parsed = double.tryParse(v.trim().replaceAll(',', '.'));
              if (parsed == null) return 'Ingresa un número válido';
              if (parsed < 0) return 'El balance inicial no puede ser negativo';
              return null;
            },
          ),
          const SizedBox(height: 6),
          const Text(
            'Saldo con el que inicia la cuenta en el sistema. Puedes dejarlo en 0.00.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
        ],

        if (_isEditing) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado Operativo',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isActive
                            ? 'Cuenta habilitada para registrar cobros y pagos'
                            : 'Cuenta inactiva (no aparecerá en nuevos registros)',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  activeTrackColor: AppColors.teal,
                  activeThumbColor: Colors.white,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
      );

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: AppColors.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      );
}
