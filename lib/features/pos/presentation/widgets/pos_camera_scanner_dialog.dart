import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/utils/camera_stream_stopper.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';

import 'camera_scanner/quick_product_search_sheet.dart';
import 'camera_scanner/ocr_variants_sheet.dart';
import 'camera_scanner/scanner_hud_overlays.dart';
import 'camera_scanner/scanner_live_cart_panel.dart';
import 'camera_scanner/scanner_top_toolbar.dart';

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
        builder: (sheetCtx) {
          final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
          final screenHeight = MediaQuery.of(sheetCtx).size.height;
          final baseHeight = screenHeight * (cartCubit != null ? 0.94 : 0.85);
          final sheetHeight =
              bottomInset > 0
                  ? (screenHeight - bottomInset).clamp(320.0, baseHeight)
                  : baseHeight;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              height: sheetHeight,
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
          );
        },
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

    // Evitar lecturas duplicadas en ráfaga del mismo código en menos de 1.3 segundos
    final now = DateTime.now();
    if (trimmed == _lastRawCode &&
        now.difference(_lastDetectionTime).inMilliseconds < 1300) {
      return;
    }

    _lastRawCode = trimmed;
    _lastDetectionTime = now;

    setState(() => _isResolving = true);
    AppFeedbackService.mediumImpact();

    if (widget.returnRawCode) {
      AppFeedbackService.lightImpact();
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
        AppFeedbackService.triggerFeedback();

        if (widget.continuousMode || widget.onContinuousScan != null) {
          // Modo Rápido / Continuo: agrega a la lista y se mantiene escaneando
          if (widget.onContinuousScan != null) {
            final scanSuccess = await widget.onContinuousScan!(result);
            if (scanSuccess == false) {
              if (mounted) setState(() => _isResolving = false);
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

  Future<void> _captureAndScanOcr({bool fromGallery = false}) async {
    if (_isResolving || _isOcrProcessing || _isClosing) return;

    try {
      final picker = ImagePicker();
      final source = fromGallery ? ImageSource.gallery : ImageSource.camera;

      try {
        await _scannerController.stop();
      } catch (_) {}

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );

      if (mounted && !_isClosing) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }

      if (pickedFile == null) return;

      setState(() => _isOcrProcessing = true);
      AppFeedbackService.mediumImpact();

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

      if (result.isDirectMatch && result.variant != null) {
        AppFeedbackService.triggerFeedback();

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
            showSnackbar: false,
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
        AppFeedbackService.mediumImpact();
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

  Future<void> _openQuickTitleSearchModal(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (modalCtx) => QuickProductSearchSheet(
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
                  showSnackbar: false,
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
    final title =
        widget.title ??
        (_scannerMode == PosScannerMode.ocrLabel
            ? 'Reconocer Etiqueta (OCR)'
            : (widget.continuousMode ? 'Escaneo Continuo' : 'Escanear Código'));

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Visor de la cámara
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: (capture) {
                if (_scannerMode != PosScannerMode.barcode) return;
                for (final barcode in capture.barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    _handleBarcodeDetected(rawValue);
                    break;
                  }
                }
              },
              errorBuilder:
                  (context, error) => CameraErrorView(
                    errorMessage: error.errorDetails?.message,
                  ),
            ),
          ),

          // 2. Máscara HUD adaptativa según modo
          Positioned.fill(
            child:
                _scannerMode == PosScannerMode.barcode
                    ? CenteredScanHud(scanAnimation: _scanAnimation)
                    : OcrScanHud(
                      isSplit: false,
                      isOcrProcessing: _isOcrProcessing,
                      onCaptureCamera:
                          () => _captureAndScanOcr(fromGallery: false),
                      onPickGallery:
                          () => _captureAndScanOcr(fromGallery: true),
                    ),
          ),

          // 3. Barra Superior Flotante con Selector de Modos
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: ScannerTopToolbar(
              title: title,
              isTorchOn: _isTorchOn,
              cameraFacing: _cameraFacing,
              scannerMode: _scannerMode,
              onClose: () => _safeClose(),
              onToggleTorch: () async {
                await _scannerController.toggleTorch();
                setState(() => _isTorchOn = !_isTorchOn);
              },
              onSwitchCamera: () async {
                await _scannerController.switchCamera();
                setState(() {
                  _cameraFacing =
                      _cameraFacing == CameraFacing.back
                          ? CameraFacing.front
                          : CameraFacing.back;
                });
              },
              onModeChanged: (mode) {
                setState(() {
                  _scannerMode = mode;
                  _pendingAmbiguousResult = null;
                });
              },
            ),
          ),

          // 4. Banner flotante de confirmación continua
          if (_lastScannedName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 108,
              left: 16,
              right: 16,
              child: ScannedFeedbackBanner(
                productName: _lastScannedName!,
                onDismiss: () => setState(() => _lastScannedName = null),
              ),
            ),

          // 5. Barra Inferior con Entrada Manual (solo en modo barcode)
          if (_scannerMode == PosScannerMode.barcode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStandardBottomBar(),
            ),

          // 6. Selector flotante de variantes si el OCR detectó ambigüedad
          if (_pendingAmbiguousResult != null)
            OcrVariantsSheet(
              result: _pendingAmbiguousResult!,
              onClose: () => setState(() => _pendingAmbiguousResult = null),
              onVariantSelected: (variant) async {
                final match = _pendingAmbiguousResult!;
                final scanResult = PosScanResult(
                  product: match.product,
                  variant: variant,
                  rawCode: variant.barcode ?? variant.sku ?? match.product.id,
                );
                setState(() => _pendingAmbiguousResult = null);

                if (widget.continuousMode || widget.onContinuousScan != null) {
                  if (widget.onContinuousScan != null) {
                    await widget.onContinuousScan!(scanResult);
                  }
                  if (mounted) {
                    setState(() {
                      _scannedCount++;
                      _lastScannedName =
                          '${match.product.name} (${variant.label})';
                    });
                  }
                } else {
                  await _safeClose(scanResult);
                }
              },
            ),

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

          // 8. Indicador de carga OCR
          if (_isOcrProcessing) const OcrProcessingOverlay(),
        ],
      ),
    );
  }

  /// Vista dividida: Cámara interactiva arriba (~38%) + Carrito en tiempo real abajo
  Widget _buildSplitCartLayout(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 80;
    final defaultCameraHeight =
        isDesktop
            ? 310.0
            : (MediaQuery.of(context).size.height *
                (_scannerMode == PosScannerMode.ocrLabel ? 0.42 : 0.36));
    final cameraHeight = isKeyboardOpen ? 0.0 : defaultCameraHeight;
    final title =
        widget.title ??
        (_scannerMode == PosScannerMode.ocrLabel
            ? 'Reconocer Etiqueta (OCR)'
            : (widget.continuousMode ? 'Escaneo Continuo' : 'Escanear Código'));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            // Barra compacta cuando el teclado está abierto
            if (isKeyboardOpen)
              ScannerKeyboardHeader(
                onClose: () => _safeClose(),
                onHideKeyboard: () => FocusScope.of(context).unfocus(),
              ),

            // Visor de Cámara Superior con colapso animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: cameraHeight,
              child: ClipRect(
                child:
                    cameraHeight == 0.0
                        ? const SizedBox.shrink()
                        : Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              fit: BoxFit.cover,
                              onDetect: (capture) {
                                if (_scannerMode != PosScannerMode.barcode) {
                                  return;
                                }
                                for (final barcode in capture.barcodes) {
                                  final rawValue = barcode.rawValue;
                                  if (rawValue != null && rawValue.isNotEmpty) {
                                    _handleBarcodeDetected(rawValue);
                                    break;
                                  }
                                }
                              },
                              errorBuilder:
                                  (context, error) => CameraErrorView(
                                    errorMessage: error.errorDetails?.message,
                                  ),
                            ),

                            // HUD adaptado según modo
                            Positioned.fill(
                              child:
                                  _scannerMode == PosScannerMode.barcode
                                      ? CompactScanHud(
                                        scanAnimation: _scanAnimation,
                                      )
                                      : OcrScanHud(
                                        isSplit: true,
                                        isOcrProcessing: _isOcrProcessing,
                                        onCaptureCamera:
                                            () => _captureAndScanOcr(
                                              fromGallery: false,
                                            ),
                                        onPickGallery:
                                            () => _captureAndScanOcr(
                                              fromGallery: true,
                                            ),
                                      ),
                            ),

                            // Barra superior flotante de controles
                            Positioned(
                              top:
                                  MediaQuery.of(context).padding.top > 0
                                      ? MediaQuery.of(context).padding.top + 6
                                      : 10,
                              left: 12,
                              right: 12,
                              child: ScannerTopToolbar(
                                title: title,
                                isTorchOn: _isTorchOn,
                                cameraFacing: _cameraFacing,
                                scannerMode: _scannerMode,
                                onClose: () => _safeClose(),
                                onToggleTorch: () async {
                                  await _scannerController.toggleTorch();
                                  setState(() => _isTorchOn = !_isTorchOn);
                                },
                                onSwitchCamera: () async {
                                  await _scannerController.switchCamera();
                                  setState(() {
                                    _cameraFacing =
                                        _cameraFacing == CameraFacing.back
                                            ? CameraFacing.front
                                            : CameraFacing.back;
                                  });
                                },
                                onModeChanged: (mode) {
                                  setState(() {
                                    _scannerMode = mode;
                                    _pendingAmbiguousResult = null;
                                  });
                                },
                              ),
                            ),

                            // Pill Banner Toast flotante
                            if (_lastScannedName != null)
                              Positioned(
                                bottom: 10,
                                left: 16,
                                right: 16,
                                child: ScannedFeedbackBanner(
                                  productName: _lastScannedName!,
                                  onDismiss:
                                      () => setState(
                                        () => _lastScannedName = null,
                                      ),
                                ),
                              ),

                            // Selector flotante de variantes si el OCR detectó ambigüedad
                            if (_pendingAmbiguousResult != null)
                              OcrVariantsSheet(
                                result: _pendingAmbiguousResult!,
                                onClose:
                                    () => setState(
                                      () => _pendingAmbiguousResult = null,
                                    ),
                                onVariantSelected: (variant) async {
                                  final match = _pendingAmbiguousResult!;
                                  final scanResult = PosScanResult(
                                    product: match.product,
                                    variant: variant,
                                    rawCode:
                                        variant.barcode ??
                                        variant.sku ??
                                        match.product.id,
                                  );
                                  setState(
                                    () => _pendingAmbiguousResult = null,
                                  );

                                  if (widget.cartCubit != null) {
                                    await PosBarcodeScannerService.addScanResultToCart(
                                      context: context,
                                      scanResult: scanResult,
                                      cartCubit: widget.cartCubit!,
                                      warehouseId: widget.warehouseId,
                                      showSnackbar: false,
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _scannedCount++;
                                        _lastScannedName =
                                            '${match.product.name} (${variant.label})';
                                      });
                                      _feedbackTimer?.cancel();
                                      _feedbackTimer = Timer(
                                        const Duration(seconds: 4),
                                        () {
                                          if (mounted) {
                                            setState(
                                              () => _lastScannedName = null,
                                            );
                                          }
                                        },
                                      );
                                    }
                                  }
                                },
                              ),

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
                            if (_isOcrProcessing) const OcrProcessingOverlay(),
                          ],
                        ),
              ),
            ),

            // Toast si teclado está abierto
            if (isKeyboardOpen && _lastScannedName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: ScannedFeedbackBanner(
                  productName: _lastScannedName!,
                  onDismiss: () => setState(() => _lastScannedName = null),
                ),
              ),

            // Panel Interactivo del Carrito en Vivo
            Expanded(
              child: ScannerLiveCartPanel(
                cartCubit: widget.cartCubit!,
                manualInputCtrl: _manualInputCtrl,
                manualFocusNode: _manualFocusNode,
                onManualSubmit: _onManualSubmit,
                onOpenSearchModal: () => _openQuickTitleSearchModal(context),
                onCheckout: () => _safeClose(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardBottomBar() {
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

          // Campo de entrada manual de código
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
                      color: Color(0xFF0F172A),
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
