import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_balance_row.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_entity_picker.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_preset_search_dialog.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_preview_card.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_status_toggle.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_type_selector.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/form/account_form_warehouse_selector.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/usecases/get_active_warehouses_usecase.dart';

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
  final _nameFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  String _type = 'CAJA';
  String _currencyCode = 'PEN';
  String _brandKey = 'auto';
  bool _isActive = true;
  bool _editBalance = false;
  bool _saving = false;
  bool _userEditedName = false;

  String? _selectedWarehouseId;
  List<WarehouseEntity> _warehouses = [];
  bool _isLoadingWarehouses = false;

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
      _selectedWarehouseId = acc.warehouseId;
      _userEditedName = true;

      final detected = FinancialBrandHelper.getBrand(
        name: acc.name,
        type: acc.type,
      );
      final match =
          FinancialBrandHelper.presets
              .where(
                (p) =>
                    p.brandType == detected.brand ||
                    p.defaultName.toLowerCase() ==
                        acc.name.toLowerCase().trim(),
              )
              .firstOrNull;
      _brandKey = match?.key ?? 'auto';
    } else {
      _nameCtrl.text = 'Caja Principal';
      _type = 'CAJA';
      _currencyCode = 'PEN';
      _brandKey = 'caja_principal';
      _balanceCtrl.text = '0.00';
      _userEditedName = false;
    }

    _loadWarehouses();

    _nameCtrl.addListener(() {
      if (!_isEditing) {
        _userEditedName = true;
      }
    });
  }

  String _getSelectedWarehouseName() {
    if (_selectedWarehouseId == null || _warehouses.isEmpty) return '';
    final w =
        _warehouses
            .where((e) => e.id == _selectedWarehouseId)
            .cast<WarehouseEntity?>()
            .firstOrNull;
    return w?.name ?? '';
  }

  void _applySuggestedCajaName({bool force = false}) {
    if (_isEditing) return;
    if (_type != 'CAJA') return;
    if (!force && _userEditedName) return;
    final wname = _getSelectedWarehouseName();
    if (wname.isEmpty) return;

    final suggested = 'Caja Principal - $wname';
    if (_nameCtrl.text.trim() == suggested) return;

    _nameCtrl.text = suggested;
    _brandKey = 'caja_principal';
    _userEditedName = false;
    if (mounted) setState(() {});
  }

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    try {
      final whs = await sl<GetActiveWarehousesUseCase>()();
      if (mounted) {
        setState(() {
          _warehouses = whs;
          _isLoadingWarehouses = false;
          if (_selectedWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first.id;
          }
        });
        _applySuggestedCajaName(force: true);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWarehouses = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onSelectPreset(FinancialBrandPreset preset) {
    setState(() {
      _brandKey = preset.key;
      _type = preset.type;
      _userEditedName = false;
      final lower = preset.defaultName.toLowerCase();
      if (preset.key.contains('usd') ||
          lower.contains('dólar') ||
          lower.contains('dolar')) {
        _currencyCode = 'USD';
      }
    });
    if (preset.type == 'CAJA') {
      if (preset.key == 'caja_chica') {
        setState(() {
          _brandKey = 'caja_principal';
        });
      }
      _applySuggestedCajaName(force: true);
    } else {
      _nameCtrl.text = preset.defaultName;
    }
  }

  void _onSelectCustom([String? name]) {
    setState(() {
      _brandKey = 'auto';
      if (name != null && name.trim().isNotEmpty) {
        _nameCtrl.text = name.trim();
        _userEditedName = true;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
      _nameCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _nameCtrl.text.length,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final balanceText = _balanceCtrl.text.trim().replaceAll(',', '.');
      final balance =
          balanceText.isNotEmpty ? double.tryParse(balanceText) ?? 0.0 : 0.0;

      String finalName = _nameCtrl.text.trim();
      if (!_isEditing && _type == 'CAJA') {
        final wname = _getSelectedWarehouseName();
        if (wname.isNotEmpty) {
          final lowerName = finalName.toLowerCase();
          final lowerW = wname.toLowerCase();
          if (!lowerName.contains(lowerW)) {
            if (lowerName == 'caja principal' ||
                lowerName == 'caja chica' ||
                lowerName == 'caja') {
              finalName = 'Caja Principal - $wname';
            } else {
              finalName = '$finalName - $wname';
            }
          } else if (lowerName.contains('chica')) {
            finalName = finalName.replaceFirst(
              RegExp(r'Caja\s+Chica', caseSensitive: false),
              'Caja Principal',
            );
          }
        }
      }

      await context.read<FinancialAccountsCubit>().saveAccount(
        name: finalName,
        type: _type,
        isActive: _isActive,
        initialBalance: (!_isEditing || _editBalance) ? balance : null,
        accountId: widget.account?.id,
        currencyCode: _currencyCode,
        warehouseId: _type == 'CAJA' ? _selectedWarehouseId : null,
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
        setState(() => _saving = false);
      }
    }
  }

  void _showPresetSearchModal() {
    AccountFormPresetSearchDialog.show(
      context,
      asDialog: widget.isSlideOver,
      selectedKey: _brandKey,
      onSelectPreset: _onSelectPreset,
      onSelectCustom: _onSelectCustom,
    );
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text.rich(
      TextSpan(
        text: text,
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: AppColors.danger),
            ),
        ],
      ),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: AppColors.txtPrimary(context),
      ),
    ),
  );

  Widget _buildFormFields() {
    final dark = AppColors.isDark(context);
    final field = dark ? AppColors.darkBackground : AppColors.surface;
    final line = AppColors.brdSubtle(context);
    final muted = AppColors.txtSecondary(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AccountFormPreviewCard(
          nameCtrl: _nameCtrl,
          balanceCtrl: _balanceCtrl,
          type: _type,
          brandKey: _brandKey,
          currencyCode: _currencyCode,
          isActive: _isActive,
          isEditing: _isEditing,
          fallbackBalance: widget.account?.balance ?? 0.0,
        ),
        const SizedBox(height: 24),

        // 1 · Entidad
        _label('Entidad'),
        AccountFormEntityPicker(
          brandKey: _brandKey,
          onSelectPreset: _onSelectPreset,
          onSelectCustom: _onSelectCustom,
          onShowAll: _showPresetSearchModal,
        ),
        const SizedBox(height: 16),

        // 2 · Nombre
        _label('Nombre de la cuenta', required: true),
        TextFormField(
          controller: _nameCtrl,
          focusNode: _nameFocus,
          decoration: InputDecoration(
            hintText: 'Ej: Caja Tienda Chimbote, BCP Dólares',
            hintStyle: TextStyle(
              fontSize: 13.5,
              color: AppColors.txtMuted(context),
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            filled: true,
            fillColor: field,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: line),
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
          ),
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          validator: (v) {
            final trimmed = v?.trim() ?? '';
            if (trimmed.isEmpty) return 'El nombre es obligatorio';
            if (trimmed.length < 2) return 'Debe tener al menos 2 caracteres';
            return null;
          },
        ),
        const SizedBox(height: 20),

        // 3 · Tipo de cuenta
        _label('Tipo de cuenta', required: true),
        AccountFormTypeSelector(
          selectedType: _type,
          onTypeChanged: (newType) {
            setState(() => _type = newType);
            if (newType == 'CAJA') {
              _applySuggestedCajaName(force: true);
            }
          },
        ),
        const SizedBox(height: 20),

        // 4 · Tienda (cajas) o aviso centralizado
        if (_type == 'CAJA') ...[
          _label('Tienda o sucursal', required: true),
          AccountFormWarehouseSelector(
            selectedWarehouseId: _selectedWarehouseId,
            warehouses: _warehouses,
            isLoading: _isLoadingWarehouses,
            onWarehouseChanged: (val) {
              if (val != null) {
                setState(() => _selectedWarehouseId = val);
                _applySuggestedCajaName();
              }
            },
          ),
        ] else
          Row(
            children: [
              Icon(
                Icons.hub_rounded,
                size: 16,
                color: dark ? const Color(0xFF2DD4BF) : AppColors.tealDark,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cuenta centralizada: disponible para cobrar en todas las tiendas.',
                  style: TextStyle(fontSize: 12.5, color: muted, height: 1.35),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),

        // 5 · Saldo + moneda
        _label(_isEditing ? 'Saldo actual' : 'Saldo inicial'),
        AccountFormBalanceRow(
          balanceCtrl: _balanceCtrl,
          isEditing: _isEditing,
          editBalance: _editBalance,
          currencyCode: _currencyCode,
          onToggleEditBalance: () {
            setState(() {
              _editBalance = !_editBalance;
              if (!_editBalance) {
                _balanceCtrl.text = widget.account!.balance.toStringAsFixed(2);
              }
            });
          },
          onCurrencyChanged: (c) => setState(() => _currencyCode = c),
        ),

        // 6 · Estado activo/inactivo (edición)
        if (_isEditing) ...[
          const SizedBox(height: 20),
          AccountFormStatusToggle(
            isActive: _isActive,
            onToggleActive: (v) => setState(() => _isActive = v),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _saveButton({required double height}) {
    return SizedBox(
      height: height,
      child: FilledButton.icon(
        onPressed: _saving ? null : _save,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isSlideOver
        ? _buildSlideOverLayout()
        : _buildBottomSheetLayout();
  }

  Widget _buildSlideOverLayout() {
    final surface = AppColors.surf(context);
    final title = AppColors.txtPrimary(context);
    final muted = AppColors.txtSecondary(context);
    final dark = AppColors.isDark(context);
    final tealText = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;
    final line = AppColors.brdSubtle(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: BoxDecoration(
            color: surface,
            border: Border(bottom: BorderSide(color: AppColors.brd(context))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: tealText,
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
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: title,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEditing
                          ? 'Modifica los datos de la cuenta'
                          : 'Configura una caja, banco o billetera digital',
                      style: TextStyle(fontSize: 12.5, color: muted),
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
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(key: _formKey, child: _buildFormFields()),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: surface,
            border: Border(top: BorderSide(color: AppColors.brd(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: title,
                    side: BorderSide(color: line),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _saveButton(height: 48)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheetLayout() {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final title = AppColors.txtPrimary(context);

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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: title,
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
            const SizedBox(height: 12),
            Flexible(child: SingleChildScrollView(child: _buildFormFields())),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: _saveButton(height: 50)),
          ],
        ),
      ),
    );
  }
}
