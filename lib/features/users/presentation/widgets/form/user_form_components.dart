import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/users/presentation/widgets/form/user_form_role_info.dart';

BoxDecoration userFormCardDecoration() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.grey.shade200),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.02),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
);

class UserFormInitialsAvatar extends StatelessWidget {
  final String name;
  const UserFormInitialsAvatar({super.key, required this.name});

  String get _initials {
    final parts =
        name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    final first = parts.first[0];
    final second = parts.length > 1 ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child:
          initials.isEmpty
              ? Icon(
                Icons.person_outline_rounded,
                size: 26,
                color: AppColors.primary.withValues(alpha: 0.7),
              )
              : Text(
                initials,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
    );
  }
}

class UserFormModePill extends StatelessWidget {
  final bool isEditing;
  const UserFormModePill({super.key, required this.isEditing});

  @override
  Widget build(BuildContext context) {
    final color = isEditing ? Colors.indigo.shade700 : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isEditing ? 'Edición' : 'Nuevo',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class UserFormRoleChip extends StatelessWidget {
  final UserFormRoleInfo info;
  const UserFormRoleChip({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, size: 14, color: info.color),
          const SizedBox(width: 5),
          Text(
            info.title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }
}

class UserFormRoleCard extends StatelessWidget {
  final UserFormRoleInfo info;
  final bool isSelected;
  final VoidCallback onTap;

  const UserFormRoleCard({
    super.key,
    required this.info,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = info.color;
    final radius = BorderRadius.circular(14);

    return Semantics(
      button: true,
      checked: isSelected,
      label: '${info.title}, ${info.subtitle}',
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.07) : Colors.white,
              borderRadius: radius,
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? color.withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    info.icon,
                    size: 22,
                    color: isSelected ? color : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child:
                      isSelected
                          ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                          : null,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: radius, onTap: onTap),
            ),
          ),
        ],
      ),
    );
  }
}

class UserFormSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  const UserFormSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: userFormCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}

class UserFormTwoColumns extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double breakpoint;
  final double gap;

  const UserFormTwoColumns({
    super.key,
    required this.left,
    required this.right,
    required this.breakpoint,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= breakpoint) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              SizedBox(width: gap),
              Expanded(child: right),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [left, SizedBox(height: gap + 2), right],
        );
      },
    );
  }
}

class UserFormAdaptiveGrid extends StatelessWidget {
  final double minItemWidth;
  final double spacing;
  final List<Widget> children;

  const UserFormAdaptiveGrid({
    super.key,
    required this.minItemWidth,
    required this.spacing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = max(
          1,
          ((c.maxWidth + spacing) / (minItemWidth + spacing)).floor(),
        );
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [for (final ch in children) SizedBox(width: w, child: ch)],
        );
      },
    );
  }
}

class UserFormPasswordStrength extends StatelessWidget {
  final String password;
  const UserFormPasswordStrength({super.key, required this.password});

  static int _level(String v) {
    if (v.length < 6) return 1;
    var s = 2;
    if (v.length >= 10) s++;
    final mixedCase =
        RegExp(r'[A-Z]').hasMatch(v) && RegExp(r'[a-z]').hasMatch(v);
    final digitOrSymbol =
        RegExp(r'[0-9]').hasMatch(v) || RegExp(r'[^A-Za-z0-9]').hasMatch(v);
    if (mixedCase && digitOrSymbol) s++;
    return min(s, 4);
  }

  @override
  Widget build(BuildContext context) {
    final level = _level(password);
    final colors = [
      Colors.red.shade500,
      Colors.orange.shade600,
      Colors.lightGreen.shade700,
      Colors.green.shade600,
    ];
    const labels = ['Muy corta', 'Débil', 'Buena', 'Segura'];
    final color = colors[level - 1];

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 4,
                    margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                    decoration: BoxDecoration(
                      color: i < level ? color : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          labels[level - 1],
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class UserFormCustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final bool required;
  final bool optional;
  final String hint;
  final String? helper;
  final IconData? icon;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool readOnly;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;

  const UserFormCustomTextField({
    super.key,
    required this.controller,
    this.label,
    this.required = false,
    this.optional = false,
    required this.hint,
    this.helper,
    this.icon,
    this.prefix,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.readOnly = false,
    this.suffixIcon,
    this.validator,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
  });

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      if (required)
                        TextSpan(
                          text: ' *',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (optional) ...[
                const SizedBox(width: 6),
                Text(
                  'Opcional',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          onFieldSubmitted: onSubmitted,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            color: readOnly ? Colors.grey.shade600 : AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            helperText: helper,
            helperMaxLines: 2,
            helperStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            errorMaxLines: 2,
            errorStyle: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Colors.red.shade700,
            ),
            prefixIcon:
                prefix ??
                (icon != null
                    ? Icon(icon, size: 20, color: Colors.grey.shade500)
                    : null),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: _border(Colors.grey.shade300),
            enabledBorder: _border(Colors.grey.shade300),
            focusedBorder: _border(
              readOnly ? Colors.grey.shade300 : AppColors.primary,
              1.6,
            ),
            errorBorder: _border(Colors.red.shade600),
            focusedErrorBorder: _border(Colors.red.shade600, 1.6),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
