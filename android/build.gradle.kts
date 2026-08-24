val localProperties = java.util.Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val mapboxDownloadsToken: String =
    (localProperties.getProperty("MAPBOX_DOWNLOADS_TOKEN")
        ?: System.getenv("MAPBOX_DOWNLOADS_TOKEN"))
        ?: throw GradleException(
            "Missing MAPBOX_DOWNLOADS_TOKEN. Add it to android/local.properties " +
                "(a secret token with Downloads:Read scope from account.mapbox.com/access-tokens) " +
                "or set it as an environment variable."
        )

// mapbox_maps_flutter's build.gradle assumes AGP 9+ auto-provides a `kotlin {}`
// extension and skips applying kotlin-android itself — that assumption doesn't
// hold with this project's AGP/Gradle combo, so pre-apply it here instead.
gradle.beforeProject {
    if (name == "mapbox_maps_flutter") {
        pluginManager.apply("org.jetbrains.kotlin.android")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
            authentication {
                create<BasicAuthentication>("basic")
            }
            credentials {
                username = "mapbox"
                password = mapboxDownloadsToken
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
