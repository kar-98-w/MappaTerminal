buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // 🔹 Google Services plugin (Firebase)
        classpath("com.google.gms:google-services:4.4.2")

        // 🔹 Android Gradle Plugin (works well with Flutter 3.24+)
        classpath("com.android.tools.build:gradle:8.2.2")

        // 🔹 Kotlin Gradle Plugin (must match AGP requirements)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.23")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
    id("com.google.gms.google-services") apply false
}

// 🔹 Custom build dir setup (safe to keep)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
