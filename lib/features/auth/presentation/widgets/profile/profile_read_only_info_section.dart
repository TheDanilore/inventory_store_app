import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_surface_card.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class ProfileReadOnlyInfoSection extends StatelessWidget {
  final String email;
  final String userRole;
  final String fullName;
  final String phone;
  final String docType;
  final String docNum;
  final String? warehouseName;
  final bool isDenseDesktop;

  const ProfileReadOnlyInfoSection({
    super.key,
    required this.email,
    required this.userRole,
    required this.fullName,
    required this.phone,
    required this.docType,
    required this.docNum,
    this.warehouseName,
    this.isDenseDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final accountItems = <_InfoItemData>[
      _InfoItemData(
        icon: Icons.email_outlined,
        label: 'Correo electrónico',
        value: email,
        isEmpty: email.isEmpty || email == 'Sin correo',
        copyable: email.isNotEmpty && email != 'Sin correo',
      ),
      _InfoItemData(
        icon: Icons.shield_outlined,
        label: 'Rol del sistema',
        value: userRole.isEmpty ? 'No asignado' : userRole.toUpperCase(),
        isEmpty: userRole.isEmpty,
      ),
      if (warehouseName != null && warehouseName!.isNotEmpty)
        _InfoItemData(
          icon: Icons.storefront_outlined,
          label: 'Sucursal / Almacén',
          value: warehouseName!,
        ),
    ];

    final personalItems = <_InfoItemData>[
      _InfoItemData(
        icon: Icons.person_outline_rounded,
        label: 'Nombre completo',
        value: fullName.isEmpty ? 'No registrado' : fullName,
        isEmpty: fullName.isEmpty,
      ),
      _InfoItemData(
        icon: Icons.phone_outlined,
        label: 'Teléfono',
        value: phone.isEmpty ? 'No registrado' : phone,
        isEmpty: phone.isEmpty,
        tabular: true,
        copyable: phone.isNotEmpty,
      ),
      _InfoItemData(
        icon: Icons.badge_outlined,
        label: 'Documento ($docType)',
        value: docNum.isEmpty ? 'No registrado' : docNum,
        isEmpty: docNum.isEmpty,
        tabular: true,
        copyable: docNum.isNotEmpty,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoGroupCard(
          groupHeader: isDenseDesktop ? 'CUENTA Y ACCESO' : null,
          items: accountItems,
          isDenseDesktop: isDenseDesktop,
        ),
        SizedBox(height: isDenseDesktop ? 16 : 12),
        _InfoGroupCard(
          groupHeader: isDenseDesktop ? 'DATOS PERSONALES' : null,
          items: personalItems,
          isDenseDesktop: isDenseDesktop,
        ),
      ],
    );
  }
}

class _InfoItemData {
  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;
  final bool tabular;
  final bool copyable;

  const _InfoItemData({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.tabular = false,
    this.copyable = false,
  });
}

class _InfoGroupCard extends StatelessWidget {
  final String? groupHeader;
  final List<_InfoItemData> items;
  final bool isDenseDesktop;

  const _InfoGroupCard({
    required this.items,
    required this.isDenseDesktop,
    this.groupHeader,
  });

  @override
  Widget build(BuildContext context) {
    return AdaptiveSurfaceCard(
      borderRadius: 20,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (groupHeader != null) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(18, 11, 18, 10),
                color: AppColors.surfSubtle(context),
                child: Text(
                  groupHeader!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.txtMuted(context),
                  ),
                ),
              ),
              Divider(height: 1, color: AppColors.dividerColor(context)),
            ],
            for (int i = 0; i < items.length; i++) ...[
              _InfoTileRow(
                item: items[i],
                isDenseDesktop: isDenseDesktop,
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: isDenseDesktop ? 18 : 64,
                  endIndent: 16,
                  color: AppColors.dividerColor(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTileRow extends StatefulWidget {
  final _InfoItemData item;
  final bool isDenseDesktop;

  const _InfoTileRow({required this.item, required this.isDenseDesktop});

  @override
  State<_InfoTileRow> createState() => _InfoTileRowState();
}

class _InfoTileRowState extends State<_InfoTileRow> {
  bool _hovered = false;
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyValue() async {
    if (!widget.item.copyable) return;
    await Clipboard.setData(ClipboardData(text: widget.item.value));
    AppFeedbackService.lightImpact();

    if (!mounted) return;
    setState(() => _copied = true);
    AppSnackbar.show(
      context,
      message: '${widget.item.label} copiado al portapapeles',
      type: SnackbarType.info,
      duration: const Duration(milliseconds: 1800),
    );
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: widget.item.isEmpty ? FontWeight.w500 : FontWeight.w700,
      fontStyle: widget.item.isEmpty ? FontStyle.italic : FontStyle.normal,
      color:
          widget.item.isEmpty
              ? AppColors.txtMuted(context)
              : AppColors.txtPrimary(context),
      fontFeatures:
          (widget.item.tabular && !widget.item.isEmpty)
              ? const [FontFeature.tabularFigures()]
              : null,
    );

    if (widget.isDenseDesktop) {
      return MouseRegion(
        cursor:
            widget.item.copyable
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.item.copyable ? _copyValue : null,
          child: AnimatedContainer(
            duration:
                disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            color:
                _hovered ? AppColors.surfHover(context) : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 195,
                  child: Row(
                    children: [
                      Icon(
                        widget.item.icon,
                        size: 16,
                        color: AppColors.txtSecondary(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.txtSecondary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SelectableText(
                    widget.item.value,
                    style: valueStyle,
                  ),
                ),
                if (widget.item.copyable)
                  AnimatedOpacity(
                    opacity: (_hovered || _copied) ? 1.0 : 0.0,
                    duration:
                        disableAnimations
                            ? Duration.zero
                            : const Duration(milliseconds: 120),
                    child: Tooltip(
                      message: _copied ? 'Copiado' : 'Copiar',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _copyValue,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: AnimatedSwitcher(
                            duration:
                                disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 180),
                            transitionBuilder:
                                (child, anim) => ScaleTransition(
                                  scale: anim,
                                  child: child,
                                ),
                            child: Icon(
                              _copied
                                  ? Icons.check_rounded
                                  : Icons.copy_rounded,
                              key: ValueKey(_copied),
                              size: 15,
                              color:
                                  _copied
                                      ? AppColors.successText(context)
                                      : AppColors.txtSecondary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Móvil / Tablet: iOS Grouped Inset Row (>= 56pt altura)
    return InkWell(
      onTap: widget.item.copyable ? _copyValue : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfSubtle(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.brd(context)),
                ),
                child: Icon(
                  widget.item.icon,
                  size: 17,
                  color: AppColors.txtSecondary(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.txtMuted(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(widget.item.value, style: valueStyle),
                  ],
                ),
              ),
              if (widget.item.copyable)
                Icon(
                  _copied ? Icons.check_rounded : Icons.copy_rounded,
                  size: 16,
                  color:
                      _copied
                          ? AppColors.successText(context)
                          : AppColors.txtMuted(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
