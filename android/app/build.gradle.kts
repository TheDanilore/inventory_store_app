import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // BORRA O COMENTA la línea antigua de kotlin-android
    // id("kotlin-android") 
    id("dev.flutter.flutter-gradle-plugin")
}

// LECTURA AUTOMÁTICA DE TU ARCHIVO KEY.PROPERTIES
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.inventory_store_app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    // CONFIGURACIÓN DE TU FIRMA OFICIAL DE PRODUCCIÓN (THEDANILORE)
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.inventory_store_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // SE REEMPLAZÓ LA CLAVE DE DEBUG POR TU NUEVA FIRMA OFICIAL DE RELEASE
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

// Forzamos la resolución limpia de las dependencias conflictivas de AndroidX al final del archivo
configurations.all {
    resolutionStrategy {
        force("androidx.core:core:1.15.0")
        force("androidx.core:core-ktx:1.15.0")
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5") // Actualizado a la versión estable 2.1.5 para soportar API 36 sin bugs
}
