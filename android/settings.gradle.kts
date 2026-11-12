pluginManagement {
    repositories {
        google()
        // Google's mirror of Maven Central first: Central itself answers
        // busy CI and cloud machines with 429 Too Many Requests.
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        // Google's mirror of Maven Central first: Central itself answers
        // busy CI and cloud machines with 429 Too Many Requests.
        maven("https://maven-central.storage-download.googleapis.com/maven2/")
        mavenCentral()
    }
}

rootProject.name = "SlowDownRadijo"
include(":app")
