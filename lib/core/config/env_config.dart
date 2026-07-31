import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String url = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: '',
    );
    String key = const String.fromEnvironment(
      'SUPABASE_KEY',
      defaultValue: '',
    );

    // Si no vinieron por variables de entorno, intentar cargar env.json como asset en modo depuración
    if (url.isEmpty || key.isEmpty) {
      try {
        final jsonString = await rootBundle.loadString('env.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        url = (jsonMap['SUPABASE_URL'] as String?)?.trim() ?? url;
        key = (jsonMap['SUPABASE_KEY'] as String?)?.trim() ?? key;
      } catch (e) {
        debugPrint('EnvConfig: No se pudo cargar env.json desde assets: $e');
      }
    }

    // Fallback final a SharedPreferences
    url = prefs.getString('SUPABASE_URL') ?? url;
    key = prefs.getString('SUPABASE_KEY') ?? key;

    if (url.isEmpty || key.isEmpty) {
      throw Exception(
        'FALLO CRÍTICO: Las credenciales de Supabase no están configuradas. '
        'Asegúrate de tener el archivo env.json en la raíz o pasar las banderas --dart-define-from-file=env.json',
      );
    }

    _supabaseUrl = url;
    _supabaseKey = key;
  }
}
