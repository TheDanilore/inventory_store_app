import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_text_field.dart';

class ChangeConnectionDialog extends StatefulWidget {
  final String currentUrl;
  
  const ChangeConnectionDialog({super.key, required this.currentUrl});

  static Future<bool?> show(BuildContext context, String currentUrl) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ChangeConnectionDialog(currentUrl: currentUrl),
    );
  }

  @override
  State<ChangeConnectionDialog> createState() => _ChangeConnectionDialogState();
}

class _ChangeConnectionDialogState extends State<ChangeConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlCtrl;
  final _keyCtrl = TextEditingController();
  
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.currentUrl);
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final url = _urlCtrl.text.trim();
      final key = _keyCtrl.text.trim();

      // Validar conexión usando el endpoint de health de Supabase Auth
      final authHealthUrl = Uri.parse('$url/auth/v1/health');
      final response = await http.get(authHealthUrl).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Tiempo de espera agotado'),
      );

      if (response.statusCode != 200) {
        throw Exception('El servidor no respondió correctamente o la URL es inválida (Status: ${response.statusCode})');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('SUPABASE_URL', url);
      await prefs.setString('SUPABASE_KEY', key);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al validar conexión: $e';
      });
    }
  }

  Future<void> _restoreDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('SUPABASE_URL');
    await prefs.remove('SUPABASE_KEY');
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.dns_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cambiar Conexión a Base de Datos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Ingresa la nueva URL del proyecto de Supabase y la API Key (anon public). Necesitarás reiniciar la aplicación.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              AppTextField(
                controller: _urlCtrl,
                label: 'Project URL',
                hintText: 'https://xxxx.supabase.co',
                icon: Icons.link_rounded,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido';
                  if (!val.startsWith('http')) return 'URL inválida';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: _keyCtrl,
                label: 'API Key',
                hintText: 'eyJh...',
                icon: Icons.key_rounded,
                obscureText: true,
                maxLines: 1,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Requerido';
                  if (val.length < 20) return 'Key demasiado corta';
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: AppPrimaryButton(
                      label: 'Guardar',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _restoreDefault,
                icon: const Icon(Icons.restore, size: 18),
                label: const Text('Restaurar servidor por defecto'),
                style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
