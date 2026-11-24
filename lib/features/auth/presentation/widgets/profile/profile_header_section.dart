import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/hover_shortcut_tooltip.dart';

class ProfileHeaderSection extends StatefulWidget {
  final String displayName;
  final String userRole;
  final String email;
  final int walletBalance;
  final String? avatarUrl;
  final Uint8List? imageBytes;
  final bool isEditing;
  final bool isLoyaltyEnabled;
  final VoidCallback? onPickImage;
  final VoidCallback? onEditToggle;
  final bool isTablet;
  final String? warehouseName;
  final bool isActive;

  const ProfileHeaderSection({
    super.key,
    required this.displayName,
    required this.userRole,
    required this.email,
    required this.walletBalance,
    required this.avatarUrl,
    required this.imageBytes,
    required this.isEditing,
    required this.isLoyaltyEnabled,
    this.onPickImage,
    this.onEditToggle,
    this.isTablet = false,
    this.warehouseName,
    this.isActive = true,
  });

  @override
  State<ProfileHeaderSection> createState() => _ProfileHeaderSectionState();
}

class _ProfileHeaderSectionState extends State<ProfileHeaderSection> {
  bool _avatarHovered = false;
  bool _avatarPressed = false;
  bool _editHovered = false;
  bool _editPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final heroColors = AppColors.profileHeroGradient(context);
    final initial =
        widget.displayName.isNotEmpty
            ? widget.displayName[0].toUpperCase()
            : 'U';

    return AnimatedContainer(
      duration:
          disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: heroColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isDark
                  ? AppColors.darkBorderSubtle
                  : Colors.white.withValues(alpha: 0.14),
          width: 1,
        ),
        boxShadow:
            isDark
                ? null
                : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          widget.isTablet ? 20 : 22,
          20,
          widget.isTablet ? 20 : 22,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar interactivo con target táctil amplio (>= 76x76pt)
                HoverShortcutTooltip(
                  message: 'Personalizar avatar',
                  shortcut: 'A',
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _avatarHovered = true),
                    onExit: (_) => setState(() => _avatarHovered = false),
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _avatarPressed = true),
                      onTapUp: (_) => setState(() => _avatarPressed = false),
                      onTapCancel: () => setState(() => _avatarPressed = false),
                      onTap: () {
                        AppFeedbackService.lightImpact();
                        widget.onPickImage?.call();
                      },
                      child: AnimatedScale(
                        scale:
                            _avatarPressed
                                ? 0.94
                                : (_avatarHovered ? 1.03 : 1.0),
                        duration:
                            disableAnimations
                                ? Duration.zero
                                : const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: _avatarHovered ? 0.85 : 0.45,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: widget.isTablet ? 34 : 36,
                                    backgroundColor:
                                        isDark
                                            ? AppColors.darkSurfaceElevated
                                            : AppColors.primary,
                                    backgroundImage:
                                        widget.imageBytes != null
                                            ? MemoryImage(widget.imageBytes!)
                                                as ImageProvider
                                            : (widget.avatarUrl != null &&
                                                    widget.avatarUrl!.isNotEmpty
                                                ? CachedNetworkImageProvider(
                                                  widget.avatarUrl!,
                                                )
                                                : null),
                                    child:
                                        (widget.imageBytes == null &&
                                                (widget.avatarUrl == null ||
                                                    widget.avatarUrl!.isEmpty))
                                            ? Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            )
                                            : null,
                                  ),
                                  Positioned.fill(
                                    child: AnimatedOpacity(
                                      opacity: _avatarHovered ? 1.0 : 0.0,
                                      duration:
                                          disableAnimations
                                              ? Duration.zero
                                              : const Duration(
                                                milliseconds: 120,
                                              ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: AnimatedContainer(
                                duration:
                                    disableAnimations
                                        ? Duration.zero
                                        : const Duration(milliseconds: 200),
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color:
                                      widget.isEditing
                                          ? AppColors.accent
                                          : AppColors.success,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                        isDark
                                            ? AppColors.darkSurface
                                            : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  widget.isEditing
                                      ? Icons.camera_alt_rounded
                                      : Icons.face_retouching_natural_rounded,
                                  size: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Nombre, email y metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.displayName.isEmpty
                            ? 'Usuario'
                            : widget.displayName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                          height: 1.18,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.email,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _HeroBadge(
                            label: widget.userRole.toUpperCase(),
                            leading: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color:
                                    widget.isActive
                                        ? AppColors.darkSuccessText
                                        : AppColors.darkWarningText,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          if (widget.warehouseName != null &&
                              widget.warehouseName!.isNotEmpty)
                            _HeroBadge(
                              label: widget.warehouseName!,
                              leading: Icon(
                                Icons.storefront_rounded,
                                size: 11,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Botón Editar >= 44x44pt (Apple HIG)
                if (widget.onEditToggle != null)
                  HoverShortcutTooltip(
                    message:
                        widget.isEditing ? 'Cancelar edición' : 'Editar perfil',
                    shortcut: widget.isEditing ? 'Esc' : 'E',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      onEnter: (_) => setState(() => _editHovered = true),
                      onExit: (_) => setState(() => _editHovered = false),
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _editPressed = true),
                        onTapUp: (_) => setState(() => _editPressed = false),
                        onTapCancel: () => setState(() => _editPressed = false),
                        onTap: () {
                          AppFeedbackService.selectionClick();
                          widget.onEditToggle?.call();
                        },
                        child: AnimatedScale(
                          scale: _editPressed ? 0.92 : 1.0,
                          duration:
                              disableAnimations
                                  ? Duration.zero
                                  : const Duration(milliseconds: 110),
                          curve: Curves.easeOutCubic,
                          child: AnimatedContainer(
                            duration:
                                disableAnimations
                                    ? Duration.zero
                                    : const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color:
                                  widget.isEditing
                                      ? AppColors.accent.withValues(
                                        alpha: _editHovered ? 0.38 : 0.26,
                                      )
                                      : Colors.white.withValues(
                                        alpha: _editHovered ? 0.22 : 0.12,
                                      ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color:
                                    widget.isEditing
                                        ? AppColors.accent.withValues(
                                          alpha: 0.55,
                                        )
                                        : Colors.white.withValues(
                                          alpha: _editHovered ? 0.35 : 0.20,
                                        ),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration:
                                  disableAnimations
                                      ? Duration.zero
                                      : const Duration(milliseconds: 200),
                              child: Icon(
                                widget.isEditing
                                    ? Icons.close_rounded
                                    : Icons.edit_rounded,
                                key: ValueKey(widget.isEditing),
                                color: Colors.white,
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Wallet balance strip (si loyalty está activo)
            if (widget.isLoyaltyEnabled) ...[
              const SizedBox(height: 18),
              InkWell(
                onTap: () => context.go('/points'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          size: 18,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo de monedas',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${widget.walletBalance} monedas',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.65),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final Widget? leading;

  const _HeroBadge({required this.label, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}
