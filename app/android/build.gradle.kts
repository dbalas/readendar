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

// Flutter 3.44 ships AGP 9 with android.builtInKotlin=false. First-party
// plugins that already migrated (google_sign_in_android 7.2.12+, others)
// no longer apply KGP, so their .kt sources never compile and Java callers
// fail with "cannot find symbol ResultUtilsKt". Apply KGP to those library
// modules until builtInKotlin can be turned on (Flutter 3.47+).
subprojects {
    pluginManager.withPlugin("com.android.library") {
        if (pluginManager.hasPlugin("org.jetbrains.kotlin.android")) {
            return@withPlugin
        }
        val hasKotlinSources =
            sequenceOf(file("src/main/kotlin"), file("src/main/java"))
                .filter { it.isDirectory }
                .any { dir -> dir.walkTopDown().any { it.extension == "kt" } }
        if (hasKotlinSources) {
            pluginManager.apply("org.jetbrains.kotlin.android")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
