import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/camera_stream_stopper.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/services/variant_disambiguation_helper.dart';

/// Modos de captura disponibles en el visor de cámara del POS
enum PosScannerMode {
  /// Escaneo rápido de códigos de barra (1D) y QR tradicionales
  barcode,

  /// Reconocimiento óptico de caracteres (OCR) para leer etiquetas, marcas y variantes
  ocrLabel,
}

/// Modal interactivo de escaneo por cámara de Códigos de Barra y QR.
///
/// Soporta:
/// - Modo Individual: escanea un producto, lo retorna y se cierra.
/// - Modo Continuo (Ráfaga): mantiene la cámara encendida y añade producto tras
///   producto a la lista/carrito en tiempo real sin interrupciones.
/// - Vista dividida (Split Scanner + Live Cart) estilo retail con HUD reticular.
/// - Apagado garantizado de la cámara al cerrar el modal (libera hardware/webcam).
/// - Linterna, cambio de cámara, entrada manual y búsqueda por título.
/// - Escaneo inteligente OCR de etiquetas y desambiguación automática de variantes.
/// - Linterna, cambio de cámara, entrada manual y búsqueda por título.
class PosCameraScannerDialog extends StatefulWidget {
  final String? warehouseId;
  final String? title;
  final bool continuousMode;
  final FutureOr<dynamic> Function(PosScanResult result)? onContinuousScan;
  final bool returnRawCode;
  final CartCubit? cartCubit;

  const PosCameraScannerDialog({
    super.key,
    this.warehouseId,
    this.title,
    this.continuousMode = false,
    this.onContinuousScan,
    this.returnRawCode = false,
    this.cartCubit,
  });

  /// Abre el modal de escaneo adaptado a la plataforma y garantiza
  /// el apagado total del hardware de la cámara web al salir.
  static Future<PosScanResult?> show(
    BuildContext context, {
    String? warehouseId,
    String? title,
    bool continuousMode = false,
    FutureOr<dynamic> Function(PosScanResult result)? onContinuousScan,
    bool returnRawCode = false,
    CartCubit? cartCubit,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    PosScanResult? result;
    if (isDesktop) {
      result = await showDialog<PosScanResult>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cartCubit != null ? 580 : 520,
                  maxHeight: cartCubit != null ? 760 : 680,
                ),
                child: PosCameraScannerDialog(
                  warehouseId: warehouseId,
                  title: title,
                  continuousMode: continuousMode,
                  onContinuousScan: onContinuousScan,
                  returnRawCode: returnRawCode,
                  cartCubit: cartCubit,
                ),
              ),
            ),
      );
    } else {
      result = await showModalBottomSheet<PosScanResult>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height:
                    MediaQuery.of(context).size.height *
                    (cartCubit != null ? 0.94 : 0.85),
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
                  returnRawCode: returnRawCode,
                  cartCubit: cartCubit,
                ),
              ),
            ),
      );
    }
    // Garantiza el apagado físico del hardware de la cámara (web/móvil)
    stopAllWebCameraStreams();
    return result;
  }

  /// Escanea un código de barras o QR físico directamente y retorna su texto plano (raw code).
  /// Ideal para formularios de alta/edición de productos donde el código aún no existe en BD.
  static Future<String?> showForRawCode(
    BuildContext context, {
    String? title,
  }) async {
    final result = await show(
      context,
      title: title ?? 'Escanear Código de Barras / QR',
      returnRawCode: true,
    );
    return result?.rawCode;
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

  // Estado para Modo OCR y resolución de variantes
  PosScannerMode _scannerMode = PosScannerMode.barcode;
  bool _isOcrProcessing = false;
  ProductOcrMatchResult? _pendingAmbiguousResult;

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
    ProductOcrScannerService.dispose();
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

    if (widget.returnRawCode) {
      HapticFeedback.lightImpact();
      final rawResult = PosScanResult(
        product: ProductEntity(id: '', name: trimmed),
        rawCode: trimmed,
      );
      await _safeClose(rawResult);
      return;
    }

    try {
      final result = await PosBarcodeScannerService.resolveCode(
        trimmed,
        warehouseId: widget.warehouseId,
      );

      if (!mounted || _isClosing) return;

      if (result != null) {
        HapticFeedback.lightImpact();
        SystemSound.play(SystemSoundType.click);

        if (widget.continuousMode || widget.onContinuousScan != null) {
          // Modo Rápido / Continuo: agrega a la lista y se mantiene escaneando
          if (widget.onContinuousScan != null) {
            final scanSuccess = await widget.onContinuousScan!(result);
            if (scanSuccess == false) {
              // Si la operación falló (ej: producto agotado o sin precio), no agregamos ni mostramos feedback falso
              if (mounted) {
                setState(() => _isResolving = false);
              }
              return;
            }
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
        try {
          _scannerController.stop();
        } catch (_) {}
        stopAllWebCameraStreams();
      },
      child:
          widget.cartCubit != null
              ? _buildSplitCartLayout(context)
              : _buildStandardScannerLayout(context),
    );
  }

  /// Vista estándar de pantalla completa cuando solo se requiere escanear un producto
  Widget _buildStandardScannerLayout(BuildContext context) {
    return Scaffold(
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
                // Solo procesar códigos de barra cuando estamos en modo barcode
                if (_scannerMode != PosScannerMode.barcode) return;
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

          // 2. Máscara HUD adaptativa según modo (Códigos vs Etiqueta OCR)
          Positioned.fill(
            child:
                _scannerMode == PosScannerMode.barcode
                    ? _buildCenteredScanHud()
                    : _buildOcrScanHud(isSplit: false),
          ),

          // 3. Barra Superior Flotante con Selector de Modos (Glassmorphism)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: _buildTopControlBar(),
          ),

          // 4. Toast / Banner flotante de detección continua
          if (_lastScannedName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 108,
              left: 16,
              right: 16,
              child: _buildScannedFeedbackBanner(),
            ),

          // 5. Barra Inferior con Entrada Manual y/o Botón "Listo" (solo en modo barcode)
          if (_scannerMode == PosScannerMode.barcode)
            Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomBar()),

          // 6. Selector flotante de variantes si el OCR detectó ambigüedad
          if (_pendingAmbiguousResult != null)
            _buildAmbiguousVariantsSheet(_pendingAmbiguousResult!),

          // 7. Indicador de carga de resolución de código
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

          // 8. Indicador de carga de procesamiento OCR inteligente
          if (_isOcrProcessing) _buildOcrProcessingOverlay(),
        ],
      ),
    );
  }

  /// Vista dividida: Cámara interactiva arriba (~38%) + Carrito en tiempo real abajo
  Widget _buildSplitCartLayout(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final cameraHeight =
        isDesktop
            ? 310.0
            : (MediaQuery.of(context).size.height *
                (_scannerMode == PosScannerMode.ocrLabel ? 0.42 : 0.36));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // 1. Visor de Cámara Superior
            SizedBox(
              height: cameraHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      // Solo procesar códigos de barra cuando estamos en modo barcode
                      if (_scannerMode != PosScannerMode.barcode) return;
                      for (final barcode in capture.barcodes) {
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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.videocam_off_rounded,
                                color: Colors.white70,
                                size: 36,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Cámara no disponible',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                error.errorDetails?.message ??
                                    'Usa el buscador por nombre abajo.',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // HUD adaptado según modo (Códigos vs Etiqueta OCR)
                  Positioned.fill(
                    child:
                        _scannerMode == PosScannerMode.barcode
                            ? _buildCompactScanHud()
                            : _buildOcrScanHud(isSplit: true),
                  ),

                  // Barra superior flotante de controles con selector de modos
                  Positioned(
                    top:
                        MediaQuery.of(context).padding.top > 0
                            ? MediaQuery.of(context).padding.top + 6
                            : 10,
                    left: 12,
                    right: 12,
                    child: _buildTopControlBar(),
                  ),

                  // Pill Banner Toast flotante ("✔ Fideo... agregado (+1)")
                  if (_lastScannedName != null)
                    Positioned(
                      bottom: 10,
                      left: 16,
                      right: 16,
                      child: _buildScannedFeedbackBanner(),
                    ),

                  // Selector flotante de variantes si el OCR detectó ambigüedad
                  if (_pendingAmbiguousResult != null)
                    _buildAmbiguousVariantsSheet(_pendingAmbiguousResult!),

                  // Overlay de búsqueda en proceso
                  if (_isResolving)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.teal,
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),

                  // Overlay de procesamiento OCR inteligente
                  if (_isOcrProcessing) _buildOcrProcessingOverlay(),
                ],
              ),
            ),

            // 2. Panel Interactivo del Carrito en Vivo
            Expanded(child: _buildLiveCartSheet(context)),
          ],
        ),
      ),
    );
  }

  /// Retícula compacta con esquinas verde esmeralda (#10B981) y animación láser
  Widget _buildCompactScanHud() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = (constraints.maxWidth * 0.78).clamp(190.0, 320.0);
        final boxHeight = (constraints.maxHeight * 0.60).clamp(100.0, 160.0);
        final leftOffset = (constraints.maxWidth - boxWidth) / 2;
        final topOffset = (constraints.maxHeight - boxHeight) / 2 + 12;
        final scanRect = Rect.fromLTWH(
          leftOffset,
          topOffset,
          boxWidth,
          boxHeight,
        );

        return Stack(
          children: [
            // 1. Máscara oscura
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 16,
                  overlayColor: Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),

            // 2. Retícula con 4 esquinas destacadas verde esmeralda (#10B981)
            Positioned.fill(
              child: CustomPaint(
                painter: _CornerBracketPainter(
                  scanRect: scanRect,
                  color: const Color(0xFF10B981),
                  cornerLength: 22,
                  strokeWidth: 3.5,
                ),
              ),
            ),

            // 3. Línea láser animada dentro del marco
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: topOffset + (_scanAnimation.value * (boxHeight - 4)),
                  left: leftOffset + 6,
                  width: boxWidth - 12,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 4. Etiqueta instructiva compacta
            Positioned(
              bottom: 6,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Apunta al código de barras o QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
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

  /// Panel inferior del carrito con lista de productos, steppers y botón Cobrar
  Widget _buildLiveCartSheet(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      bloc: widget.cartCubit,
      builder: (context, cartState) {
        final items = cartState.sortedItems;
        final totalAmount = cartState.totalAmount;
        final itemCount = cartState.itemCount;

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Cabecera del Carrito
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: AppColors.teal,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Carrito ($itemCount)',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _openQuickTitleSearchModal(context),
                      icon: const Icon(Icons.search_rounded, size: 16),
                      label: const Text('Buscar por nombre'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Colors.white12, height: 1),

              // Lista de productos o Estado Vacío
              Expanded(
                child:
                    items.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    color: Colors.white38,
                                    size: 38,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Apunta la cámara al producto',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Se agregará automáticamente al carrito.\nTambién puedes buscarlo por su nombre o ingresar su SKU.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          itemCount: items.length,
                          separatorBuilder:
                              (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _buildCartItemTile(item);
                          },
                        ),
              ),

              // Barra de entrada manual compacta
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: TextField(
                          controller: _manualInputCtrl,
                          focusNode: _manualFocusNode,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _onManualSubmit(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1E293B),
                            hintText: 'Ingresar código de barras o SKU...',
                            hintStyle: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            prefixIcon: const Icon(
                              Icons.keyboard_alt_outlined,
                              size: 16,
                              color: AppColors.teal,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 38,
                      child: FilledButton(
                        onPressed: _onManualSubmit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Agregar'),
                      ),
                    ),
                  ],
                ),
              ),

              // Pie con Totales y Botón "Cobrar"
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  border: Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total a Cobrar ($itemCount ${itemCount == 1 ? 'producto' : 'productos'}):',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'S/ ${totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF34D399),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed:
                                items.isEmpty
                                    ? null
                                    : () async {
                                      await _safeClose();
                                      if (context.mounted) {
                                        context.push('/pos-checkout');
                                      }
                                    },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white12,
                              disabledForegroundColor: Colors.white38,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.point_of_sale_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Cobrar S/ ${totalAmount.toStringAsFixed(2)}',
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Fila de producto individual en la lista del carrito con stepper
  Widget _buildCartItemTile(CartItemEntity item) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Imagen / Miniatura del producto
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child:
                item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (context, error, stackTrace) => const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white38,
                            size: 20,
                          ),
                    )
                    : const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.white38,
                      size: 20,
                    ),
          ),
          const SizedBox(width: 10),

          // Título y Precio unitario
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'S/ ${item.unitPrice.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (item.variantLabel != null &&
                        item.variantLabel!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${item.variantLabel})',
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Stepper de Cantidad [-] QTY [+]
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.cartCubit?.updateQuantity(
                      item.cartKey,
                      item.quantity - 1,
                    );
                  },
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      Icons.remove_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '${item.quantity}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.cartCubit?.updateQuantity(
                      item.cartKey,
                      item.quantity + 1,
                    );
                  },
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    child: Icon(
                      Icons.add_rounded,
                      color: AppColors.teal,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Subtotal del ítem
          SizedBox(
            width: 58,
            child: Text(
              'S/ ${item.subtotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF34D399),
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  /// Despliega modal de búsqueda en vivo por título o nombre de producto
  Future<void> _openQuickTitleSearchModal(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (modalCtx) => _QuickProductSearchModal(
            warehouseId: widget.warehouseId,
            onProductSelected: (product) async {
              Navigator.of(modalCtx).pop();
              if (widget.cartCubit != null) {
                await PosBarcodeScannerService.addScanResultToCart(
                  context: context,
                  scanResult: PosScanResult(
                    product: product,
                    variant: product.defaultVariant,
                    rawCode: product.id,
                  ),
                  cartCubit: widget.cartCubit!,
                  warehouseId: widget.warehouseId,
                );
                if (mounted) {
                  setState(() {
                    _lastScannedName = product.name;
                  });
                  _feedbackTimer?.cancel();
                  _feedbackTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() => _lastScannedName = null);
                    }
                  });
                }
              }
            },
          ),
    );
  }

  Widget _buildTopControlBar() {
    final title =
        widget.title ??
        (_scannerMode == PosScannerMode.ocrLabel
            ? 'Reconocer Etiqueta (OCR)'
            : (widget.continuousMode ? 'Escaneo Continuo' : 'Escanear Código'));

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
                icon:
                    _isTorchOn
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
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
        ),
        const SizedBox(height: 6),
        _buildModeSwitcher(),
      ],
    );
  }

  Widget _buildModeSwitcher() {
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
    final isSelected = _scannerMode == mode;
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
          if (_scannerMode == mode) return;
          HapticFeedback.selectionClick();
          setState(() {
            _scannerMode = mode;
            _pendingAmbiguousResult = null;
          });
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

  Future<void> _captureAndScanOcr({bool fromGallery = false}) async {
    if (_isResolving || _isOcrProcessing || _isClosing) return;

    try {
      final picker = ImagePicker();
      final source = fromGallery ? ImageSource.gallery : ImageSource.camera;

      // Pausar temporalmente mobile_scanner para liberar el hardware de cámara nativo
      try {
        await _scannerController.stop();
      } catch (_) {}

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );

      // Reanudar MobileScanner si el widget continúa activo
      if (mounted && !_isClosing) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }

      if (pickedFile == null) return;

      setState(() => _isOcrProcessing = true);
      HapticFeedback.mediumImpact();

      final result = await ProductOcrScannerService.recognizeFromImageFile(
        pickedFile.path,
        warehouseId: widget.warehouseId,
      );

      if (!mounted || _isClosing) return;

      if (result == null) {
        AppSnackbar.show(
          context,
          message:
              'No se reconoció ningún producto en la etiqueta. Intenta enfocar más de cerca el título.',
          type: SnackbarType.warning,
        );
        return;
      }

      // Si se resolvió variante única o el producto tiene una sola variante
      if (result.isDirectMatch && result.variant != null) {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.click);

        final scanResult = PosScanResult(
          product: result.product,
          variant: result.variant,
          rawCode:
              result.variant?.barcode ??
              result.variant?.sku ??
              result.product.id,
        );

        if (widget.cartCubit != null) {
          final added = await PosBarcodeScannerService.addScanResultToCart(
            context: context,
            scanResult: scanResult,
            cartCubit: widget.cartCubit!,
            warehouseId: widget.warehouseId,
          );

          if (added && mounted) {
            final variantLabel =
                result.variant?.shortLabel.isNotEmpty == true
                    ? ' (${result.variant!.shortLabel})'
                    : '';
            setState(() {
              _scannedCount++;
              _lastScannedName = '${result.product.name}$variantLabel';
            });
            _feedbackTimer?.cancel();
            _feedbackTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _lastScannedName = null);
            });
          }
        } else if (widget.continuousMode || widget.onContinuousScan != null) {
          if (widget.onContinuousScan != null) {
            await widget.onContinuousScan!(scanResult);
          }
          if (mounted) {
            setState(() {
              _scannedCount++;
              _lastScannedName = result.product.name;
            });
          }
        } else {
          await _safeClose(scanResult);
        }
      } else {
        // Ambigüedad en variantes: mostrar selector rápido sobre la cámara
        HapticFeedback.mediumImpact();
        setState(() {
          _pendingAmbiguousResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al leer etiqueta: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrProcessing = false);
      }
    }
  }

  Widget _buildOcrScanHud({required bool isSplit}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = (constraints.maxWidth * 0.86).clamp(240.0, 420.0);
        final boxHeight =
            isSplit
                ? (constraints.maxHeight * 0.58).clamp(110.0, 170.0)
                : (constraints.maxHeight * 0.44).clamp(200.0, 310.0);
        final leftOffset = (constraints.maxWidth - boxWidth) / 2;
        final topOffset =
            (constraints.maxHeight - boxHeight) / 2 + (isSplit ? 24 : -10);
        final scanRect = Rect.fromLTWH(
          leftOffset,
          topOffset,
          boxWidth,
          boxHeight,
        );

        return Stack(
          children: [
            // 1. Máscara oscura
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 20,
                  overlayColor: Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),

            // 2. Esquinas destacadas ámbar dorado
            Positioned.fill(
              child: CustomPaint(
                painter: _CornerBracketPainter(
                  scanRect: scanRect,
                  color: const Color(0xFFF59E0B),
                  cornerLength: 26,
                  strokeWidth: 3.5,
                ),
              ),
            ),

            // 3. Indicador de texto instructivo dentro del marco
            Positioned(
              top: topOffset + 10,
              left: leftOffset + 12,
              right: leftOffset + 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Enfoca el nombre y presentación del producto',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Botón de captura flotante
            Positioned(
              bottom: isSplit ? 6 : 80,
              left: 20,
              right: 20,
              child: Center(child: _buildOcrCaptureButton(isSplit: isSplit)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOcrCaptureButton({required bool isSplit}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed:
                _isOcrProcessing
                    ? null
                    : () => _captureAndScanOcr(fromGallery: false),
            icon:
                _isOcrProcessing
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(
              _isOcrProcessing ? 'Leyendo...' : 'Capturar y Leer Etiqueta',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: const Color(0xFF0F172A),
              padding: EdgeInsets.symmetric(
                horizontal: isSplit ? 14 : 20,
                vertical: isSplit ? 8 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Cargar foto de galería',
          child: Material(
            color: Colors.black.withValues(alpha: 0.65),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap:
                  _isOcrProcessing
                      ? null
                      : () => _captureAndScanOcr(fromGallery: true),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmbiguousVariantsSheet(ProductOcrMatchResult result) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        result.detectedPresentation != null
                            ? 'Detectado: "${result.detectedPresentation}". Elige presentación:'
                            : 'Selecciona la presentación detectada:',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed:
                      () => setState(() => _pendingAmbiguousResult = null),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  result.candidateVariants.map((variant) {
                    final label =
                        variant.shortLabel.isNotEmpty
                            ? variant.shortLabel
                            : variant.label;
                    final price =
                        variant.salePrice != null
                            ? 'S/ ${variant.salePrice!.toStringAsFixed(2)}'
                            : '';
                    final isSuggested =
                        result.detectedPresentation != null &&
                        VariantDisambiguationHelper.normalize(label).contains(
                          VariantDisambiguationHelper.normalize(
                            result.detectedPresentation!,
                          ),
                        );

                    return InkWell(
                      onTap: () async {
                        final scanResult = PosScanResult(
                          product: result.product,
                          variant: variant,
                          rawCode:
                              variant.barcode ??
                              variant.sku ??
                              result.product.id,
                        );
                        setState(() => _pendingAmbiguousResult = null);

                        if (widget.cartCubit != null) {
                          await PosBarcodeScannerService.addScanResultToCart(
                            context: context,
                            scanResult: scanResult,
                            cartCubit: widget.cartCubit!,
                            warehouseId: widget.warehouseId,
                          );
                          if (mounted) {
                            setState(() {
                              _scannedCount++;
                              _lastScannedName =
                                  '${result.product.name} ($label)';
                            });
                            _feedbackTimer?.cancel();
                            _feedbackTimer = Timer(
                              const Duration(seconds: 4),
                              () {
                                if (mounted) {
                                  setState(() => _lastScannedName = null);
                                }
                              },
                            );
                          }
                        } else if (widget.continuousMode ||
                            widget.onContinuousScan != null) {
                          if (widget.onContinuousScan != null) {
                            await widget.onContinuousScan!(scanResult);
                          }
                          if (mounted) {
                            setState(() {
                              _scannedCount++;
                              _lastScannedName =
                                  '${result.product.name} ($label)';
                            });
                          }
                        } else {
                          await _safeClose(scanResult);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSuggested
                                  ? const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSuggested
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white24,
                            width: isSuggested ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSuggested) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF59E0B),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color:
                                    isSuggested
                                        ? const Color(0xFFFDE68A)
                                        : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOcrProcessingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFF59E0B),
                strokeWidth: 3.5,
              ),
              SizedBox(height: 16),
              Text(
                'Leyendo texto de etiqueta con IA...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Reconociendo marca, título y variantes',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
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
        final leftOffset = (constraints.maxWidth - boxSize) / 2;
        final topOffset = (constraints.maxHeight - boxSize) / 2 - 20;
        final scanRect = Rect.fromLTWH(leftOffset, topOffset, boxSize, boxSize);

        return Stack(
          children: [
            // 1. Máscara oscura limpia mediante CustomPainter (sin BlendModes destructivos)
            Positioned.fill(
              child: CustomPaint(
                painter: _ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 22,
                  overlayColor: Colors.black.withValues(alpha: 0.58),
                ),
              ),
            ),

            // 2. Marco con esquinas redondeadas color Neón Teal
            Positioned(
              top: topOffset,
              left: leftOffset,
              width: boxSize,
              height: boxSize,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.95),
                    width: 2.5,
                  ),
                ),
              ),
            ),

            // 3. Línea láser animada
            AnimatedBuilder(
              animation: _scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: topOffset + (_scanAnimation.value * (boxSize - 4)),
                  left: leftOffset + 8,
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

/// Dibuja una máscara oscura sobre la pantalla excluyendo la ventana de escaneo,
/// calculada mediante geometría de trazados vectoriales (Path.combine con PathOperation.difference).
///
/// Esto previene el bug de Flutter Web CanvasKit donde `BlendMode.srcOut` / `BlendMode.dstOut`
/// borran el canal alfa del canvas y dejan traslúcido el contenido del fondo (pantallas previas).
class _ScannerOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;

  const _ScannerOverlayPainter({
    required this.scanWindow,
    required this.borderRadius,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Usamos PathFillType.evenOdd para vaciar el marco central sin costosas
    // operaciones booleanas (Path.combine), evitando glitches de renderizado en Flutter Web/CanvasKit.
    final path =
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
          ..addRRect(
            RRect.fromRectAndRadius(scanWindow, Radius.circular(borderRadius)),
          );

    final paint =
        Paint()
          ..color = overlayColor
          ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// Dibuja 4 esquinas destacadas (corner brackets) alrededor del rectángulo de escaneo.
class _CornerBracketPainter extends CustomPainter {
  final Rect scanRect;
  final Color color;
  final double cornerLength;
  final double strokeWidth;

  const _CornerBracketPainter({
    required this.scanRect,
    this.color = const Color(0xFF10B981),
    this.cornerLength = 24.0,
    this.strokeWidth = 3.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final l = scanRect.left;
    final t = scanRect.top;
    final r = scanRect.right;
    final b = scanRect.bottom;
    final cl = cornerLength;

    final path =
        Path()
          // Top-left
          ..moveTo(l, t + cl)
          ..lineTo(l, t)
          ..lineTo(l + cl, t)
          // Top-right
          ..moveTo(r - cl, t)
          ..lineTo(r, t)
          ..lineTo(r, t + cl)
          // Bottom-right
          ..moveTo(r, b - cl)
          ..lineTo(r, b)
          ..lineTo(r - cl, b)
          // Bottom-left
          ..moveTo(l + cl, b)
          ..lineTo(l, b)
          ..lineTo(l, b - cl);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) {
    return oldDelegate.scanRect != scanRect ||
        oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Modal rápido para buscar productos por nombre o SKU e insertarlos al carrito.
class _QuickProductSearchModal extends StatefulWidget {
  final String? warehouseId;
  final ValueChanged<ProductEntity> onProductSelected;

  const _QuickProductSearchModal({
    required this.warehouseId,
    required this.onProductSelected,
  });

  @override
  State<_QuickProductSearchModal> createState() =>
      _QuickProductSearchModalState();
}

class _QuickProductSearchModalState extends State<_QuickProductSearchModal> {
  final _searchCtrl = TextEditingController();
  List<ProductEntity> _products = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _performSearch('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final repo = sl<ProductsRepository>();
      final res = await repo.getProducts(
        searchQuery: query.trim().isEmpty ? null : query.trim(),
        limit: 25,
        isActive: true,
      );
      if (!mounted) return;
      res.fold(
        (failure) => setState(() => _products = []),
        (data) => setState(() => _products = data.products),
      );
    } catch (_) {
      if (mounted) setState(() => _products = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.manage_search_rounded,
                  color: AppColors.teal,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Buscar Producto por Nombre o SKU',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'Escribe ej: Arroz, Fideo, Aceite, Leche...',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
                suffixIcon:
                    _searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            _performSearch('');
                          },
                        )
                        : null,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.teal,
                        strokeWidth: 2.5,
                      ),
                    )
                    : _products.isEmpty
                    ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchCtrl.text.isEmpty
                              ? 'No hay productos disponibles.'
                              : 'No se encontraron productos para "${_searchCtrl.text}".',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _products.length,
                      separatorBuilder:
                          (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final price = product.displaySalePrice ?? 0.0;
                        return InkWell(
                          onTap: () => widget.onProductSelected(product),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child:
                                      product.primaryImageUrl != null
                                          ? Image.network(
                                            product.primaryImageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    const Icon(
                                                      Icons
                                                          .inventory_2_outlined,
                                                      color: Colors.white38,
                                                      size: 20,
                                                    ),
                                          )
                                          : const Icon(
                                            Icons.inventory_2_outlined,
                                            color: Colors.white38,
                                            size: 20,
                                          ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            'S/ ${price.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Color(0xFF34D399),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (product.brandName != null &&
                                              product
                                                  .brandName!
                                                  .isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              product.brandName!,
                                              style: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 11.5,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                FilledButton(
                                  onPressed:
                                      () => widget.onProductSelected(product),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.teal,
                                    foregroundColor: const Color(0xFF0F172A),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  child: const Text('+ Agregar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}
