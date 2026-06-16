import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initControllers();
    });
  }

  void _initControllers() {
    final config = context.read<AppConfigProvider>();
    if (config.businessName != 'Cargando...') {
      _businessNameCtrl.text = config.businessName == 'Sin configurar' ? '' : config.businessName;
      _taxIdCtrl.text = config.businessTaxId;
      _addressCtrl.text = config.businessAddress;
      _phoneCtrl.text = config.businessPhone;
      _logoUrlCtrl.text = config.businessLogoUrl;
      setState(() => _isInitialized = true);
    } else {
      // Si todavía está cargando, escuchamos hasta que termine
      config.addListener(_onConfigLoaded);
    }
  }

  void _onConfigLoaded() {
    final config = context.read<AppConfigProvider>();
    if (config.businessName != 'Cargando...') {
      config.removeListener(_onConfigLoaded);
      if (mounted) {
        _businessNameCtrl.text = config.businessName == 'Sin configurar' ? '' : config.businessName;
        _taxIdCtrl.text = config.businessTaxId;
        _addressCtrl.text = config.businessAddress;
        _phoneCtrl.text = config.businessPhone;
        _logoUrlCtrl.text = config.businessLogoUrl;
        setState(() => _isInitialized = true);
      }
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
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<AppConfigProvider>();
    final success = await provider.saveBusinessInfo(
      businessName: _businessNameCtrl.text,
      taxId: _taxIdCtrl.text,
      address: _addressCtrl.text,
      phone: _phoneCtrl.text,
      logoUrl: _logoUrlCtrl.text,
    );

    if (mounted) {
      if (success) {
        AppSnackbar.show(
          context,
          message: 'Información del negocio guardada.',
          type: SnackbarType.success,
        );
      } else {
        AppSnackbar.show(
          context,
          message: 'No se pudo guardar la información. Intente nuevamente.',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<AppConfigProvider>();

    return AdminLayout(
      title: 'Información del Negocio',
      showBackButton: true,
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BusinessPreviewCard(
                    businessName: config.businessName,
                    businessLogoUrl: config.businessLogoUrl,
                    businessAddress: config.businessAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // Formulario
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
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
                            TextFormField(
                              controller: _businessNameCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del negocio',
                                hintText: 'Mi Tienda',
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty 
                                  ? 'El nombre del negocio es requerido' 
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _taxIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'RUC / Tax ID (Opcional)',
                                hintText: '20123456789',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressCtrl,
                              maxLines: 2,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: const InputDecoration(
                                labelText: 'Dirección (Opcional)',
                                hintText: 'Av. Principal 123',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono (Opcional)',
                                hintText: '999 999 999',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _logoUrlCtrl,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'URL del logo (Opcional)',
                                hintText: 'https://...',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
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
                        'Esta información se usa en toda la app: título global, menú lateral y vista cliente.',
                        style: TextStyle(color: Colors.teal),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  AppPrimaryButton(
                    label: config.isSavingBusinessInfo ? 'Guardando...' : 'Guardar información',
                    onPressed: config.isSavingBusinessInfo ? null : _save,
                  ),
                ],
              ),
            ),
    );
  }
}

class _BusinessPreviewCard extends StatelessWidget {
  final String businessName;
  final String businessLogoUrl;
  final String businessAddress;

  const _BusinessPreviewCard({
    required this.businessName,
    required this.businessLogoUrl,
    required this.businessAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                      child: CachedNetworkImage(
                        imageUrl: businessLogoUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Icon(
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
                    businessAddress.isNotEmpty
                        ? businessAddress
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
    );
  }
}
