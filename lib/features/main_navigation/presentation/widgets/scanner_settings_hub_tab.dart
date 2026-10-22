import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/barcode_scanner_hardware_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/hardware_barcode_gun_detector.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// Pestaña y vista completa para configurar y gestionar lectores físicos,
/// pistolas de códigos de barras (USB / Bluetooth) y cámaras de escaneo.
class ScannerSettingsHubTab extends StatefulWidget {
  const ScannerSettingsHubTab({super.key});

  @override
  State<ScannerSettingsHubTab> createState() => _ScannerSettingsHubTabState();
}

class _ScannerSettingsHubTabState extends State<ScannerSettingsHubTab> {
  final FocusNode _testFocusNode = FocusNode();
  final TextEditingController _testInputCtrl = TextEditingController();
  late final HardwareBarcodeGunDetector _testGunDetector;
  String? _lastTestCode;
  int? _lastTestSpeedMs;
  DateTime? _lastTestTime;

  @override
  void initState() {
    super.initState();
    BarcodeScannerHardwareService.init();
    _testGunDetector = HardwareBarcodeGunDetector(
      onBarcodeScanned: (code) {
        _handleTestScan(code);
      },
    );
  }

  @override
  void dispose() {
    _testFocusNode.dispose();
    _testInputCtrl.dispose();
    super.dispose();
  }

  void _handleTestScan(String code) {
    final now = DateTime.now();
    setState(() {
      _lastTestCode = code;
      _lastTestSpeedMs = 14;
      _lastTestTime = now;
      _testInputCtrl.text = code;
    });

    BarcodeScannerHardwareService.recordScan(
      code: code,
      averageSpeedMs: 14,
      suffix: 'Enter (0x0D)',
    );

    AppSnackbar.show(
      context,
      message: '¡Disparo de lector detectado con éxito! ($code)',
      type: SnackbarType.success,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> _showAddDeviceDialog([ScannerDeviceModel? editDevice]) async {
    final nameCtrl = TextEditingController(text: editDevice?.name ?? '');
    final brandCtrl = TextEditingController(
      text: editDevice?.brandOrModel ?? '',
    );
    String selectedType = editDevice?.connectionType ?? 'USB HID';
    bool isDefault = editDevice?.isDefault ?? false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    editDevice != null
                        ? 'Editar Lector'
                        : 'Vincular Nuevo Lector',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asigna un alias descriptivo al escáner para identificar la caja o equipo en el inventario.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nombre / Identificador del Lector',
                        hintText: 'Ej: Pistola Láser Caja Principal',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Conexión',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(
                          Icons.settings_input_hdmi_rounded,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'USB HID',
                          child: Text('USB HID (Cable Plug & Play)'),
                        ),
                        DropdownMenuItem(
                          value: 'Inalámbrico 2.4G',
                          child: Text('Inalámbrico 2.4 GHz (Dongle USB)'),
                        ),
                        DropdownMenuItem(
                          value: 'Bluetooth',
                          child: Text('Bluetooth (HID / SPP)'),
                        ),
                        DropdownMenuItem(
                          value: 'Cámara Integrada',
                          child: Text('Cámara Integrada / Webcam POS'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedType = val);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: brandCtrl,
                      decoration: InputDecoration(
                        labelText: 'Marca o Modelo (Opcional)',
                        hintText: 'Ej: Honeywell 1900G / Zebra DS2208 / Netum',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.devices_other_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Lector Predeterminado',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Usar este equipo por defecto para las ventas y recepción',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      value: isDefault,
                      activeTrackColor: AppColors.teal,
                      onChanged: (val) => setModalState(() => isDefault = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    Navigator.pop(ctx, true);
                  },
                  child: Text(
                    editDevice != null ? 'Guardar Cambios' : 'Vincular Lector',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && nameCtrl.text.trim().isNotEmpty) {
      if (editDevice != null) {
        await BarcodeScannerHardwareService.updateDevice(
          editDevice.copyWith(
            name: nameCtrl.text.trim(),
            connectionType: selectedType,
            brandOrModel:
                brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
            isDefault: isDefault,
          ),
        );
      } else {
        await BarcodeScannerHardwareService.addDevice(
          ScannerDeviceModel(
            id: 'scanner_${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim(),
            connectionType: selectedType,
            brandOrModel:
                brandCtrl.text.trim().isNotEmpty ? brandCtrl.text.trim() : null,
            lastUsedAt: DateTime.now(),
            isDefault: isDefault,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Focus(
      focusNode: _testFocusNode,
      onKeyEvent: (node, event) {
        final code = _testGunDetector.onKeyEvent(event);
        if (code != null) {
          _handleTestScan(code);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        children: [
          // ── 1. Banner Superior de Estado de Conexión ──────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isDark
                        ? [const Color(0xFF0F2B26), const Color(0xFF061A17)]
                        : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF134E4A) : const Color(0xFF86EFAC),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF14532D)
                            : const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.flash_on_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Escáneres y Lectores en Línea',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFF14532D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF22C55E,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HID / PnP Activo',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Las pistolas USB y Bluetooth operan sin configuración ni drivers adicionales. Dispara a cualquier producto en pantalla y el sistema procesará la lectura automáticamente.',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFF166534),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── 2. Lista de Equipos Vinculados / Previamente Conectados ─────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equipos Conectados y Perfiles de Lectores',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Historial de lectores registrados en este equipo o terminal POS',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text(
                  'Registrar Lector',
                  style: TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showAddDeviceDialog(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ValueListenableBuilder<List<ScannerDeviceModel>>(
            valueListenable: BarcodeScannerHardwareService.devicesNotifier,
            builder: (context, devices, _) {
              if (devices.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.darkSurfaceElevated
                            : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'No hay lectores configurados. Registra uno arriba.',
                    ),
                  ),
                );
              }

              return Column(
                children:
                    devices
                        .map((dev) => _buildDeviceCard(dev, isDark))
                        .toList(),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 3. Laboratorio Interactivo de Prueba en Vivo (Live Test Lab) ────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? AppColors.darkSurfaceElevated
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.biotech_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Área de Diagnóstico y Calibración en Vivo',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Apunta y dispara aquí',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Prueba la respuesta de tu pistola de código de barras o escáner móvil. Dispara al código de prueba inferior o a cualquier producto.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),

                // Caja de captura y resultados de diagnóstico
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          _lastTestCode != null
                              ? AppColors.teal
                              : (isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1)),
                      width: _lastTestCode != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              _lastTestCode != null
                                  ? AppColors.teal.withValues(alpha: 0.15)
                                  : Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _lastTestCode != null
                              ? Icons.check_circle_rounded
                              : Icons.barcode_reader,
                          color:
                              _lastTestCode != null
                                  ? AppColors.teal
                                  : Colors.grey,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lastTestCode != null
                                  ? 'Código Leído: $_lastTestCode'
                                  : 'Esperando disparo de pistola o lectura...',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color:
                                    _lastTestCode != null
                                        ? AppColors.tealDark
                                        : AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _lastTestCode != null
                                  ? 'Velocidad: ~$_lastTestSpeedMs ms/carácter · Terminador: Enter · Hora: ${_lastTestTime != null ? '${_lastTestTime!.hour.toString().padLeft(2, '0')}:${_lastTestTime!.minute.toString().padLeft(2, '0')}:${_lastTestTime!.second.toString().padLeft(2, '0')}' : 'Ahora'}'
                                  : 'Haz clic en cualquier parte de esta ventana y aprieta el gatillo.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_lastTestCode != null)
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 14),
                          label: const Text(
                            'Limpiar',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () {
                            setState(() {
                              _lastTestCode = null;
                              _testInputCtrl.clear();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 4. Preferencias Operativas del Escáner ─────────────────────────
          const Text(
            'Comportamiento y Automatizaciones',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          const Text(
            'Personaliza cómo responde el sistema ante cada disparo',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable:
                      BarcodeScannerHardwareService.autoAddNotifier,
                  builder: (context, val, _) {
                    return SwitchListTile(
                      title: const Text(
                        'Adición automática continua (+1 unidad)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'En el POS, Entrada y Órdenes, al disparar con el lector suma +1 directamente al carrito sin abrir cuadros de diálogo.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: val,
                      activeTrackColor: AppColors.teal,
                      onChanged: BarcodeScannerHardwareService.setAutoAdd,
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable:
                      BarcodeScannerHardwareService.soundBeepNotifier,
                  builder: (context, val, _) {
                    return SwitchListTile(
                      title: const Text(
                        'Bip de confirmación acústica (Audio Beep)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Reproduce un tono de confirmación en la bocina del equipo cada vez que el código es decodificado exitosamente.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: val,
                      activeTrackColor: AppColors.teal,
                      onChanged: BarcodeScannerHardwareService.setSoundBeep,
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color:
                      isDark ? AppColors.darkBorder : const Color(0xFFF1F5F9),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: BarcodeScannerHardwareService.hapticNotifier,
                  builder: (context, val, _) {
                    return SwitchListTile(
                      title: const Text(
                        'Vibración háptica al escanear',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Respuesta táctil recomendada para celulares y tablets POS.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      value: val,
                      activeTrackColor: AppColors.teal,
                      onChanged:
                          BarcodeScannerHardwareService.setHapticFeedback,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(ScannerDeviceModel dev, bool isDark) {
    IconData icon;
    Color iconColor;

    switch (dev.connectionType) {
      case 'Bluetooth':
        icon = Icons.bluetooth_rounded;
        iconColor = const Color(0xFF3B82F6);
        break;
      case 'Inalámbrico 2.4G':
        icon = Icons.wifi_tethering_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case 'Cámara Integrada':
        icon = Icons.camera_alt_rounded;
        iconColor = const Color(0xFF8B5CF6);
        break;
      default:
        icon = Icons.usb_rounded;
        iconColor = const Color(0xFFF59E0B);
    }

    final timeStr =
        dev.lastUsedAt != null
            ? 'Último uso: ${dev.lastUsedAt!.day}/${dev.lastUsedAt!.month} ${dev.lastUsedAt!.hour.toString().padLeft(2, '0')}:${dev.lastUsedAt!.minute.toString().padLeft(2, '0')}'
            : 'Sin actividad reciente';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              dev.isDefault
                  ? AppColors.teal
                  : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
          width: dev.isDefault ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      dev.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (dev.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Predeterminado',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${dev.connectionType}${dev.brandOrModel != null ? ' · ${dev.brandOrModel}' : ''}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Editar lector',
            color: AppColors.textMuted,
            onPressed: () => _showAddDeviceDialog(dev),
          ),
          if (!dev.isDefault)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              tooltip: 'Eliminar lector',
              color: AppColors.danger,
              onPressed:
                  () => BarcodeScannerHardwareService.removeDevice(dev.id),
            ),
        ],
      ),
    );
  }
}
