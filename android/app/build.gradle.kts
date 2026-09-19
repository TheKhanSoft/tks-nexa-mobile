import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tksnexa.attendance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tksnexa.attendance"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Production signing is intentionally supplied outside source control.
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.google.android.play:integrity:1.3.0")
}

fun decodedDartDefines(): Map<String, String> {
    val encoded = providers.gradleProperty("dart-defines").orNull ?: return emptyMap()
    return encoded.split(",").mapNotNull { value ->
        runCatching {
            String(Base64.getDecoder().decode(value), Charsets.UTF_8)
        }.getOrNull()
    }.mapNotNull { definition ->
        val separator = definition.indexOf('=')
        if (separator <= 0) null
        else definition.substring(0, separator) to definition.substring(separator + 1)
    }.toMap()
}

gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("Release", ignoreCase = true) }) {
        val defines = decodedDartDefines()
        check(defines["APP_ENV"] == "production") {
            "Release builds require APP_ENV=production."
        }
        check(defines["DISCOVERY_BASE_URL"]?.startsWith("https://") == true) {
            "Release builds require an HTTPS DISCOVERY_BASE_URL."
        }
        check(!defines["TENANT_API_ALLOWED_HOST_SUFFIXES"].isNullOrBlank()) {
            "Release builds require TENANT_API_ALLOWED_HOST_SUFFIXES."
        }
        check(defines["ALLOW_MOCK_SECURITY"] != "true") {
            "Mock security is forbidden in release builds."
        }
    }
}
