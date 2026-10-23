# Reglas críticas para corregir el bug de R8 en shared_preferences_android 2.5.x
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.coroutines.intrinsics.** { *; }

# Mantener intacta la API de SharedPreferences de Flutter
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# === AGREGA ESTO PARA FIXEAR TU ERROR DE COMPILACIÓN ===
# Evitar que R8 descarte las opciones de idiomas no utilizados de ML Kit
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.devanagari.**