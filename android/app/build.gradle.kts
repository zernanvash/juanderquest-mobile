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
        if (!hasReleaseSigning) {
            project.logger.warn("Release signing is not configured. Falling back to debug signing for local server artifact.")
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

    // Debug app names (jdq-dev / JDQ AR Lab) come from resValue in buildTypes.debug.
    buildFeatures {
        resValues = true
    }

    defaultConfig {
        applicationId = "dev.zernanvash.juanderquest"
        // ARCore (Plan 47 World AR) needs API 24+.
        minSdk = maxOf(24, flutter.minSdkVersion)
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
        // Builds installed straight from the PC are "jdq-dev" with their own ID, so they sit beside the
        // released "JuanDerQuest" app instead of replacing it (owner 2026-10-30).
        debug {
            // The AR Lab test app (lib/main_ar_lab.dart, -PjdqArLab=true) gets its own ID and name so it
            // sits beside jdq-dev and the released app (owner 2026-11-02).
            if (project.findProperty("jdqArLab") == "true") {
                applicationIdSuffix = ".arlab"
                resValue("string", "app_name", "JDQ AR Lab")
            } else if (project.findProperty("jdqArTest") == "true") {
                // The full app with in-progress AR work (-PjdqArTest=true), so AR testing and the
                // implementers' jdq-dev builds don't overwrite each other on the owner's phone.
                applicationIdSuffix = ".artest"
                resValue("string", "app_name", "JDQ AR Test")
            } else {
                applicationIdSuffix = ".dev"
                resValue("string", "app_name", "jdq-dev")
            }
        }
        release {
            signingConfig = if (hasReleaseSigning) signingConfigs.getByName("protectedRelease") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

// Flutter 3.44 injects defaultConfig filters. AGP merges build-type filters
// with those defaults, so clear them after DSL evaluation before restricting
// release only. Debug keeps every ABI supported by the selected Flutter target.
androidComponents.finalizeDsl {
    it.defaultConfig.ndk.abiFilters.clear()
    it.buildTypes.getByName("release").ndk.abiFilters.apply {
        clear()
        addAll(listOf("arm64-v8a", "armeabi-v7a"))
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    // World AR (Plan 47). "AR Optional": the app installs on phones without ARCore.
    implementation("com.google.ar:core:1.56.0")
}

// The AR Lab and AR Test apps have no registered Firebase client (main.dart initialises Firebase
// from code options and carries on if it fails), so skip the google-services step for them.
if (project.findProperty("jdqArLab") == "true" || project.findProperty("jdqArTest") == "true") {
    tasks.matching { it.name.contains("GoogleServices") }.configureEach { enabled = false }
}
