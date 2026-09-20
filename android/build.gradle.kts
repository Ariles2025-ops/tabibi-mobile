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

// tabibi-compilesdk-override : force compileSdk 36 sur tous les plugins (flutter_appauth fixe 31).
subprojects {
    // Le build.gradle racine de Flutter evalue deja :app (evaluationDependsOn) : on ne
    // (re)planifie afterEvaluate que sur les sous-projets pas encore evalues (les plugins).
    if (!state.executed) {
        afterEvaluate {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                try {
                    androidExt.javaClass
                        .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(androidExt, 36)
                } catch (e: Exception) {
                }
            }
        }
    }
}
