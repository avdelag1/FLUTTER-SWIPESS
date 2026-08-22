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

    // Flutter 3.47 ships AGP 9 with android.builtInKotlin=false while the
    // ecosystem migrates. Mapbox Maps Flutter 3.0 alpha checks only the AGP
    // major version, so it skips applying KGP and then immediately configures
    // the `kotlin {}` extension, which makes Android release builds fail.
    // Register this narrowly-scoped compatibility bridge before the Mapbox
    // subproject is evaluated. Remove it once Mapbox respects the
    // android.builtInKotlin property itself.
    if (project.name == "mapbox_maps_flutter_mobile") {
        project.pluginManager.withPlugin("com.android.library") {
            project.pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
