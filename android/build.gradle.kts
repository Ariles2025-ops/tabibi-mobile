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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Force compileSdk 36 sur TOUS les modules de plugins (flutter_appauth compile
// contre android-31 dans le cache pub ; androidx.window exige >= 33). Reflexion
// pour rester compatible quelle que soit la version d'AGP du plugin.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                val m = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                m.invoke(androidExt, 36)
            } catch (e: Exception) {
                // module sans cette methode : ignore
            }
        }
    }
}
