import 'package:flutter/material.dart';

/// Contenedor de botones de acción rápida para el Estado de Cuenta
class AccountStatementActionButtons extends StatelessWidget {
  final bool isProcessing;
  final String? processingLabel;
  final VoidCallback onPrint;
  final VoidCallback onWhatsApp;
  final VoidCallback onEmail;
  final VoidCallback onSavePdf;
  final VoidCallback onCopy;

  const AccountStatementActionButtons({
    super.key,
    required this.isProcessing,
    required this.processingLabel,
    required this.onPrint,
    required this.onWhatsApp,
    required this.onEmail,
    required this.onSavePdf,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Botón Principal: IMPRIMIR
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: isProcessing ? null : onPrint,
              icon:
                  isProcessing && processingLabel?.contains('impresión') == true
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.print_rounded, size: 18),
              label: const Text(
                'IMPRIMIR ESTADO DE CUENTA',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  fontSize: 13,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Fila 1: WHATSAPP + CORREO
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: isProcessing ? null : onWhatsApp,
                    icon: const Icon(Icons.chat_rounded, size: 16),
                    label: const Text(
                      'WHATSAPP',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: isProcessing ? null : onEmail,
                    icon: const Icon(Icons.mail_rounded, size: 16),
                    label: const Text(
                      'CORREO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Fila 2: GUARDAR PDF + COPIAR TEXTO
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: isProcessing ? null : onSavePdf,
                    icon:
                        isProcessing && processingLabel?.contains('PDF') == true
                            ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                            ),
                    label: const Text(
                      'GUARDAR PDF',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.icon(
                    onPressed: onCopy,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'COPIAR TEXTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
