allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// CameraX 1.5 exposes CallbackToFutureAdapter in its public API, but the
// current Flutter camera plugin does not declare the artifact on its compile
// classpath. Supply it to that plugin module until its upstream metadata does.
subprojects {
    if (name == "camera_android_camerax") {
        pluginManager.withPlugin("com.android.library") {
            dependencies.add("implementation", "androidx.concurrent:concurrent-futures:1.3.0")
        }
    }
    // coinbase_wallet_sdk 1.0.10 hard-codes compileSdk 31 even though its
    // AndroidX dependencies require API 34+. It also references two absent
    // ProGuard files. Override these at AGP's DSL finalization rather than
    // editing the generated Pub cache.
    if (name == "coinbase_wallet_sdk") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>("androidComponents") {
                finalizeDsl {
                    it.compileSdk = 36
                    it.defaultConfig.consumerProguardFiles.clear()
                    it.defaultConfig.proguardFiles.clear()
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
