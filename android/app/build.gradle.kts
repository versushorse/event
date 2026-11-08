import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.firebase.appdistribution")
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val mapsApiKey = localProperties.getProperty("maps.apiKey") ?: ""

android {
    namespace = "com.example.weekend_outing.weekend_outing"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.weekend_outing.weekend_outing"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            firebaseAppDistribution {
                appId = "1:54317410205:android:da8dae713cbf2e680a3174"
                serviceCredentialsFile = project.file("firebase-credentials.json").absolutePath
                artifactType = "APK"
                artifactPath = project.file("../../build/app/outputs/flutter-apk/app-release.apk").absolutePath
                testers = "high.standard.derringer@gmail.com, orangeruby73.04sw1184@gmail.com"
                releaseNotes = "詳細画面マップ位置ボタン追加・地図スワイプクラッシュ防止・グルメ集約・アプリアイコン拡大対応版"
            }
        }
    }
}

flutter {
    source = "../.."
}
