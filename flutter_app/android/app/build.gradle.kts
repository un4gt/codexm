import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use(::load)
    }
}

fun releaseSigningValue(gradleName: String, keyPropertiesName: String): String? {
    return providers.gradleProperty(gradleName).orNull
        ?: System.getenv(gradleName)
        ?: keyProperties.getProperty(keyPropertiesName)
}

val releaseKeystoreFile = releaseSigningValue("KEYSTORE_FILE", "storeFile")
val releaseKeystorePassword = releaseSigningValue("KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = releaseSigningValue("KEY_ALIAS", "keyAlias")
val releaseKeyPassword = releaseSigningValue("KEY_PASSWORD", "keyPassword")
val releaseKeystore = releaseKeystoreFile?.takeIf { it.isNotBlank() }?.let(::file)
val hasReleaseSigning = listOf(
    releaseKeystore?.takeIf { it.exists() }?.path,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }
val requiresReleaseSigning = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (requiresReleaseSigning && !hasReleaseSigning) {
    val guidance = buildString {
        append(
            "Release signing is required for distributable Android APKs and in-app updates. " +
                "Configure flutter_app/android/key.properties using Flutter's standard " +
                "storeFile/storePassword/keyAlias/keyPassword fields, or provide the " +
                "KEYSTORE_* Gradle properties or environment variables.",
        )
        if (!releaseKeystoreFile.isNullOrBlank() && releaseKeystore?.exists() != true) {
            append(" Missing keystore file: $releaseKeystoreFile.")
        }
    }
    throw GradleException(guidance)
}

android {
    namespace = "com.unsafe.codexm.flutterapp"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.unsafe.codexm.flutterapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = requireNotNull(releaseKeystore)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
