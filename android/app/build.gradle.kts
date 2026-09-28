plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseKeystorePath = System.getenv("JDQ_RELEASE_KEYSTORE_PATH")
val releaseStorePassword = System.getenv("JDQ_RELEASE_STORE_PASSWORD")
val releaseKeyAlias = System.getenv("JDQ_RELEASE_KEY_ALIAS")
val releaseKeyPassword = System.getenv("JDQ_RELEASE_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() }

// Debug builds use Android's normal debug certificate. Never silently publish an
// unsigned APK or reuse the old, publicly exposed alpha signing identity.
gradle.taskGraph.whenReady {
    if (allTasks.any { it.path == ":app:assembleRelease" || it.path == ":app:bundleRelease" }) {
        require(hasReleaseSigning && file(releaseKeystorePath!!).isFile) {
            "Release signing is not configured. Set JDQ_RELEASE_KEYSTORE_PATH, " +
                "JDQ_RELEASE_STORE_PASSWORD, JDQ_RELEASE_KEY_ALIAS, and JDQ_RELEASE_KEY_PASSWORD."
        }
    }
}

android {
    namespace = "dev.zernanvash.juanderquest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.zernanvash.juanderquest"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }


    signingConfigs {
        create("protectedRelease") {
            if (hasReleaseSigning) {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("protectedRelease")
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
    implementation("androidx.multidex:multidex:2.0.1")
}

