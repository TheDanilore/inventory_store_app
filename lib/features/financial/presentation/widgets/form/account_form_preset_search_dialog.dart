import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/features/financial/domain/utils/financial_brand_helper.dart';

class AccountFormPresetSearchDialog extends StatefulWidget {
  final String selectedKey;
  final ValueChanged<FinancialBrandPreset> onSelectPreset;
  final ValueChanged<String?> onSelectCustom;
  final bool asDialog;

  const AccountFormPresetSearchDialog({
    super.key,
    this.asDialog = false,
    required this.selectedKey,
    required this.onSelectPreset,
    required this.onSelectCustom,
  });

  static Future<void> show(
    BuildContext context, {
    required bool asDialog,
    required String selectedKey,
    required ValueChanged<FinancialBrandPreset> onSelectPreset,
    required ValueChanged<String?> onSelectCustom,
  }) {
    if (asDialog) {
      return showDialog(
        context: context,
        builder:
            (dialogCtx) => Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AccountFormPresetSearchDialog(
                  asDialog: true,
                  selectedKey: selectedKey,
                  onSelectPreset: (preset) {
                    Navigator.pop(dialogCtx);
                    onSelectPreset(preset);
                  },
                  onSelectCustom: (name) {
                    Navigator.pop(dialogCtx);
                    onSelectCustom(name);
                  },
                ),
              ),
            ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetCtx) => AccountFormPresetSearchDialog(
            selectedKey: selectedKey,
            onSelectPreset: (preset) {
              Navigator.pop(sheetCtx);
              onSelectPreset(preset);
            },
            onSelectCustom: (name) {
              Navigator.pop(sheetCtx);
              onSelectCustom(name);
            },
          ),
    );
  }

  @override
  State<AccountFormPresetSearchDialog> createState() =>
      _AccountFormPresetSearchDialogState();
}

class _AccountFormPresetSearchDialogState
    extends State<AccountFormPresetSearchDialog> {
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
