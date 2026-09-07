allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Force all Android subprojects (including Flutter plugins like file_picker
// which transitively depend on flutter_plugin_android_lifecycle) to compile
// against Android API 36. The plugin's own AAR metadata check would otherwise
// fail with: "Dependency ':flutter_plugin_android_lifecycle' requires libraries
// and applications that depend on it to compile against version 36 or later".
subprojects {
    afterEvaluate {
        when (extensions.findByName("android")) {
            is com.android.build.gradle.LibraryExtension ->
                (extensions.getByName("android") as com.android.build.gradle.LibraryExtension).compileSdk = 36
            is com.android.build.gradle.internal.dsl.BaseAppModuleExtension ->
                (extensions.getByName("android") as com.android.build.gradle.internal.dsl.BaseAppModuleExtension).compileSdk = 36
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
