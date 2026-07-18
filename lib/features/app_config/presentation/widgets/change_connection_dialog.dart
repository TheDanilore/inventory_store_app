import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final url = _urlCtrl.text.trim();
    final key = _keyCtrl.text.trim();

    context.read<AppConfigCubit>().changeConnection(url, key);
  }

  void _restoreDefault() {
    context.read<AppConfigCubit>().restoreDefaultConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: BlocConsumer<AppConfigCubit, AppConfigState>(
        listener: (context, state) {
          if (state.connectionStatus == ViewState.success) {
            Navigator.pop(context, true);
          }
        },
        builder: (context, state) {
          final isLoading = state.connectionStatus == ViewState.loading;

          return Container(
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
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
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
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        state.errorMessage!,
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
                          onPressed:
                              isLoading
                                  ? null
                                  : () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppPrimaryButton(
                          label: isLoading ? 'Guardando...' : 'Guardar',
                          onPressed: isLoading ? null : _save,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: isLoading ? null : _restoreDefault,
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restaurar servidor por defecto'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
