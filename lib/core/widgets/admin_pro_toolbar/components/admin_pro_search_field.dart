import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class AdminDesktopSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String? searchKeyHint;
  final bool searchOnSubmitOnly;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback? onScanBarcode;
  final String scanBarcodeTooltip;

  const AdminDesktopSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    this.searchKeyHint,
    required this.searchOnSubmitOnly,
    this.onSearchChanged,
    this.onSearchSubmitted,
    required this.onClearSearch,
    this.onScanBarcode,
    required this.scanBarcodeTooltip,
  });

  void _executeSearch(BuildContext context, [String? query]) {
    final text = query ?? controller.text;
    final trimmed = text.trim();
    onSearchSubmitted?.call(trimmed);
    onSearchChanged?.call(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final searchTooltipMsg =
        searchKeyHint != null && searchKeyHint!.isNotEmpty
            ? 'Buscar (Atajo: $searchKeyHint o Alt+$searchKeyHint)'
            : 'Buscar';

    return SizedBox(
      height: 40,
      child: Tooltip(
        message: searchTooltipMsg,
        waitDuration: const Duration(milliseconds: 600),
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (val) {
            if (searchOnSubmitOnly) {
              if (val.isEmpty) {
                _executeSearch(context, '');
              }
            } else {
              onSearchChanged?.call(val);
            }
          },
          onSubmitted: (val) => _executeSearch(context, val),
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDark ? const Color(0xFF60A5FA) : AppColors.teal,
              size: 19,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasFocus = focusNode.hasFocus;
                final showSearchBtn = value.text.isNotEmpty || hasFocus;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (value.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.textMuted,
                          size: 17,
                        ),
                        tooltip: 'Limpiar búsqueda (Atajo: Esc)',
                        splashRadius: 16,
                        onPressed: onClearSearch,
                      ),
                    if (onScanBarcode != null)
                      IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 19,
                        ),
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : AppColors.tealDark,
                        tooltip: scanBarcodeTooltip,
                        splashRadius: 18,
                        onPressed: () {
                          AppFeedbackService.lightImpact();
                          onScanBarcode!();
                        },
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: showSearchBtn ? 1.0 : 0.0,
                        child:
                            showSearchBtn
                                ? Tooltip(
                                  message: 'Buscar (Atajo: Enter)',
                                  waitDuration: const Duration(
                                    milliseconds: 400,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _executeSearch(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Ink(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                isDark
                                                    ? const Color(
                                                      0xFF60A5FA,
                                                    ).withValues(alpha: 0.15)
                                                    : AppColors.teal.withValues(
                                                      alpha: 0.1,
                                                    ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  isDark
                                                      ? const Color(
                                                        0xFF60A5FA,
                                                      ).withValues(alpha: 0.4)
                                                      : AppColors.teal
                                                          .withValues(
                                                            alpha: 0.35,
                                                          ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.search_rounded,
                                                size: 14,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF60A5FA,
                                                        )
                                                        : AppColors.tealDark,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Buscar',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      isDark
                                                          ? const Color(
                                                            0xFF60A5FA,
                                                          )
                                                          : AppColors.tealDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                );
              },
            ),
            filled: true,
            fillColor:
                isDark ? AppColors.darkSurfaceElevated : AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF60A5FA) : AppColors.teal,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class AdminMobileSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool searchOnSubmitOnly;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback? onScanBarcode;
  final String scanBarcodeTooltip;

  const AdminMobileSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.searchOnSubmitOnly,
    this.onSearchChanged,
    this.onSearchSubmitted,
    required this.onClearSearch,
    this.onScanBarcode,
    required this.scanBarcodeTooltip,
  });

  void _executeSearch([String? query]) {
    final text = query ?? controller.text;
    final trimmed = text.trim();
    onSearchSubmitted?.call(trimmed);
    onSearchChanged?.call(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: (val) {
          if (searchOnSubmitOnly) {
            if (val.isEmpty) {
              _executeSearch('');
            }
          } else {
            onSearchChanged?.call(val);
          }
        },
        onSubmitted: (val) => _executeSearch(val),
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
            fontSize: 13,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      splashRadius: 18,
                      onPressed: onClearSearch,
                    ),
                  if (onScanBarcode != null)
                    IconButton(
                      icon: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 20,
                        color:
                            isDark
                                ? const Color(0xFF60A5FA)
                                : AppColors.primary,
                      ),
                      tooltip: scanBarcodeTooltip,
                      splashRadius: 20,
                      onPressed: () {
                        AppFeedbackService.lightImpact();
                        onScanBarcode!();
                      },
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color:
                          isDark ? const Color(0xFF60A5FA) : AppColors.primary,
                    ),
                    tooltip: 'Buscar',
                    splashRadius: 20,
                    onPressed: () {
                      AppFeedbackService.lightImpact();
                      _executeSearch();
                    },
                  ),
                ],
              );
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
