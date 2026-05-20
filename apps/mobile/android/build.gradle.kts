allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Dev container (Windows Docker): keep Gradle outputs off the bind mount so chmod/755
// and the build cache work. Override with UNRECORDED_ANDROID_BUILD_DIR (absolute path).
val newBuildDir: Directory =
    System.getenv("UNRECORDED_ANDROID_BUILD_DIR")?.takeIf { it.isNotBlank() }?.let { path ->
        rootProject.objects.directoryProperty().apply {
            set(rootProject.file(path))
        }.get()
    }
        ?: rootProject.layout.buildDirectory.dir("../../build").get()
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
