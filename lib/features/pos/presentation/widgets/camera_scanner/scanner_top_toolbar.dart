import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

/// Barra superior flotante de controles y selector de modo para el escáner POS
class ScannerTopToolbar extends StatelessWidget {
  final String title;
  final bool isTorchOn;
  final CameraFacing cameraFacing;
  final PosScannerMode scannerMode;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final ValueChanged<PosScannerMode> onModeChanged;

  const ScannerTopToolbar({
    super.key,
    required this.title,
    required this.isTorchOn,
    required this.cameraFacing,
    required this.scannerMode,
    required this.onClose,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              _buildCircleAction(
                icon: Icons.close_rounded,
                tooltip: 'Cerrar escáner',
                onPressed: onClose,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildCircleAction(
                icon:
                    isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                tooltip: 'Linterna',
                isActive: isTorchOn,
                onPressed: onToggleTorch,
              ),
              const SizedBox(width: 6),
              _buildCircleAction(
                icon: Icons.flip_camera_ios_rounded,
                tooltip: 'Cambiar cámara',
                onPressed: onSwitchCamera,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        ScannerModeSwitcher(
          currentMode: scannerMode,
          onModeChanged: onModeChanged,
        ),
      ],
    );
  }

  Widget _buildCircleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive ? AppColors.teal : Colors.white.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              color: isActive ? Colors.black : Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

/// Selector de pestañas para cambiar entre escáner de códigos de barra y OCR
class ScannerModeSwitcher extends StatelessWidget {
  final PosScannerMode currentMode;
  final ValueChanged<PosScannerMode> onModeChanged;

  const ScannerModeSwitcher({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab(
            mode: PosScannerMode.barcode,
            icon: Icons.qr_code_scanner_rounded,
            label: 'Código de Barras / QR',
          ),
          const SizedBox(width: 4),
          _buildModeTab(
            mode: PosScannerMode.ocrLabel,
            icon: Icons.document_scanner_rounded,
            label: 'Leer Etiqueta (OCR)',
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required PosScannerMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentMode == mode;
    final activeColor =
        mode == PosScannerMode.ocrLabel
            ? const Color(0xFFF59E0B)
            : AppColors.teal;

    return Material(
      color:
          isSelected ? activeColor.withValues(alpha: 0.22) : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          if (currentMode == mode) return;
          AppFeedbackService.selectionClick();
          onModeChanged(mode);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                isSelected
                    ? Border.all(
                      color: activeColor.withValues(alpha: 0.8),
                      width: 1.2,
                    )
                    : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra superior visible cuando el teclado está abierto y la cámara se colapsa
class ScannerKeyboardHeader extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onHideKeyboard;

  const ScannerKeyboardHeader({
    super.key,
    required this.onClose,
    required this.onHideKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.of(context).padding.top > 0
            ? MediaQuery.of(context).padding.top + 6
            : 10,
        16,
        10,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          Tooltip(
            message: 'Cerrar escáner',
            child: Material(
              color: Colors.white.withValues(alpha: 0.15),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ingreso Manual / Búsqueda',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  'Escribe el código o SKU y presiona Agregar',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onHideKeyboard,
            icon: const Icon(
              Icons.keyboard_hide_rounded,
              color: AppColors.teal,
            ),
            tooltip: 'Ocultar teclado y ver cámara',
          ),
        ],
      ),
    );
  }
}
