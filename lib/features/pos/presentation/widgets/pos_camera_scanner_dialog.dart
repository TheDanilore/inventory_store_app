import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';

/// Modal interactivo de escaneo por cámara de Códigos de Barra y QR para POS.
///
/// Soporta:
/// - Cámara en vivo con visor centrado y animación de escaneo.
/// - Linterna (torch) y cambio de cámara frontal/trasera.
/// - Entrada manual de código como fallback accesible.
/// - Detección y resolución inmediata de producto/variante con feedback háptico.
class PosCameraScannerDialog extends StatefulWidget {
  final String? warehouseId;

  const PosCameraScannerDialog({
    super.key,
    this.warehouseId,
  });

  /// Abre el modal de escaneo adaptado a la plataforma.
  static Future<PosScanResult?> show(
    BuildContext context, {
    String? warehouseId,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    if (isDesktop) {
      return showDialog<PosScanResult>(
        context: context,
        barrierDismissible: true,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
            child: PosCameraScannerDialog(warehouseId: warehouseId),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<PosScanResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            clipBehavior: Clip.antiAlias,
            child: PosCameraScannerDialog(warehouseId: warehouseId),
          ),
        ),
      );
    }
  }

  @override
  State<PosCameraScannerDialog> createState() => _PosCameraScannerDialogState();
}

class _PosCameraScannerDialogState extends State<PosCameraScannerDialog>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  final _manualInputCtrl = TextEditingController();
  final _manualFocusNode = FocusNode();

  bool _isResolving = false;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _cameraFacing,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    _manualInputCtrl.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleBarcodeDetected(String rawCode) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty || _isResolving) return;

    setState(() => _isResolving = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await PosBarcodeScannerService.resolveCode(
        trimmed,
        warehouseId: widget.warehouseId,
      );

      if (!mounted) return;

      if (result != null) {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop(result);
      } else {
        AppSnackbar.show(
          context,
          message: 'No se encontró ningún producto con el código "$trimmed"',
          type: SnackbarType.warning,
        );
        // Esperamos un breve periodo antes de permitir un nuevo intento
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al buscar producto: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  void _onManualSubmit() {
    final code = _manualInputCtrl.text.trim();
    if (code.isNotEmpty) {
      _handleBarcodeDetected(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Visor de la cámara
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  _handleBarcodeDetected(rawValue);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white70,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cámara no disponible o sin permisos',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ??
                            'Puedes ingresar el código manualmente abajo.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Overlay Oscurecido con marco de escaneo central
          _buildScanFrameOverlay(),

          // 3. Barra Superior con Controles (Cerrar, Linterna, Cambiar Cámara)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                _buildCircularButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cerrar escáner',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _buildCircularButton(
                  icon: _isTorchOn
                      ? Icons.flash_on_rounded
                      : Icons.flash_off_rounded,
                  tooltip: 'Linterna',
                  isActive: _isTorchOn,
                  onPressed: () async {
                    await _scannerController.toggleTorch();
                    setState(() => _isTorchOn = !_isTorchOn);
                  },
                ),
                const SizedBox(width: 8),
                _buildCircularButton(
                  icon: Icons.flip_camera_ios_rounded,
                  tooltip: 'Cambiar cámara',
                  onPressed: () async {
                    await _scannerController.switchCamera();
                    setState(() {
                      _cameraFacing = _cameraFacing == CameraFacing.back
                          ? CameraFacing.front
                          : CameraFacing.back;
                    });
                  },
                ),
              ],
            ),
          ),

          // 4. Barra Inferior con Entrada Manual de Código
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomManualInput(),
          ),

          // 5. Indicador de carga de resolución
          if (_isResolving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.teal,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Buscando producto...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isActive
            ? AppColors.primary
            : Colors.black.withValues(alpha: 0.5),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildScanFrameOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.maxWidth * 0.70;
        final clampedBox = boxSize.clamp(200.0, 300.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Marco guía
            Container(
              width: clampedBox,
              height: clampedBox,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.teal,
                  width: 2.5,
                ),
              ),
            ),

            // Línea láser animada de escaneo
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: (constraints.maxHeight - clampedBox) / 2 +
                      (_scanAnimation.value * clampedBox),
                  child: Container(
                    width: clampedBox - 20,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Texto instructivo flotante
            Positioned(
              top: (constraints.maxHeight + clampedBox) / 2 + 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: AppColors.teal,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Apunta a un código de barras o QR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomManualInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '¿No puedes escanear? Ingresa el código:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: _manualInputCtrl,
                    focusNode: _manualFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onManualSubmit(),
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'SKU, código de barras o ID...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      prefixIcon: const Icon(
                        Icons.barcode_reader,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _manualInputCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _manualInputCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _manualInputCtrl.text.trim().isEmpty || _isResolving
                    ? null
                    : _onManualSubmit,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text(
                  'Buscar',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  minimumSize: const Size(0, 42),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
