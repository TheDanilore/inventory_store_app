import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/services/barcode_scanner_hardware_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/theme/bloc/theme_cubit.dart';
import 'package:inventory_store_app/core/theme/widgets/theme_circular_wave.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_scroll_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_section_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_tiles.dart';

class AppearanceSettingsTab extends StatefulWidget {
  final bool isDark;

  const AppearanceSettingsTab({super.key, required this.isDark});

  @override
  State<AppearanceSettingsTab> createState() => _AppearanceSettingsTabState();
}

class _AppearanceSettingsTabState extends State<AppearanceSettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;

    return SettingsScrollContent(
      isDark: isDark,
      children: [
        // ── Tema visual ──
        SettingsSectionCard(
          isDark: isDark,
          icon: Icons.palette_outlined,
          title: 'Tema y Paleta Visual',
          subtitle:
              'Personaliza la interfaz de usuario en toda la plataforma ERP',
          children: [
            BlocBuilder<ThemeCubit, ThemeMode>(
              builder: (context, currentMode) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;

                    final options = [
                      _ThemeOptionItem(
                        mode: ThemeMode.light,
                        title: 'Claro Ejecutivo',
                        subtitle: 'Estilo Apple / Linear HIG',
                        icon: Icons.light_mode_rounded,
                        isSelected: currentMode == ThemeMode.light,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.dark,
                        title: 'Oscuro Midnight',
                        subtitle: 'Slate Navy (#0B0F19)',
                        icon: Icons.dark_mode_rounded,
                        isSelected: currentMode == ThemeMode.dark,
                      ),
                      _ThemeOptionItem(
                        mode: ThemeMode.system,
                        title: 'Automático',
                        subtitle: 'Sincronizado con el SO',
                        icon: Icons.brightness_auto_rounded,
                        isSelected: currentMode == ThemeMode.system,
                      ),
                    ];

                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      children:
                          options.map((opt) {
                            final card = Builder(
                              builder: (itemCtx) {
                                return InkWell(
                                  onTap: () {
                                    AppFeedbackService.vibrate(
                                      durationMs: 35,
                                      amplitude: 90,
                                    );
                                    final renderBox =
                                        itemCtx.findRenderObject()
                                            as RenderBox?;
                                    Offset? origin;
                                    if (renderBox != null &&
                                        renderBox.hasSize) {
                                      origin = renderBox.localToGlobal(
                                        renderBox.size.center(Offset.zero),
                                      );
                                    }
                                    ThemeCircularWave.switchTheme(
                                      context,
                                      origin: origin,
                                      targetMode: opt.mode,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color:
                                          opt.isSelected
                                              ? (isDark
                                                  ? const Color(
                                                    0xFF1E3A8A,
                                                  ).withValues(alpha: 0.35)
                                                  : const Color(0xFFEFF6FF))
                                              : (isDark
                                                  ? const Color(0xFF111827)
                                                  : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color:
                                            opt.isSelected
                                                ? const Color(0xFF3B82F6)
                                                : (isDark
                                                    ? AppColors.darkBorderSubtle
                                                    : const Color(0xFFE2E8F0)),
                                        width: opt.isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          opt.icon,
                                          size: 22,
                                          color:
                                              opt.isSelected
                                                  ? const Color(0xFF3B82F6)
                                                  : (isDark
                                                      ? AppColors
                                                          .darkTextSecondary
                                                      : const Color(
                                                        0xFF64748B,
                                                      )),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                opt.title,
                                                style: TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      opt.isSelected
                                                          ? (isDark
                                                              ? const Color(
                                                                0xFF93C5FD,
                                                              )
                                                              : const Color(
                                                                0xFF1E40AF,
                                                              ))
                                                          : (isDark
                                                              ? AppColors
                                                                  .darkTextPrimary
                                                              : const Color(
                                                                0xFF0F172A,
                                                              )),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                opt.subtitle,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      isDark
                                                          ? AppColors
                                                              .darkTextMuted
                                                          : const Color(
                                                            0xFF64748B,
                                                          ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (opt.isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: Color(0xFF3B82F6),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );

                            if (isWide) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                  ),
                                  child: card,
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: card,
                            );
                          }).toList(),
                    );
                  },
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Preferencias de Interacción (Vibración y Sonido interactivos) ──
        SettingsSectionCard(
          isDark: isDark,
          icon: Icons.tune_rounded,
          title: 'Preferencias de Interacción y Hardware',
          subtitle:
              'Configura y prueba la vibración, sonidos de confirmación y atajos de teclado',
          children: [
            // Switch 1: Vibración / Feedback Háptico
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.hapticNotifier,
              builder: (context, isHapticEnabled, _) {
                return SettingsSwitchTile(
                  isDark: isDark,
                  icon: Icons.vibration_rounded,
                  title: 'Feedback Háptico (Vibración)',
                  subtitle:
                      'Vibración táctil al escanear productos, presionar botones clave y cobrar.',
                  value: isHapticEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setHapticFeedback(val);
                    if (val) {
                      AppFeedbackService.vibrate(
                        durationMs: 70,
                        amplitude: 160,
                      );
                    }
                  },
                  trailingAction:
                      isHapticEnabled
                          ? TextButton.icon(
                            icon: const Icon(Icons.touch_app_rounded, size: 14),
                            label: const Text(
                              'Probar',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF2563EB),
                            ),
                            onPressed:
                                () => AppFeedbackService.vibrate(
                                  durationMs: 90,
                                  amplitude: 200,
                                ),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Switch 2: Sonido / Bip de Escaneo y Ventas
            ValueListenableBuilder<bool>(
              valueListenable: BarcodeScannerHardwareService.soundBeepNotifier,
              builder: (context, isSoundEnabled, _) {
                return SettingsSwitchTile(
                  isDark: isDark,
                  icon: Icons.volume_up_rounded,
                  title: 'Sonido y Bip de Confirmación',
                  subtitle:
                      'Emite un sonido auditivo al leer códigos de barras o registrar ventas con éxito.',
                  value: isSoundEnabled,
                  onChanged: (val) async {
                    await BarcodeScannerHardwareService.setSoundBeep(val);
                    if (val) {
                      AppFeedbackService.playBeep();
                    }
                  },
                  trailingAction:
                      isSoundEnabled
                          ? TextButton.icon(
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 14,
                            ),
                            label: const Text(
                              'Probar Sonido',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: const Color(0xFF10B981),
                            ),
                            onPressed: () => AppFeedbackService.playBeep(),
                          )
                          : null,
                );
              },
            ),
            const SizedBox(height: 10),

            // Item 3: Atajos de Teclado con Modal Informativo
            SettingsActionTile(
              isDark: isDark,
              icon: Icons.keyboard_rounded,
              title: 'Atajos Globales de Teclado',
              subtitle:
                  '⌘K / Ctrl+K búsqueda rápida · F2 Cobro POS · Alt+B Guardar borrador',
              actionLabel: 'Ver Todos',
              onActionPressed: () => _showKeyboardShortcutsDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showKeyboardShortcutsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor:
                isDark ? AppColors.darkSurfaceElevated : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.keyboard_rounded, color: Color(0xFF2563EB)),
                SizedBox(width: 10),
                Text(
                  'Atajos Globales de Teclado',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildShortcutRow('⌘K / Ctrl+K', 'Búsqueda instantánea ERP'),
                  _buildShortcutRow(
                    'F2',
                    'Abrir cobro de venta en el POS (Checkout)',
                  ),
                  _buildShortcutRow(
                    'Alt + B',
                    'Guardar venta actual como borrador',
                  ),
                  _buildShortcutRow('⌘P / Ctrl+P', 'Reimprimir último ticket'),
                  _buildShortcutRow(
                    'F4',
                    'Enfocar buscador de productos con código de barras',
                  ),
                  _buildShortcutRow('Esc', 'Cerrar modales o cancelar diálogo'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Entendido'),
              ),
            ],
          ),
    );
  }

  Widget _buildShortcutRow(String keys, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              keys,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionItem {
  final ThemeMode mode;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;

  const _ThemeOptionItem({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
  });
}
