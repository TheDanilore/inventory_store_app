import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class BusinessInfoScreen extends StatefulWidget {
  const BusinessInfoScreen({super.key});

  @override
  State<BusinessInfoScreen> createState() => _BusinessInfoScreenState();
}

class _BusinessInfoScreenState extends State<BusinessInfoScreen> {
  final _businessNameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  bool _didInit = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Escuchamos los cambios del proveedor
    final config = context.watch<AppConfigProvider>();

    // CORRECCIÓN: Solo inicializamos los controladores si no se ha hecho antes
    // Y si los datos ya terminaron de cargar desde Supabase/Caché
    if (!_didInit && config.businessName != 'Cargando...') {
      _businessNameCtrl.text =
          config.businessName == 'Sin configurar' ? '' : config.businessName;
      _taxIdCtrl.text = config.businessTaxId;
      _addressCtrl.text = config.businessAddress;
      _phoneCtrl.text = config.businessPhone;
      _logoUrlCtrl.text = config.businessLogoUrl;
      _didInit =
          true; // Bloqueamos para que no sobrescriba lo que el usuario escribe
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _taxIdCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _logoUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final businessName = _businessNameCtrl.text.trim();
    if (businessName.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Ingresa el nombre del negocio.',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<AppConfigProvider>().saveBusinessInfo(
        businessName: businessName,
        taxId: _taxIdCtrl.text,
        address: _addressCtrl.text,
        phone: _phoneCtrl.text,
        logoUrl: _logoUrlCtrl.text,
      );

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Información del negocio guardada.',
        backgroundColor: Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo guardar la información: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();
    final businessName = config.businessName;
    final businessLogoUrl = config.businessLogoUrl;

    return AdminLayout(
      title: 'Información del Negocio',
      showBackButton: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Vista previa',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F9D8F), Color(0xFF0C7C72)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (businessLogoUrl.isNotEmpty)
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                businessLogoUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, _, _) => const Icon(
                                      Icons.storefront_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                              ),
                            )
                          else
                            const Icon(
                              Icons.storefront_rounded,
                              color: Colors.white,
                              size: 38,
                            ),
                          const SizedBox(height: 12),
                          Text(
                            businessName == 'Cargando...'
                                ? 'Nombre del negocio'
                                : businessName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            config.businessAddress.isNotEmpty
                                ? config.businessAddress
                                : 'Dirección principal',
                            style: const TextStyle(
                              color: Colors.white70,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Datos del negocio',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _businessNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del negocio',
                        hintText: 'Mi Tienda',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _taxIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'RUC / Tax ID',
                        hintText: '20123456789',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        hintText: 'Dirección Principal',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono',
                        hintText: '999 999 999',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _logoUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'URL del logo',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.teal.shade100),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Esta información se guarda en la tabla business_info y se usa en toda la app: título global, menú lateral y vista cliente.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: _isSaving ? 'Guardando...' : 'Guardar información',
              onPressed: _isSaving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
