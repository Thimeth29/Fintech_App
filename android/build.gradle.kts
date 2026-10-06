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

// Some plugins (e.g. tflite_flutter) pin Java compatibility explicitly but
// don't pin their Kotlin compiler's jvmTarget, so it silently follows
// whatever JDK Gradle itself runs under — causing "Inconsistent JVM Target
// Compatibility" between their Java and Kotlin tasks. Force every module to
// the same target (17, matching android/app/build.gradle.kts) from here.
// Registered before evaluationDependsOn(":app") below, which otherwise
// forces :app to fully evaluate before this hook could attach to it.
subprojects {
    afterEvaluate {
        extensions.findByName("android")?.withGroovyBuilder {
            getProperty("compileOptions").withGroovyBuilder {
                setProperty("sourceCompatibility", JavaVersion.VERSION_17)
                setProperty("targetCompatibility", JavaVersion.VERSION_17)
            }
        }
        tasks.matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }.configureEach {
            withGroovyBuilder {
                getProperty("kotlinOptions").withGroovyBuilder {
                    setProperty("jvmTarget", "17")
                }
            }
        }
    }
}

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
