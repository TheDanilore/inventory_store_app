import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';

class AccountFormSheet extends StatefulWidget {
  final FinancialAccountEntity? account;
  final bool isSlideOver;

  const AccountFormSheet({super.key, this.account, this.isSlideOver = false});

  static Future<bool?> show(
    BuildContext context, {
    FinancialAccountEntity? account,
  }) {
    final cubit = context.read<FinancialAccountsCubit>();
    return AdaptiveDetailSheet.show<bool>(
      context,
      desktopWidth: 480.0,
      builder:
          (dialogCtx) => BlocProvider.value(
            value: cubit,
            child: AccountFormSheet(
              account: account,
              isSlideOver: AdaptiveDetailSheet.isSideSheet(dialogCtx),
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
  String _currencyCode = 'PEN';
  String _brandKey = 'auto';
  bool _isActive = true;
  bool _editBalance = false;
  bool _saving = false;

  static const _types = [
    {
      'type': 'CAJA',
      'label': 'Caja Física',
      'icon': Icons.point_of_sale_rounded,
    },
    {
      'type': 'BANCO',
      'label': 'Cuenta Bancaria',
      'icon': Icons.account_balance_rounded,
    },
    {
      'type': 'DIGITAL',
      'label': 'Billetera Digital',
      'icon': Icons.phone_android_rounded,
    },
    {'type': 'OTRO', 'label': 'Otra', 'icon': Icons.savings_rounded},
  ];

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final acc = widget.account!;
      _nameCtrl.text = acc.name;
      _type = acc.type;
      _isActive = acc.isActive;
      _currencyCode = acc.currencyCode;
      _balanceCtrl.text = acc.balance.toStringAsFixed(2);

      // Detectar si el nombre coincide con algún preset conocido
      final detected = FinancialBrandHelper.getBrand(
        name: acc.name,
        type: acc.type,
      );
      final match =
          FinancialBrandHelper.presets
              .where((p) => p.brandType == detected.brand)
              .firstOrNull;
      if (match != null) {
        _brandKey = match.key;
      }
    } else {
      // Valor por defecto inicial amigable ("por defecto salir algo")
      _nameCtrl.text = 'Caja Principal';
      _type = 'CAJA';
      _currencyCode = 'PEN';
      _brandKey = 'caja_principal';
      _balanceCtrl.text = '0.00';
    }

    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _balanceCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _onSelectPreset(FinancialBrandPreset preset) {
    setState(() {
      _brandKey = preset.key;
      _type = preset.type;
      // Si el nombre estaba vacío o coincidía con un preset previo, actualizarlo
      final isInitialOrEmpty =
          _nameCtrl.text.trim().isEmpty ||
          FinancialBrandHelper.presets.any(
            (p) => p.defaultName == _nameCtrl.text.trim(),
          );
      if (isInitialOrEmpty) {
        _nameCtrl.text = preset.defaultName;
      }
    });
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
        initialBalance: (!_isEditing || _editBalance) ? balance : null,
        accountId: widget.account?.id,
        currencyCode: _currencyCode,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: FriendlyErrorMessage.format(e),
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
        // Encabezado del Side Sheet
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
                      _isEditing
                          ? 'Editar Cuenta Financiera'
                          : 'Nueva Cuenta Financiera',
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
                          ? 'Modifica los parámetros y logo de la cuenta'
                          : 'Configura una caja, banco o billetera digital',
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
            child: Form(key: _formKey, child: _buildFormFields()),
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
                  icon:
                      _saving
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
            const AppSheetDragHandle(padding: EdgeInsets.only(bottom: 12)),
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
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: _buildFormFields())),
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
                child:
                    _saving
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
    final currSymbol = _currencyCode == 'USD' ? '\$ ' : 'S/ ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Tarjeta de Vista Previa en Tiempo Real (Live Preview) ─────────
        _buildLivePreviewCard(),
        const SizedBox(height: 20),

        // ── 2. Selector Visual de Entidad / Logotipo / Marca ─────────────────
        _fieldLabel('Entidad / Logotipo de la Cuenta'),
        _buildBrandPicker(),
        const SizedBox(height: 18),

        // ── 3. Nombre de la Cuenta ───────────────────────────────────────────
        _fieldLabel('Nombre de la cuenta *'),
        TextFormField(
          controller: _nameCtrl,
          decoration: _inputDeco('Ej: BCP Soles, Caja Chica, Yape Principal'),
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) return 'El nombre es obligatorio';
            if (trimmed.length < 2) {
              return 'El nombre debe tener al menos 2 caracteres';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // ── 4. Moneda de la Cuenta ───────────────────────────────────────────
        _fieldLabel('Moneda de la cuenta *'),
        Row(
          children: [
            Expanded(
              child: _currencyCard(
                code: 'PEN',
                symbol: 'S/',
                name: 'Soles peruanos',
                isSelected: _currencyCode == 'PEN',
                onTap: () => setState(() => _currencyCode = 'PEN'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _currencyCard(
                code: 'USD',
                symbol: '\$',
                name: 'Dólares americanos',
                isSelected: _currencyCode == 'USD',
                onTap: () => setState(() => _currencyCode = 'USD'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── 5. Tipo de Cuenta ────────────────────────────────────────────────
        _fieldLabel('Tipo de cuenta *'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              _types.map((item) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? AppColors.teal : AppColors.border,
                          width: selected ? 1.5 : 1.0,
                        ),
                        boxShadow:
                            selected
                                ? [
                                  BoxShadow(
                                    color: AppColors.teal.withValues(
                                      alpha: 0.2,
                                    ),
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
                            color:
                                selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            itemLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color:
                                  selected
                                      ? Colors.white
                                      : AppColors.textPrimary,
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

        // ── 6. Balance (Inicial o Ajuste) ────────────────────────────────────
        if (!_isEditing) ...[
          _fieldLabel('Balance inicial ($currSymbol)'),
          TextFormField(
            controller: _balanceCtrl,
            decoration: _inputDeco('0.00').copyWith(
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  currSymbol,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
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
            'Saldo inicial de apertura para la cuenta. Puedes dejarlo en 0.00.',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ajustar Balance Actual',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _editBalance
                                ? 'Puedes corregir directamente el saldo de la cuenta'
                                : 'Saldo actual registrado: $currSymbol${widget.account!.balance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _editBalance = !_editBalance;
                          if (!_editBalance) {
                            _balanceCtrl.text = widget.account!.balance
                                .toStringAsFixed(2);
                          }
                        });
                      },
                      icon: Icon(
                        _editBalance
                            ? Icons.close_rounded
                            : Icons.edit_note_rounded,
                        size: 16,
                      ),
                      label: Text(
                        _editBalance ? 'Cancelar ajuste' : 'Corregir saldo',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_editBalance) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _balanceCtrl,
                    decoration: _inputDeco('0.00').copyWith(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Text(
                          currSymbol,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 0,
                        minHeight: 0,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    validator: (v) {
                      if (!_editBalance) {
                        return null;
                      }
                      if (v == null || v.trim().isEmpty) {
                        return 'Ingresa un saldo';
                      }
                      final parsed = double.tryParse(
                        v.trim().replaceAll(',', '.'),
                      );
                      if (parsed == null) {
                        return 'Ingresa un número válido';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── 7. Estado Operativo (Activa / Inactiva) ───────────────────────────
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

  // ── Tarjeta de Vista Previa en Vivo ──────────────────────────────────────
  Widget _buildLivePreviewCard() {
    final name =
        _nameCtrl.text.trim().isEmpty
            ? 'Nombre de Cuenta'
            : _nameCtrl.text.trim();
    final brandInfo = FinancialBrandHelper.getBrand(
      name: name,
      type: _type,
      brandKey: _brandKey,
    );
    final currSymbol = _currencyCode == 'USD' ? '\$ ' : 'S/ ';
    final balanceVal =
        double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '.')) ??
        (_isEditing ? widget.account!.balance : 0.0);
    final currencyFmt = NumberFormat.currency(
      locale: _currencyCode == 'USD' ? 'en_US' : 'es_PE',
      symbol: currSymbol,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: brandInfo.primaryColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: brandInfo.primaryColor.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 14,
                color: brandInfo.primaryColor,
              ),
              const SizedBox(width: 6),
              Text(
                'VISTA PREVIA EN VIVO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: brandInfo.primaryColor,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      _isActive
                          ? const Color(0xFFE6FFFA)
                          : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isActive ? 'Activa' : 'Inactiva',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color:
                        _isActive
                            ? AppColors.tealDark
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          Row(
            children: [
              FinancialBrandHelper.buildBrandBadge(
                name: name,
                type: _type,
                brandKey: _brandKey,
                size: 42,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _type,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _currencyCode == 'USD'
                                    ? Colors.amber.shade50
                                    : AppColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _currencyCode,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  _currencyCode == 'USD'
                                      ? Colors.amber.shade900
                                      : AppColors.tealDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${brandInfo.label}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: brandInfo.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFmt.format(balanceVal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Saldo',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Selector Visual de Logotipo y Marca ──────────────────────────────────
  Widget _buildBrandPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Opción Automática
              _brandPresetChip(
                label: 'Auto (según nombre)',
                isSelected: _brandKey == 'auto',
                icon: Icons.auto_awesome_rounded,
                color: AppColors.textSecondary,
                onTap: () => setState(() => _brandKey = 'auto'),
              ),
              const SizedBox(width: 8),

              // Presets populares de Bancos y Billeteras
              ...FinancialBrandHelper.presets.map((p) {
                final isSelected = _brandKey == p.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => _onSelectPreset(p),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? p.primaryColor.withValues(alpha: 0.12)
                                : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? p.primaryColor : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FinancialBrandHelper.buildBrandBadge(
                            name: p.label,
                            type: p.type,
                            brandKey: p.key,
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            p.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                              color:
                                  isSelected
                                      ? p.primaryColor
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Elige la entidad para asignar el logo oficial automáticamente, o déjalo en automático.',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _brandPresetChip({
    required String label,
    required bool isSelected,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.teal.withValues(alpha: 0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.teal : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.tealDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
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

  Widget _currencyCard({
    required String code,
    required String symbol,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.teal.withValues(alpha: 0.08)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.teal : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                symbol.trim(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color:
                          isSelected
                              ? AppColors.tealDark
                              : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
