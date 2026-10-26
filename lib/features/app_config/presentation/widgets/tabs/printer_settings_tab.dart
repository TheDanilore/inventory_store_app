import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/pos_printer_settings_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_scroll_content.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_section_card.dart';
import 'package:inventory_store_app/features/app_config/presentation/widgets/components/settings_tiles.dart';

class PrinterSettingsTab extends StatefulWidget {
  final bool isDark;

  const PrinterSettingsTab({super.key, required this.isDark});

  @override
  State<PrinterSettingsTab> createState() => _PrinterSettingsTabState();
}

class _PrinterSettingsTabState extends State<PrinterSettingsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TextEditingController _printerFooterCtrl;
  bool _isPrintingTestTicket = false;

  @override
  void initState() {
    super.initState();
    _printerFooterCtrl = TextEditingController(
      text: PosPrinterSettingsService.footerMessageNotifier.value,
    );
  }

  @override
  void dispose() {
    _printerFooterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = widget.isDark;
    return BlocBuilder<AppConfigCubit, AppConfigState>(
      builder: (context, state) {
        final info = state.businessInfo;
        final businessName = info?.businessName ?? 'DANILORE ONE ERP';
        final taxId = info?.taxId ?? '10751565149';
        final address = info?.address ?? 'Virtual';
        final phone = info?.phone ?? '';

        return SettingsScrollContent(
          isDark: isDark,
          children: [
            SettingsSectionCard(
              isDark: isDark,
              icon: Icons.print_rounded,
              title: 'Configuración de Impresión Térmica POS',
              subtitle:
                  'Ajusta el ancho de papel, disparo automático de tickets y realiza pruebas de corte y texto',
              children: [
                // 1. Selector de Ancho de Papel
                ValueListenableBuilder<String>(
                  valueListenable: PosPrinterSettingsService.paperWidthNotifier,
                  builder: (context, currentWidth, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Ancho del Rollo de Papel Térmico',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2563EB,
                                  ).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  currentWidth,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(
                            builder: (context, radioConstraints) {
                              final isNarrow = radioConstraints.maxWidth < 440;
                              final option80 = _buildPaperWidthOption(
                                width: '80mm',
                                label: '80 mm (Estándar POS)',
                                desc:
                                    'Ticketeras fijas USB/Red (Epson, Bixolon, Xprinter)',
                                isSelected: currentWidth == '80mm',
                                isDark: isDark,
                                onTap:
                                    () =>
                                        PosPrinterSettingsService.setPaperWidth(
                                          '80mm',
                                        ),
                              );
                              final option58 = _buildPaperWidthOption(
                                width: '58mm',
                                label: '58 mm (Compacto)',
                                desc:
                                    'Ticketeras móviles Bluetooth y terminales portátiles',
                                isSelected: currentWidth == '58mm',
                                isDark: isDark,
                                onTap:
                                    () =>
                                        PosPrinterSettingsService.setPaperWidth(
                                          '58mm',
                                        ),
                              );

                              if (isNarrow) {
                                return Column(
                                  children: [
                                    option80,
                                    const SizedBox(height: 8),
                                    option58,
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(child: option80),
                                  const SizedBox(width: 10),
                                  Expanded(child: option58),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 2. Impresión Automática al Cobrar
                ValueListenableBuilder<bool>(
                  valueListenable: PosPrinterSettingsService.autoPrintNotifier,
                  builder: (context, autoPrint, _) {
                    return SettingsSwitchTile(
                      isDark: isDark,
                      icon: Icons.auto_mode_rounded,
                      title: 'Impresión Automática al Cobrar',
                      subtitle:
                          'Abre el cuadro de diálogo de impresión automáticamente al completar una venta en el POS.',
                      value: autoPrint,
                      onChanged: (val) {
                        PosPrinterSettingsService.setAutoPrint(val);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 3. Cantidad de Copias
                ValueListenableBuilder<int>(
                  valueListenable: PosPrinterSettingsService.copiesNotifier,
                  builder: (context, copies, _) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isDark
                                ? AppColors.darkSurfaceElevated
                                : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isDark
                                  ? AppColors.darkBorderSubtle
                                  : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, boxConstraints) {
                          final isNarrow = boxConstraints.maxWidth < 460;
                          final infoCol = Row(
                            children: [
                              const Icon(
                                Icons.copy_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Copias del Comprobante',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      '1 copia para el cliente, o 2 para control interno de almacén/cocina',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );

                          final segButton = SegmentedButton<int>(
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: const Color(0xFF2563EB),
                              selectedForegroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            segments: const [
                              ButtonSegment(value: 1, label: Text('1 Copia')),
                              ButtonSegment(value: 2, label: Text('2 Copias')),
                            ],
                            selected: {copies},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) {
                                PosPrinterSettingsService.setCopies(set.first);
                              }
                            },
                          );

                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                infoCol,
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: segButton,
                                ),
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: infoCol),
                              const SizedBox(width: 12),
                              segButton,
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                // 4. Mensaje del Pie de Página del Ticket
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark
                              ? AppColors.darkBorderSubtle
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.short_text_rounded,
                            color: Color(0xFF2563EB),
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Mensaje al Pie del Ticket',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _printerFooterCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText:
                              'Ej: ¡Gracias por su compra! Conserve su ticket para cualquier garantía.',
                          hintStyle: const TextStyle(fontSize: 12),
                          filled: true,
                          fillColor:
                              isDark ? const Color(0xFF0F172A) : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color:
                                  isDark
                                      ? AppColors.darkBorder
                                      : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.save_rounded, size: 16),
                          label: const Text(
                            'Guardar Mensaje',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () async {
                            await PosPrinterSettingsService.setFooterMessage(
                              _printerFooterCtrl.text.trim(),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pie de ticket actualizado correctamente',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 5. Laboratorio de Calibración / Impresión de Prueba
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, boxConstraints) {
                      final isNarrow = boxConstraints.maxWidth < 480;

                      final iconAndText = Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.print_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Laboratorio de Calibración Térmica',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Envía un ticket de prueba para validar alineación, corte y nitidez.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final printBtn = FilledButton.icon(
                        icon:
                            _isPrintingTestTicket
                                ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : const Icon(Icons.send_rounded, size: 16),
                        label: Text(
                          _isPrintingTestTicket
                              ? 'Enviando...'
                              : 'Imprimir Prueba',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed:
                            _isPrintingTestTicket
                                ? null
                                : () async {
                                  setState(() => _isPrintingTestTicket = true);
                                  final currencySymbol =
                                      this.context
                                          .read<AppConfigCubit>()
                                          .state
                                          .currencySymbol;
                                  final success =
                                      await PosPrinterSettingsService.printTestTicket(
                                        businessName: businessName,
                                        taxId: taxId,
                                        address: address,
                                        phone: phone,
                                        currencySymbol: currencySymbol,
                                      );
                                  if (!mounted) return;
                                  setState(() => _isPrintingTestTicket = false);
                                  ScaffoldMessenger.of(
                                    this.context,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Ticket de prueba enviado a la cola de impresión'
                                            : 'No se pudo generar el ticket de prueba',
                                      ),
                                      backgroundColor:
                                          success
                                              ? const Color(0xFF10B981)
                                              : AppColors.danger,
                                    ),
                                  );
                                },
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            iconAndText,
                            const SizedBox(height: 14),
                            SizedBox(width: double.infinity, child: printBtn),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: iconAndText),
                          const SizedBox(width: 12),
                          printBtn,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaperWidthOption({
    required String width,
    required String label,
    required String desc,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF0F172A) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF2563EB)
                    : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color:
                      isSelected
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF94A3B8),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color:
                          isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark
                                  ? AppColors.darkTextPrimary
                                  : const Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
