plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.voyage"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 등 일부 의존성이 요구하는
        // core library desugaring 활성화.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID for Android package name.
        // NOTE: 초기 MVP 단계에서는 기본값(com.example.voyage)을 유지하고,
        // 스토어 배포 전에만 변경을 검토한다.
        applicationId = "com.example.voyage"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionName / versionCode are derived from pubspec.yaml.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // TODO: 실제 스토어 배포용 keystore 준비 후 아래 값을 채운다.
            // storeFile = file("/path/to/your/keystore.jks")
            // storePassword = "your-store-password"
            // keyAlias = "your-key-alias"
            // keyPassword = "your-key-password"
        }
    }

    buildTypes {
        release {
            // 내부 테스트 단계에서는 난독화/리소스 축소를 끄고,
            // 디버깅/크래시 분석이 쉽도록 유지한다.
            isMinifyEnabled = false
            isShrinkResources = false
            // keystore 준비 전까지는 debug 키로 서명해,
            // `flutter build apk --release`를 바로 설치해볼 수 있게 한다.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8+ API를 사용하기 위한 core library desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
