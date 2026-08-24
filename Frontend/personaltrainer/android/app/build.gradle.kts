plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.altf4.personaltrainer"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // `flutter_local_notifications` usa APIs de java.time, que en Android
        // no existen por debajo de API 26. El desugaring las reescribe a una
        // implementación propia al compilar. Sin esto el build de release falla
        // en seco ("requires core library desugaring to be enabled"), y solo en
        // release: `flutter run` en debug no lo pide y el fallo aparece justo
        // cuando vas a generar la APK que ibas a instalar.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.altf4.personaltrainer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 28
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // La biblioteca que aporta las clases reescritas por el desugaring de
    // arriba. Va junta con `isCoreLibraryDesugaringEnabled`: activar el flag
    // sin declarar esta dependencia falla igual, solo que con otro mensaje.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
