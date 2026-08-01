import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

abstract class EnvConfig {
  static String _supabaseUrl = '';
  static String _supabaseKey = '';

  static String get supabaseUrl => _supabaseUrl;
  static String get supabaseKey => _supabaseKey;

  /// Carga las credenciales usando un sistema de resolución en cascada:
  /// 1. `String.fromEnvironment` (Inyectado vía CLI o launch.json)
  /// 2. `rootBundle` asset `env.json` (En modo debug/desarrollo)
  /// 3. `SharedPreferences` (Si el usuario configuró credenciales en la app)
  static Future<void> load(SharedPreferences prefs) async {
    // 1. PRIORIDAD BAJA: Caché persistente
    String url = prefs.getString('SUPABASE_URL') ?? '';
    String key = prefs.getString('SUPABASE_KEY') ?? '';

    // 2. PRIORIDAD MEDIA: Archivo de entorno local (env.json)
    try {
      final jsonString = await rootBundle.loadString('env.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      final jsonUrl = (jsonMap['SUPABASE_URL'] as String?)?.trim() ?? '';
      final jsonKey = (jsonMap['SUPABASE_KEY'] as String?)?.trim() ?? '';
      if (jsonUrl.isNotEmpty) url = jsonUrl;
      if (jsonKey.isNotEmpty) key = jsonKey;
    } catch (e) {
      developer.log(
        'No se pudo cargar env.json desde assets',
        error: e,
        name: 'EnvConfig',
      );
    }

    // 3. PRIORIDAD MÁXIMA: Banderas de compilación (--dart-define)
    const envUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    const envKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: '');

    if (envUrl.isNotEmpty) url = envUrl;
    if (envKey.isNotEmpty) key = envKey;

    if (url.isEmpty || key.isEmpty) {
      throw Exception(
        'FALLO CRÍTICO: Las credenciales de Supabase no están configuradas. '
        'Asegúrate de tener el archivo env.json en la raíz o pasar las banderas --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...',
      );
    }

    _supabaseUrl = url;
    _supabaseKey = key;
  }
}
