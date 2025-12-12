import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile =
    listOf(
            rootProject.file("key.properties"), // android/key.properties (recommended)
            project.file("key.properties"), // android/app/key.properties (fallback)
        )
        .firstOrNull { it.exists() }
        ?: rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }

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
            if (keystorePropertiesFile.exists()) {
                val storeFilePath =
                    keystoreProperties.getProperty("storeFile")
                        ?: error("Missing `storeFile` in ${keystorePropertiesFile.path}.")
                val storeFileFromAndroidRoot = rootProject.file(storeFilePath)
                val storeFileFromAppModule = file(storeFilePath)
                storeFile =
                    when {
                        storeFileFromAndroidRoot.exists() -> storeFileFromAndroidRoot
                        storeFileFromAppModule.exists() -> storeFileFromAppModule
                        else -> storeFileFromAppModule
                    }
                storePassword =
                    keystoreProperties.getProperty("storePassword")
                        ?: error("Missing `storePassword` in ${keystorePropertiesFile.path}.")
                keyAlias =
                    keystoreProperties.getProperty("keyAlias")
                        ?: error("Missing `keyAlias` in ${keystorePropertiesFile.path}.")
                keyPassword =
                    keystoreProperties.getProperty("keyPassword")
                        ?: error("Missing `keyPassword` in ${keystorePropertiesFile.path}.")
            } else if (isReleaseBuild) {
                error(
                    "Missing signing config file (android/key.properties or android/app/key.properties). " +
                        "Create it to build a properly-signed release bundle for Play Console.",
                )
            }
        }
    }

    buildTypes {
        release {
            // 내부 테스트 단계에서는 난독화/리소스 축소를 끄고,
            // 디버깅/크래시 분석이 쉽도록 유지한다.
            isMinifyEnabled = false
            isShrinkResources = false
            // IMPORTANT: release must NOT be signed with debug keys, or Play Console rejects it.
            signingConfig = signingConfigs.getByName("release")
            isDebuggable = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8+ API를 사용하기 위한 core library desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
