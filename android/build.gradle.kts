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
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
