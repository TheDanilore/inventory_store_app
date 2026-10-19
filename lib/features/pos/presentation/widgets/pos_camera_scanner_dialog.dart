import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/camera_stream_stopper.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';

/// Modal interactivo de escaneo por cámara de Códigos de Barra y QR.
///
/// Soporta:
/// - Modo Individual: escanea un producto, lo retorna y se cierra.
/// - Modo Continuo (Ráfaga): mantiene la cámara encendida y añade producto tras
///   producto a la lista/carrito en tiempo real sin interrupciones.
/// - Apagado garantizado de la cámara al cerrar el modal (libera hardware/webcam).
/// - Visor HUD centrado con esquinas iluminadas, máscara translúcida y haz láser.
/// - Linterna, cambio de cámara y entrada manual integrada.
class PosCameraScannerDialog extends StatefulWidget {
  final String? warehouseId;
  final String? title;
  final bool continuousMode;
  final Future<void> Function(PosScanResult result)? onContinuousScan;

  const PosCameraScannerDialog({
    super.key,
    this.warehouseId,
    this.title,
    this.continuousMode = false,
    this.onContinuousScan,
  });

  /// Abre el modal de escaneo adaptado a la plataforma y garantiza
  /// el apagado total del hardware de la cámara web al salir.
  static Future<PosScanResult?> show(
    BuildContext context, {
    String? warehouseId,
    String? title,
    bool continuousMode = false,
    Future<void> Function(PosScanResult result)? onContinuousScan,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    PosScanResult? result;
    if (isDesktop) {
      result = await showDialog<PosScanResult>(
        context: context,
        barrierDismissible: true,
        builder:
            (_) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                  maxHeight: 680,
                ),
                child: PosCameraScannerDialog(
                  warehouseId: warehouseId,
                  title: title,
                  continuousMode: continuousMode,
                  onContinuousScan: onContinuousScan,
                ),
              ),
            ),
      );
    } else {
      result = await showModalBottomSheet<PosScanResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: PosCameraScannerDialog(
                  warehouseId: warehouseId,
                  title: title,
                  continuousMode: continuousMode,
                  onContinuousScan: onContinuousScan,
                ),
              ),
            ),
      );
    }
    // Garantiza el apagado físico del hardware de la cámara (web/móvil)
    stopAllWebCameraStreams();
    return result;
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
  bool _isClosing = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  // Estado para modo continuo
  int _scannedCount = 0;
  String? _lastScannedName;
  Timer? _feedbackTimer;
  DateTime _lastDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastRawCode = '';

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

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _feedbackTimer?.cancel();
    try {
      _scannerController.stop();
      _scannerController.dispose();
    } catch (_) {}
    stopAllWebCameraStreams();
    _manualInputCtrl.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  /// Cierra el diálogo y garantiza el apagado del hardware de cámara
  Future<void> _safeClose([PosScanResult? result]) async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      await _scannerController.stop();
    } catch (_) {}
    stopAllWebCameraStreams();

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _handleBarcodeDetected(String rawCode) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty || _isResolving || _isClosing) return;

    // Evitar lecturas duplicadas en ráfaga del mismo código en menos de 1.2 segundos
    final now = DateTime.now();
    if (trimmed == _lastRawCode &&
        now.difference(_lastDetectionTime).inMilliseconds < 1300) {
      return;
    }

    _lastRawCode = trimmed;
    _lastDetectionTime = now;

    setState(() => _isResolving = true);
    HapticFeedback.mediumImpact();

    try {
      final result = await PosBarcodeScannerService.resolveCode(
        trimmed,
        warehouseId: widget.warehouseId,
      );

      if (!mounted || _isClosing) return;

      if (result != null) {
        HapticFeedback.lightImpact();

        if (widget.continuousMode || widget.onContinuousScan != null) {
          // Modo Rápido / Continuo: agrega a la lista y se mantiene escaneando
          if (widget.onContinuousScan != null) {
            await widget.onContinuousScan!(result);
          }

          if (mounted) {
            setState(() {
              _scannedCount++;
              _lastScannedName = result.product.name;
              _isResolving = false;
            });

            _feedbackTimer?.cancel();
            _feedbackTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _lastScannedName = null);
              }
            });
          }
        } else {
          // Modo Individual: detiene cámara y retorna el resultado
          await _safeClose(result);
        }
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se encontró producto para el código "$trimmed"',
            type: SnackbarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al buscar código: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted && !_isClosing) {
        setState(() => _isResolving = false);
      }
    }
  }

  void _onManualSubmit() {
    final code = _manualInputCtrl.text.trim();
    if (code.isNotEmpty) {
      _manualInputCtrl.clear();
      _handleBarcodeDetected(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Asegura apagar el stream de cámara en Web/Móvil si se cierra por back o tap exterior
        try {
          _scannerController.stop();
        } catch (_) {}
        stopAllWebCameraStreams();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Visor de la cámara con tamaño expansivo
            Positioned.fill(
              child: MobileScanner(
                controller: _scannerController,
                fit: BoxFit.cover,
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
            ),

            // 2. Máscara HUD oscura y Marco de Escaneo Centralizado
            Positioned.fill(child: _buildCenteredScanHud()),

            // 3. Barra Superior Flotante (Glassmorphism)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 12,
              right: 12,
              child: _buildTopControlBar(),
            ),

            // 4. Toast / Banner flotante de detección continua
            if (_lastScannedName != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 64,
                left: 16,
                right: 16,
                child: _buildScannedFeedbackBanner(),
              ),

            // 5. Barra Inferior con Entrada Manual y/o Botón "Listo"
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),

            // 6. Indicador de carga de resolución
            if (_isResolving)
              Positioned.fill(
                child: Container(
                  color: Colors.black45,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.teal,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Buscando código...',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopControlBar() {
    final title =
        widget.title ??
        (widget.continuousMode ? 'Escaneo Continuo' : 'Escanear Código');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          _buildCircleAction(
            icon: Icons.close_rounded,
            tooltip: 'Cerrar escáner',
            onPressed: () => _safeClose(),
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
            icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            tooltip: 'Linterna',
            isActive: _isTorchOn,
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          const SizedBox(width: 6),
          _buildCircleAction(
            icon: Icons.flip_camera_ios_rounded,
            tooltip: 'Cambiar cámara',
            onPressed: () async {
              await _scannerController.switchCamera();
              setState(() {
                _cameraFacing =
                    _cameraFacing == CameraFacing.back
                        ? CameraFacing.front
                        : CameraFacing.back;
              });
            },
          ),
        ],
      ),
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

  Widget _buildScannedFeedbackBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '¡Agregado a la lista (+1)!',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  _lastScannedName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredScanHud() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.70).clamp(210.0, 300.0);
        final topOffset = (constraints.maxHeight - boxSize) / 2 - 20;

        return Stack(
          children: [
            // Máscara oscura recortada con orificio central
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.55),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Positioned(
                    top: topOffset,
                    left: (constraints.maxWidth - boxSize) / 2,
                    width: boxSize,
                    height: boxSize,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Marco con esquinas redondeadas color Neón Teal
            Positioned(
              top: topOffset,
              left: (constraints.maxWidth - boxSize) / 2,
              width: boxSize,
              height: boxSize,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.9),
                    width: 2.5,
                  ),
                ),
              ),
            ),

            // Línea láser animada
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: topOffset + (_scanAnimation.value * (boxSize - 4)),
                  left: (constraints.maxWidth - boxSize) / 2 + 8,
                  width: boxSize - 16,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.9),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Texto instructivo debajo del marco
            Positioned(
              top: topOffset + boxSize + 16,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 15,
                        color: AppColors.teal,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Apunta al código de barras o QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final isContinuous =
        widget.continuousMode || widget.onContinuousScan != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        14,
        16,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isContinuous) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.teal,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_scannedCount escaneados',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _safeClose(),
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Listo / Salir'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],

          // Campo de entrada manual de código con fondo blanco y texto oscuro nítido
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _manualInputCtrl,
                    focusNode: _manualFocusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _onManualSubmit(),
                    cursorColor: AppColors.primary,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(
                        0xFF0F172A,
                      ), // Texto oscuro de alto contraste
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Ingresar SKU o código manual...',
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.keyboard_alt_outlined,
                        size: 19,
                        color: AppColors.primary,
                      ),
                      suffixIcon:
                          _manualInputCtrl.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(
                                  Icons.cancel_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                onPressed: () {
                                  _manualInputCtrl.clear();
                                  setState(() {});
                                },
                              )
                              : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.teal,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    _manualInputCtrl.text.trim().isEmpty || _isResolving
                        ? null
                        : _onManualSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: const Color(0xFF0F172A),
                  disabledBackgroundColor: Colors.white12,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(0, 44),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
                child: const Text('Buscar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
