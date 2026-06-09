import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserDetailSheet extends StatefulWidget {
  final Map<String, dynamic> profile;
  const UserDetailSheet({super.key, required this.profile});

  @override
  State<UserDetailSheet> createState() => _UserDetailSheetState();
}

class _UserDetailSheetState extends State<UserDetailSheet> {
  final _supabase = Supabase.instance.client;
  final _pointsCtrl = TextEditingController();
  bool isSaving = false;

  Future<void> _adjustPoints(int amount) async {
    if (amount == 0) return;
    setState(() => isSaving = true);

    // 1. CAPTURAR LAS REFERENCIAS ANTES DEL ASYNC GAP
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _supabase.from('wallet_movements').insert({
        'profile_id': widget.profile['id'],
        'points': amount,
        'movement_type': 'MANUAL_BONUS',
        'description': 'Ajuste manual de Admin',
      });

      // 2. USAR LA VARIABLE LOCAL
      navigator.pop(true);
    } catch (e) {
      // 3. USAR LA VARIABLE LOCAL
      scaffoldMessenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extraemos datos para mostrar
    final profile = widget.profile;
    final profileDetails = <MapEntry<String, String>>[
      MapEntry('ID perfil', _formatValue(profile['id'])),
      MapEntry('ID auth', _formatValue(profile['auth_user_id'])),
      MapEntry('Correo', _formatValue(profile['email'])),
      MapEntry('Nombre completo', _formatValue(profile['full_name'])),
      MapEntry('Rol', _formatValue(profile['role'])),
      MapEntry('Estado', _formatBool(profile['is_active'])),
      MapEntry('Teléfono', _formatValue(profile['phone'])),
      MapEntry(
        'Documento',
        _formatDocument(profile['document_type'], profile['document_number']),
      ),
      MapEntry('Saldo actual', '${profile['wallet_balance'] ?? 0} monedas'),
      MapEntry('Creado', _formatValue(profile['created_at'])),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                profile['full_name'] ?? 'Usuario',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(height: 30),

            const Text(
              'Datos del usuario',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...profileDetails.map(
              (detail) => _buildDetailRow(detail.key, detail.value),
            ),

            const SizedBox(height: 20),
            // Saldo
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo actual:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${profile['wallet_balance'] ?? 'no tiene'} monedas',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Colors.teal,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // Campo para monedas personalizadas
            TextField(
              controller: _pointsCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad de monedas',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.stars),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        () =>
                            _adjustPoints(int.tryParse(_pointsCtrl.text) ?? 0),
                    child: const Text('Sumar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        () => _adjustPoints(
                          -(int.tryParse(_pointsCtrl.text) ?? 0),
                        ),
                    child: const Text('Restar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'No disponible';
    if (value is String && value.trim().isEmpty) return 'No disponible';
    return value.toString();
  }

  String _formatBool(dynamic value) {
    if (value == null) return 'No disponible';
    return value == true ? 'Activo' : 'Inactivo';
  }

  String _formatDocument(dynamic type, dynamic number) {
    final documentType = _formatValue(type);
    final documentNumber = _formatValue(number);
    return '$documentType - $documentNumber';
  }
}
