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

// Some plugins (e.g. flutter_timezone) ship their own outdated Kotlin Gradle
// Plugin config with a Kotlin JVM target (1.8) that doesn't match the Java
// target AGP infers for their Java sources (11), which Gradle now rejects as
// an inconsistency. Forcing every subproject's Kotlin/Java compile tasks to
// the same target the app itself uses (17) resolves it without needing each
// plugin to publish a fix.
subprojects {
    // :app already sets its own JVM target correctly (see app/build.gradle.kts);
    // evaluationDependsOn(":app") above forces it to evaluate eagerly, before
    // this block would even get a chance to register afterEvaluate on it, so
    // it's excluded here rather than hitting "project already evaluated".
    if (project.name == "app") return@subprojects
    // Each plugin module's own build script lets AGP fall back to its own
    // Java default (usually 11) while separately hardcoding an old Kotlin
    // target (1.8), which is what's causing "Inconsistent JVM Target"
    // failures — Kotlin and AGP's Java default disagree. Forcing the task
    // properties directly (via configureEach) doesn't stick: AGP's variant
    // task wiring reads the *extension's* compileOptions as the source of
    // truth and pushes that onto the task after the fact, overwriting it.
    // Setting the extension itself, right as each android plugin variant
    // (application/library) is applied — before AGP queries its own
    // default — is what actually sticks.
    listOf("com.android.application", "com.android.library").forEach { pluginId ->
        pluginManager.withPlugin(pluginId) {
            extensions.configure<com.android.build.gradle.BaseExtension> {
                compileOptions.sourceCompatibility = JavaVersion.VERSION_17
                compileOptions.targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }
    // Some plugins (e.g. home_widget) hardcode Java 1.8 in their *own* build
    // script, which runs after the withPlugin callback above and overrides it
    // back — leaving Java at 1.8 while Kotlin is forced to 17 below, the exact
    // mismatch Gradle rejects. Re-assert 17 in afterEvaluate, once the
    // plugin's own script has run, so it has the final word.
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
    }
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
