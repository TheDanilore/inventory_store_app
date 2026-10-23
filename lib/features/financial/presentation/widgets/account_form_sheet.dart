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

/// Formulario de Cuenta Financiera (crear / editar).
///
/// Cambios de UX respecto a la versión anterior:
///  • La "entidad" (Yape, BCP, Caja…) se elige en UN solo lugar. Antes existían
///    cuatro controles para lo mismo: selector desplegable, chips rápidos,
///    selector de logotipo y link "Personalizar nombre".
///  • El logo ya no es un paso aparte: lo define la entidad elegida
///    ("Otro" = automático según el nombre).
///  • El campo de nombre siempre es visible y editable.
///  • Moneda y saldo comparten fila; en edición el saldo se muestra en el
///    mismo campo con acción "Corregir" (antes era una tarjeta aparte).
///  • Textos de ayuda duplicados eliminados; vista previa más compacta.
///  • Modo oscuro soportado (antes todo estaba fijo en colores claros).
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

  /// Clave del preset elegido. 'auto' = "Otro": el logo se deduce del nombre.
  String _brandKey = 'auto';
  bool _isActive = true;
  bool _editBalance = false;
  bool _saving = false;

  String? _selectedWarehouseId;
  List<WarehouseEntity> _warehouses = [];
  bool _isLoadingWarehouses = false;

  /// Entidades más usadas, en orden fijo. Si alguna clave no existe en los
  /// presets se ignora; si ninguna existe se usan los primeros presets.
  static const _quickKeys = [
    'caja_principal',
    'yape',
    'plin',
    'bcp',
    'bbva',
    'interbank',
  ];
  static const int _fallbackVisible = 5;

  static const _types = [
    ('CAJA', 'Caja', Icons.point_of_sale_rounded),
    ('BANCO', 'Banco', Icons.account_balance_rounded),
    ('DIGITAL', 'Billetera', Icons.phone_android_rounded),
    ('OTRO', 'Otro', Icons.savings_rounded),
  ];

  bool get _isEditing => widget.account != null;
  String get _symbol => _currencyCode == 'USD' ? '\$ ' : 'S/ ';

  // ── Colores adaptativos (claro / oscuro) ────────────────────────────────
  bool get _dark => AppColors.isDark(context);
  Color get _surface => AppColors.surf(context);
  Color get _line => AppColors.brdSubtle(context);
  Color get _title => AppColors.txtPrimary(context);
  Color get _muted => AppColors.txtSecondary(context);
  Color get _hint => AppColors.txtMuted(context);
  Color get _field => _dark ? AppColors.darkBackground : AppColors.surface;
  Color get _soft =>
      _dark ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;
  Color get _tealText => _dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;

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

      // Detectar si la cuenta corresponde a alguna entidad conocida
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
          if (_selectedWarehouseId == null && _warehouses.isNotEmpty) {
            _selectedWarehouseId = _warehouses.first.id;
          }
        });
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

  // ── Acciones ──────────────────────────────────────────────────────────────
  void _onSelectPreset(FinancialBrandPreset preset) {
    setState(() {
      _brandKey = preset.key;
      _type = preset.type;
      _nameCtrl.text = preset.defaultName;
      final lower = preset.defaultName.toLowerCase();
      if (preset.key.contains('usd') ||
          lower.contains('dólar') ||
          lower.contains('dolar')) {
        _currencyCode = 'USD';
      }
    });
  }

  /// "Otro": logo automático según el nombre. Si viene [name] (desde el
  /// buscador) se usa como nombre; si no, se enfoca el campo para escribir.
  void _onSelectCustom([String? name]) {
    setState(() {
      _brandKey = 'auto';
      if (name != null && name.trim().isNotEmpty) _nameCtrl.text = name.trim();
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
        setState(() => _saving = false);
      }
    }
  }

  void _showPresetSearchModal() {
    // Desktop / tablet (slide-over): diálogo centrado.
    // Móvil: bottom sheet.
    if (widget.isSlideOver) {
      showDialog(
        context: context,
        builder:
            (dialogCtx) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: _PresetSearchSheet(
                  asDialog: true,
                  selectedKey: _brandKey,
                  onSelectPreset: (preset) {
                    Navigator.pop(dialogCtx);
                    _onSelectPreset(preset);
                  },
                  onSelectCustom: (name) {
                    Navigator.pop(dialogCtx);
                    _onSelectCustom(name);
                  },
                ),
              ),
            ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return _PresetSearchSheet(
          selectedKey: _brandKey,
          onSelectPreset: (preset) {
            Navigator.pop(sheetCtx);
            _onSelectPreset(preset);
          },
          onSelectCustom: (name) {
            Navigator.pop(sheetCtx);
            _onSelectCustom(name);
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LAYOUTS
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return widget.isSlideOver
        ? _buildSlideOverLayout()
        : _buildBottomSheetLayout();
  }

  // ── Desktop / Tablet: Slide-over ──────────────────────────────────────────
  Widget _buildSlideOverLayout() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          decoration: BoxDecoration(
            color: _surface,
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
                  color: _tealText,
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
                        color: _title,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isEditing
                          ? 'Modifica los datos de la cuenta'
                          : 'Configura una caja, banco o billetera digital',
                      style: TextStyle(fontSize: 12.5, color: _muted),
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
            color: _surface,
            border: Border(top: BorderSide(color: AppColors.brd(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _title,
                    side: BorderSide(color: _line),
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

  // ── Mobile: Bottom Sheet ──────────────────────────────────────────────────
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
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: _title,
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

  // ═══════════════════════════════════════════════════════════════════════════
  // CAMPOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPreviewCard(),
        const SizedBox(height: 24),

        // 1 · Entidad (único lugar para elegir banco / billetera / caja + logo)
        _label('Entidad'),
        _buildEntityPicker(),
        const SizedBox(height: 16),

        // 2 · Nombre (siempre visible y editable)
        _label('Nombre de la cuenta', required: true),
        _buildNameField(),
        const SizedBox(height: 20),

        // 3 · Tipo
        _label('Tipo de cuenta', required: true),
        _buildTypeSelector(),
        const SizedBox(height: 20),

        // 4 · Tienda (solo cajas físicas) o aviso de cuenta centralizada
        if (_type == 'CAJA') ...[
          _label('Tienda o sucursal', required: true),
          _buildWarehouseField(),
        ] else
          _buildCentralizedNote(),
        const SizedBox(height: 20),

        // 5 · Saldo + moneda en la misma fila
        _label(_isEditing ? 'Saldo actual' : 'Saldo inicial'),
        _buildBalanceRow(),

        // 6 · Estado (solo edición)
        if (_isEditing) ...[const SizedBox(height: 20), _buildActiveToggle()],
        const SizedBox(height: 8),
      ],
    );
  }

  // ── Vista previa compacta ─────────────────────────────────────────────────
  Widget _buildPreviewCard() {
    final name =
        _nameCtrl.text.trim().isEmpty
            ? 'Nombre de cuenta'
            : _nameCtrl.text.trim();
    final brand = FinancialBrandHelper.getBrand(
      name: name,
      type: _type,
      brandKey: _brandKey,
    );
    final accent = brand.primaryColor;
    final balanceVal =
        double.tryParse(_balanceCtrl.text.trim().replaceAll(',', '.')) ??
        (_isEditing ? widget.account!.balance : 0.0);
    final balanceText =
        '$_symbol${NumberFormat('#,##0.00', 'en_US').format(balanceVal)}';
    final isUsd = _currencyCode == 'USD';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow:
            _dark
                ? null
                : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.08),
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
              Icon(Icons.visibility_outlined, size: 13, color: accent),
              const SizedBox(width: 6),
              Text(
                'VISTA PREVIA',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!_isActive) _miniChip('Inactiva', _muted, _soft),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FinancialBrandHelper.buildBrandBadge(
                name: name,
                type: _type,
                brandKey: _brandKey,
                size: 44,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: _title,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _miniChip(_typeLabel(_type), _muted, _soft),
                        _miniChip(
                          _currencyCode,
                          isUsd ? const Color(0xFFB45309) : _tealText,
                          isUsd
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : AppColors.teal.withValues(alpha: 0.12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                balanceText,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: _title,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    for (final t in _types) {
      if (t.$1 == type) return t.$2;
    }
    return type;
  }

  Widget _miniChip(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ── Selector de entidad (chips + "Otro" + "Ver todas") ────────────────────
  Widget _buildEntityPicker() {
    final all = FinancialBrandHelper.presets;
    var visible = <FinancialBrandPreset>[
      for (final k in _quickKeys) ...all.where((p) => p.key == k),
    ];
    if (visible.isEmpty) visible = all.take(_fallbackVisible).toList();

    // Si la entidad elegida no está entre las rápidas, se agrega al final
    // (el resto conserva su posición y nada "salta" al seleccionar).
    final selected = all.where((p) => p.key == _brandKey).firstOrNull;
    if (selected != null && visible.every((p) => p.key != selected.key)) {
      visible = [...visible, selected];
    }
    final hidden = all.length - visible.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in visible)
          _entityChip(
            selected: _brandKey == p.key,
            color: p.primaryColor,
            leading: FinancialBrandHelper.buildBrandBadge(
              name: p.label,
              type: p.type,
              brandKey: p.key,
              size: 22,
            ),
            label: p.label,
            onTap: () => _onSelectPreset(p),
          ),
        _entityChip(
          selected: _brandKey == 'auto',
          color: AppColors.teal,
          leading: Icon(
            Icons.edit_note_rounded,
            size: 20,
            color: _brandKey == 'auto' ? _tealText : _muted,
          ),
          label: 'Otro',
          onTap: _onSelectCustom,
        ),
        if (hidden > 0)
          _entityChip(
            selected: false,
            color: AppColors.teal,
            leading: Icon(Icons.search_rounded, size: 18, color: _muted),
            label: 'Ver todas',
            trailing: '+$hidden',
            onTap: _showPresetSearchModal,
          ),
      ],
    );
  }

  Widget _entityChip({
    required bool selected,
    required Color color,
    required Widget leading,
    required String label,
    required VoidCallback onTap,
    String? trailing,
  }) {
    final fg =
        selected
            ? (_dark ? Color.lerp(color, Colors.white, 0.4)! : color)
            : _title;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : _field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : _line,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 5),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      focusNode: _nameFocus,
      decoration: _inputDeco('Ej: Caja Tienda Chimbote, BCP Dólares'),
      textCapitalization: TextCapitalization.words,
      maxLength: 50,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      validator: (v) {
        final trimmed = v?.trim() ?? '';
        if (trimmed.isEmpty) return 'El nombre es obligatorio';
        if (trimmed.length < 2) return 'Debe tener al menos 2 caracteres';
        return null;
      },
    );
  }

  // ── Tipo de cuenta: 4 tiles con icono ─────────────────────────────────────
  Widget _buildTypeSelector() {
    return Row(
      children: [
        for (var i = 0; i < _types.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _typeTile(_types[i])),
        ],
      ],
    );
  }

  Widget _typeTile((String, String, IconData) item) {
    final selected = _type == item.$1;
    return InkWell(
      onTap: () => setState(() => _type = item.$1),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.10) : _field,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.teal : _line,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(item.$3, size: 20, color: selected ? _tealText : _muted),
            const SizedBox(height: 5),
            Text(
              item.$2,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? _tealText : _title,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tienda ────────────────────────────────────────────────────────────────
  Widget _buildWarehouseField() {
    if (_isLoadingWarehouses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }
    if (_warehouses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay tiendas activas registradas. Crea una antes de agregar una caja física.',
                style: TextStyle(fontSize: 12.5, color: _title),
              ),
            ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue:
          _selectedWarehouseId != null &&
                  _warehouses.any((w) => w.id == _selectedWarehouseId)
              ? _selectedWarehouseId
              : _warehouses.first.id,
      isExpanded: true,
      decoration: _inputDeco('Selecciona la tienda').copyWith(
        prefixIcon: const Icon(
          Icons.storefront_rounded,
          color: AppColors.teal,
          size: 20,
        ),
        helperText: 'Cada tienda maneja su propio cajón y turnos.',
        helperStyle: TextStyle(fontSize: 11.5, color: _muted),
      ),
      items: [
        for (final w in _warehouses)
          DropdownMenuItem<String>(
            value: w.id,
            child: Text(
              w.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
      onChanged: (val) {
        if (val != null) setState(() => _selectedWarehouseId = val);
      },
    );
  }

  Widget _buildCentralizedNote() {
    return Row(
      children: [
        Icon(Icons.hub_rounded, size: 16, color: _tealText),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Cuenta centralizada: disponible para cobrar en todas las tiendas.',
            style: TextStyle(fontSize: 12.5, color: _muted, height: 1.35),
          ),
        ),
      ],
    );
  }

  // ── Saldo + moneda ────────────────────────────────────────────────────────
  Widget _buildBalanceRow() {
    final locked = _isEditing && !_editBalance;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _balanceCtrl,
            readOnly: locked,
            decoration: _inputDeco('0.00').copyWith(
              fillColor: locked ? _soft : _field,
              prefixIcon: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Text(
                  _symbol,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _title,
                    fontSize: 15,
                  ),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              suffixIcon:
                  _isEditing
                      ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _editBalance = !_editBalance;
                              if (!_editBalance) {
                                _balanceCtrl.text = widget.account!.balance
                                    .toStringAsFixed(2);
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: _tealText,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _editBalance ? 'Cancelar' : 'Corregir',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      : null,
              helperText:
                  _editBalance
                      ? 'Estás corrigiendo el saldo manualmente.'
                      : null,
              helperStyle: TextStyle(fontSize: 11.5, color: _muted),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            validator: (v) {
              if (locked) return null;
              final text = v?.trim() ?? '';
              if (text.isEmpty) return _isEditing ? 'Ingresa un saldo' : null;
              final parsed = double.tryParse(text.replaceAll(',', '.'));
              if (parsed == null) return 'Ingresa un número válido';
              if (!_isEditing && parsed < 0) {
                return 'El saldo inicial no puede ser negativo';
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 10),
        _currencySegment(),
      ],
    );
  }

  Widget _currencySegment() {
    Widget seg(String code) {
      final selected = _currencyCode == code;
      return InkWell(
        onTap: () => setState(() => _currencyCode = code),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            code,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _muted,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg('PEN'), seg('USD')],
      ),
    );
  }

  // ── Estado (solo edición) ─────────────────────────────────────────────────
  Widget _buildActiveToggle() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuenta activa',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    color: _title,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isActive
                      ? 'Disponible para cobros y pagos'
                      : 'No aparecerá en nuevos registros',
                  style: TextStyle(fontSize: 12, color: _muted),
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
    );
  }

  // ── Helpers visuales ──────────────────────────────────────────────────────
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
        color: _title,
      ),
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13.5, color: _hint),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: _field,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _line),
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

// ═════════════════════════════════════════════════════════════════════════════
// Buscador completo de entidades (agrupado por tipo)
// ═════════════════════════════════════════════════════════════════════════════
class _PresetSearchSheet extends StatefulWidget {
  final String selectedKey;
  final ValueChanged<FinancialBrandPreset> onSelectPreset;

  /// Recibe el texto buscado (si lo hay) para usarlo como nombre personalizado.
  final ValueChanged<String?> onSelectCustom;

  /// true en desktop: se muestra como diálogo centrado (sin handle, con
  /// esquinas redondeadas completas y foco automático en el buscador).
  final bool asDialog;

  const _PresetSearchSheet({
    this.asDialog = false,
    required this.selectedKey,
    required this.onSelectPreset,
    required this.onSelectCustom,
  });

  @override
  State<_PresetSearchSheet> createState() => _PresetSearchSheetState();
}

class _PresetSearchSheetState extends State<_PresetSearchSheet> {
  final _searchCtrl = TextEditingController();
  String _raw = '';

  String get _query => _raw.toLowerCase();

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _raw = _searchCtrl.text.trim());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static const _groupOrder = ['CAJA', 'DIGITAL', 'BANCO'];

  String _groupTitle(String type) {
    switch (type) {
      case 'CAJA':
        return 'Cajas';
      case 'DIGITAL':
        return 'Billeteras digitales';
      case 'BANCO':
        return 'Bancos';
      default:
        return 'Otras';
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.txtSecondary(context);
    final title = AppColors.txtPrimary(context);
    final dark = AppColors.isDark(context);
    final teal = dark ? const Color(0xFF2DD4BF) : AppColors.tealDark;

    final presets =
        FinancialBrandHelper.presets.where((p) {
          if (_query.isEmpty) return true;
          return p.label.toLowerCase().contains(_query) ||
              p.defaultName.toLowerCase().contains(_query);
        }).toList();

    final groups = <String, List<FinancialBrandPreset>>{};
    for (final p in presets) {
      groups.putIfAbsent(p.type, () => []).add(p);
    }
    final keys = [
      ..._groupOrder.where(groups.containsKey),
      ...groups.keys.where((k) => !_groupOrder.contains(k)),
    ];

    final screenH = MediaQuery.of(context).size.height;
    final maxH = widget.asDialog ? screenH * 0.8 : screenH * 0.75;
    final radius =
        widget.asDialog
            ? BorderRadius.circular(18)
            : const BorderRadius.vertical(top: Radius.circular(20));

    // Material (no Container) para que el ripple de los ListTile sea visible
    return Material(
      color: AppColors.surf(context),
      borderRadius: radius,
      elevation: widget.asDialog ? 12 : 0,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.asDialog)
              const AppSheetDragHandle(
                padding: EdgeInsets.only(top: 10, bottom: 8),
              )
            else
              const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Seleccionar entidad',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: title,
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
                autofocus: widget.asDialog,
                textInputAction: TextInputAction.done,
                // Enter: elige el primer resultado, o usa el texto como nombre
                onSubmitted: (_) {
                  if (presets.isNotEmpty) {
                    widget.onSelectPreset(presets.first);
                  } else if (_raw.isNotEmpty) {
                    widget.onSelectCustom(_raw);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Buscar banco, billetera o caja...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.txtMuted(context),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: muted,
                  ),
                  suffixIcon:
                      _raw.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: _searchCtrl.clear,
                          )
                          : null,
                  isDense: true,
                  filled: true,
                  fillColor:
                      dark ? AppColors.darkBackground : AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.brdSubtle(context)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.brdSubtle(context)),
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
            Divider(height: 1, color: AppColors.brd(context)),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  for (final key in keys) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
                      child: Text(
                        _groupTitle(key).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: muted,
                        ),
                      ),
                    ),
                    for (final p in groups[key]!) _presetTile(p, title, muted),
                  ],
                  if (_raw.isNotEmpty && presets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                      child: Text(
                        'Sin coincidencias para “$_raw”.',
                        style: TextStyle(fontSize: 13, color: muted),
                      ),
                    ),
                  const Divider(height: 24),
                  _customTile(title, muted, teal),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetTile(FinancialBrandPreset p, Color title, Color muted) {
    final isSelected = widget.selectedKey == p.key;
    // Solo mostramos el nombre por defecto si aporta algo distinto al título
    final showSub = p.defaultName.toLowerCase() != p.label.toLowerCase();
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
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          color: isSelected ? p.primaryColor : title,
        ),
      ),
      subtitle:
          showSub
              ? Text(
                p.defaultName,
                style: TextStyle(fontSize: 12, color: muted),
              )
              : null,
      trailing:
          isSelected
              ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.teal,
                size: 20,
              )
              : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () => widget.onSelectPreset(p),
    );
  }

  Widget _customTile(Color title, Color muted, Color teal) {
    final hasQuery = _raw.isNotEmpty;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.edit_note_rounded, color: teal, size: 20),
      ),
      title: Text(
        hasQuery ? 'Usar “$_raw” como nombre' : 'Otra cuenta o nombre propio',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: title,
        ),
      ),
      subtitle: Text(
        hasQuery
            ? 'Cuenta personalizada, logo automático'
            : 'Si tu entidad no está en la lista',
        style: TextStyle(fontSize: 12, color: muted),
      ),
      trailing:
          widget.selectedKey == 'auto'
              ? const Icon(
                Icons.check_circle_rounded,
                color: AppColors.teal,
                size: 20,
              )
              : Icon(Icons.chevron_right_rounded, size: 18, color: muted),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: () => widget.onSelectCustom(hasQuery ? _raw : null),
    );
  }
}
