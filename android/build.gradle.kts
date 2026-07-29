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
rootProject.buildDir = newBuildDir.asFile

subprojects {
    val project = this
    
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
    project.buildDir = newSubprojectBuildDir.asFile
    
    if (project.name != "app") {
        project.afterEvaluate {
            if (project.hasProperty("android")) {
                val android = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
                android?.apply {
                    compileSdkVersion(36)
                }
            }
        }
    }
    
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
