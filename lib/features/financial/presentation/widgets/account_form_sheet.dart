import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

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
  String _selectedPresetKey = 'caja_principal';
  bool _isCustomName = false;
  bool _isActive = true;
  bool _editBalance = false;
  bool _saving = false;

  String? _selectedWarehouseId;
  List<WarehouseEntity> _warehouses = [];
  bool _isLoadingWarehouses = false;

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
      _selectedWarehouseId = acc.warehouseId;

      // Detectar si el nombre coincide con algún preset conocido
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
      if (match != null) {
        _brandKey = match.key;
        _selectedPresetKey = match.key;
        _isCustomName = false;
      } else {
        _selectedPresetKey = 'custom';
        _isCustomName = true;
      }
    } else {
      // Valor por defecto inicial amigable ("por defecto salir algo")
      _nameCtrl.text = 'Caja Principal';
      _type = 'CAJA';
      _currencyCode = 'PEN';
      _brandKey = 'caja_principal';
      _selectedPresetKey = 'caja_principal';
      _isCustomName = false;
      _balanceCtrl.text = '0.00';
    }

    _loadWarehouses();

    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
    _balanceCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    try {
      final whs = await sl<WarehousesRepository>().getActiveWarehouses();
      if (mounted) {
        setState(() {
          _warehouses = whs;
          _isLoadingWarehouses = false;
          // Si no hay almacén asignado aún y es caja física, asignar el primer almacén disponible
          if (_selectedWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first.id;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingWarehouses = false);
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  void _onSelectPreset(FinancialBrandPreset preset) {
    setState(() {
      _selectedPresetKey = preset.key;
      _brandKey = preset.key;
      _type = preset.type;
      _nameCtrl.text = preset.defaultName;
      _isCustomName = false;
      if (preset.key.contains('usd') ||
          preset.defaultName.toLowerCase().contains('dólar') ||
          preset.defaultName.toLowerCase().contains('dolar')) {
        _currencyCode = 'USD';
      }
    });
  }

  void _onSelectCustom() {
    setState(() {
      _selectedPresetKey = 'custom';
      _isCustomName = true;
      _brandKey = 'auto';
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

        // ── 2. Selector Desplegable / Buscador de Nombre de Cuenta ───────────
        _buildAccountNameSelector(),
        const SizedBox(height: 18),

        // ── 3. Selector Visual de Entidad / Logotipo / Marca (Opcional) ─────────
        _fieldLabel('Logotipo de la Cuenta (Opcional)'),
        _buildBrandPicker(),
        const SizedBox(height: 18),

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

        // ── 5.1 Asignación de Tienda / Sucursal ───────────────────────────────
        if (_type == 'CAJA') ...[
          _fieldLabel('Tienda o Sucursal física *'),
          if (_isLoadingWarehouses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else if (_warehouses.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No hay almacenes o tiendas activas registradas.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue:
                  _selectedWarehouseId != null &&
                          _warehouses.any((w) => w.id == _selectedWarehouseId)
                      ? _selectedWarehouseId
                      : (_warehouses.isNotEmpty ? _warehouses.first.id : null),
              isExpanded: true,
              decoration: _inputDeco('Selecciona la tienda').copyWith(
                prefixIcon: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              items:
                  _warehouses.map((w) {
                    return DropdownMenuItem<String>(
                      value: w.id,
                      child: Text(
                        w.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedWarehouseId = val);
                }
              },
            ),
          const SizedBox(height: 6),
          const Text(
            'Cada sucursal maneja su propio cajón de dinero físico para aperturas, cierres y turnos.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.hub_rounded,
                  size: 20,
                  color: AppColors.tealDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cuenta Digital / Centralizada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Esta cuenta está disponible para cobrar y recibir transferencias en todas las tiendas y vendedores.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blueGrey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

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

  // ── Selector de Nombre / Entidad con Buscador y Desplegable ───────────────
  Widget _buildAccountNameSelector() {
    final currentName = _nameCtrl.text.trim();
    final displayName =
        currentName.isEmpty ? 'Seleccionar entidad o nombre...' : currentName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Nombre / Entidad Financiera *'),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showPresetSearchModal(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isCustomName ? AppColors.teal : AppColors.border,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  FinancialBrandHelper.buildBrandBadge(
                    name: currentName,
                    type: _type,
                    brandKey: _brandKey,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color:
                                currentName.isEmpty
                                    ? AppColors.textSecondary
                                    : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _isCustomName
                              ? 'Nombre personalizado (Toca para buscar predefinidos)'
                              : 'Entidad predefinida (Toca para cambiar)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.unfold_more_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Chips de acceso rápido horizontal
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _quickPresetChip('Caja Principal', 'caja_principal'),
              const SizedBox(width: 6),
              _quickPresetChip('Yape', 'yape'),
              const SizedBox(width: 6),
              _quickPresetChip('Plin', 'plin'),
              const SizedBox(width: 6),
              _quickPresetChip('BCP Soles', 'bcp'),
              const SizedBox(width: 6),
              _quickPresetChip('BBVA', 'bbva'),
              const SizedBox(width: 6),
              _quickPresetChip('Interbank', 'interbank'),
              const SizedBox(width: 6),
              _quickOtherChip(),
            ],
          ),
        ),

        // Campo de texto visible si eligió "Otro" o si desea personalizar el nombre
        if (_isCustomName) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameCtrl,
            decoration: _inputDeco(
              'Ej: Caja Tienda Chimbote, BCP Dólares, Yape Cobros',
            ).copyWith(
              prefixIcon: const Icon(
                Icons.edit_note_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              helperText:
                  'Escribe el nombre con el que identificarás esta cuenta.',
            ),
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
          if (_type == 'CAJA') ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _cajaSuggestionChip('Caja Principal'),
                _cajaSuggestionChip('Caja Chica'),
                _cajaSuggestionChip('Caja Tienda 1'),
                _cajaSuggestionChip('Caja Tienda 2'),
                _cajaSuggestionChip('Caja Almacén Central'),
              ],
            ),
          ],
        ] else ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _onSelectCustom,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text(
                'Personalizar nombre de cuenta',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _quickPresetChip(String label, String presetKey) {
    final isSelected = !_isCustomName && _selectedPresetKey == presetKey;
    final preset = FinancialBrandHelper.presets.firstWhere(
      (p) => p.key == presetKey,
      orElse: () => FinancialBrandHelper.presets.first,
    );

    return InkWell(
      onTap: () => _onSelectPreset(preset),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.teal.withValues(alpha: 0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FinancialBrandHelper.buildBrandBadge(
              name: preset.label,
              type: preset.type,
              brandKey: preset.key,
              size: 16,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.tealDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickOtherChip() {
    final isSelected = _isCustomName;
    return InkWell(
      onTap: _onSelectCustom,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.teal.withValues(alpha: 0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              size: 14,
              color: isSelected ? AppColors.tealDark : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Otro...',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? AppColors.tealDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cajaSuggestionChip(String name) {
    return InkWell(
      onTap: () {
        setState(() {
          _nameCtrl.text = name;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          name,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  void _showPresetSearchModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _PresetSearchSheet(
          selectedKey: _isCustomName ? 'custom' : _selectedPresetKey,
          onSelectPreset: (preset) {
            Navigator.pop(sheetCtx);
            _onSelectPreset(preset);
          },
          onSelectCustom: () {
            Navigator.pop(sheetCtx);
            _onSelectCustom();
          },
        );
      },
    );
  }
}

// ── Modal Desplegable con Buscador de Entidades y Cuentas ───────────────────
class _PresetSearchSheet extends StatefulWidget {
  final String selectedKey;
  final ValueChanged<FinancialBrandPreset> onSelectPreset;
  final VoidCallback onSelectCustom;

  const _PresetSearchSheet({
    required this.selectedKey,
    required this.onSelectPreset,
    required this.onSelectCustom,
  });

  @override
  State<_PresetSearchSheet> createState() => _PresetSearchSheetState();
}

class _PresetSearchSheetState extends State<_PresetSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presets =
        FinancialBrandHelper.presets.where((p) {
          if (_query.isEmpty) return true;
          return p.label.toLowerCase().contains(_query) ||
              p.defaultName.toLowerCase().contains(_query) ||
              p.type.toLowerCase().contains(_query);
        }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppSheetDragHandle(
            padding: EdgeInsets.only(top: 10, bottom: 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seleccionar Entidad Financiera',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar banco, billetera o caja...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                suffixIcon:
                    _query.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                        : null,
                isDense: true,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.teal,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                // Opción especial: "Otro (Personalizado)"
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.tealDark,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    '✨ Otra cuenta / Nombre personalizado',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Si tu entidad o caja no está en la lista, ingrésala manualmente',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing:
                      widget.selectedKey == 'custom'
                          ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.teal,
                            size: 20,
                          )
                          : const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  onTap: widget.onSelectCustom,
                ),
                const Divider(height: 8, indent: 56),

                // Lista de presets filtrados
                ...presets.map((p) {
                  final isSelected = widget.selectedKey == p.key;
                  String typeLabel = 'Cuenta Bancaria';
                  if (p.type == 'CAJA') typeLabel = 'Caja Física';
                  if (p.type == 'DIGITAL') typeLabel = 'Billetera Digital';

                  return ListTile(
                    leading: FinancialBrandHelper.buildBrandBadge(
                      name: p.label,
                      type: p.type,
                      brandKey: p.key,
                      size: 36,
                    ),
                    title: Text(
                      p.label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isSelected ? p.primaryColor : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '$typeLabel • ${p.defaultName}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    trailing:
                        isSelected
                            ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.teal,
                              size: 20,
                            )
                            : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => widget.onSelectPreset(p),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
