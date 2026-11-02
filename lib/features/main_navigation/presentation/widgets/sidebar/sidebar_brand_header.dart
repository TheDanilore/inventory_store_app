import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/sidebar/sidebar_collapsible_label.dart';

class SidebarBrandHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const SidebarBrandHeader({
    super.key,
    required this.isCollapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
      child: ClipRect(
        child: Row(
          mainAxisAlignment:
              isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Tooltip(
              message: isCollapsed ? 'Expandir menú' : 'DANILORE ONE ERP',
              preferBelow: false,
              verticalOffset: 16,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isCollapsed ? onToggleCollapse : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 38,
                    height: 38,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFDBEAFE),
                        width: 1,
                      ),
                    ),
                    child: Image.asset(
                          'assets/logo_icon.png',
                          fit: BoxFit.contain,
                        )
                        .animate(target: isCollapsed ? 1 : 0)
                        .rotate(
                          begin: 0,
                          end: 1,
                          duration: 320.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: CollapsibleLabel(
                collapsed: isCollapsed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 12),
                    Expanded(
                      child:
                          BlocSelector<AppConfigCubit, AppConfigState, String>(
                            selector:
                                (state) =>
                                    state.businessInfo?.businessName ??
                                    'DANILORE ONE',
                            builder: (context, name) {
                              final isDefault =
                                  name.trim().isEmpty ||
                                  name == 'ERP Tienda' ||
                                  name == 'Mi Tienda' ||
                                  name.toUpperCase().contains('DANILORE');

                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isDefault)
                                    Row(
                                      children: [
                                        Text(
                                          'DANILORE ',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                isDark
                                                    ? AppColors.darkTextPrimary
                                                    : const Color(0xFF0F172A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const Text(
                                          'ONE',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF3B82F6),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isDark
                                                ? AppColors.darkTextPrimary
                                                : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      isDefault
                                          ? 'Todo tu negocio en un solo lugar'
                                          : 'DANILORE ONE ERP',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            isDark
                                                ? AppColors.darkTextMuted
                                                : const Color(0xFF64748B),
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'Colapsar menú',
                preferBelow: false,
                verticalOffset: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onToggleCollapse,
                    borderRadius: BorderRadius.circular(8),
                    hoverColor:
                        isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.05),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                          width: 0.8,
                        ),
                      ),
                      child: Icon(
                        Icons.view_sidebar_outlined,
                        size: 16,
                        color:
                            isDark
                                ? AppColors.darkTextSecondary
                                : const Color(0xFF64748B),
                      ),
                    ),
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
