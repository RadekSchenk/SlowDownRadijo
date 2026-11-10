plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}

// The iOS app's Resources folder: photos, fonts and schedule.json are used
// from there, not copied into android/ (see buildSrc/SharedResources.kt).
val iosResourcesDir = rootProject.layout.projectDirectory.dir("../SlowDownRadijo/Resources")

android {
    namespace = "cz.slowdownradijo.app"
    compileSdk = 37

    defaultConfig {
        applicationId = "cz.slowdownradijo.app"
        minSdk = 26
        targetSdk = 37
        // CI sets the build number (the run number); 1 locally.
        versionCode = providers.environmentVariable("VERSION_CODE").orNull?.toInt() ?: 1
        versionName = "1.1"
    }

    // The Google Play upload key, from CI secrets (a base64 keystore). Without
    // it, release builds are signed with the debug key: installable on an
    // emulator for testing, refused by Google Play.
    val uploadKeystore = providers.environmentVariable("UPLOAD_KEYSTORE_PATH").orNull
    signingConfigs {
        if (uploadKeystore != null) {
            create("upload") {
                storeFile = file(uploadKeystore)
                storePassword = providers.environmentVariable("UPLOAD_KEYSTORE_PASSWORD").get()
                keyAlias = providers.environmentVariable("UPLOAD_KEY_ALIAS").get()
                keyPassword = providers.environmentVariable("UPLOAD_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
        debug {
            applicationIdSuffix = ".debug"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.systemProperty("robolectric.pixelCopyRenderMode", "hardware")
                // Robolectric reaches into FileDescriptor through JDK internals.
                it.jvmArgs(
                    "--add-opens=java.base/java.io=ALL-UNNAMED",
                    "--add-exports=java.base/jdk.internal.access=ALL-UNNAMED",
                )
            }
        }
    }
}

val syncSharedResources = tasks.register<SyncSharedResources>("syncSharedResources") {
    iosResources.set(iosResourcesDir)
    resOutput.set(layout.buildDirectory.dir("generated/shared/res"))
    kotlinOutput.set(layout.buildDirectory.dir("generated/shared/kotlin"))
}
val syncSharedAssets = tasks.register<SyncSharedAssets>("syncSharedAssets") {
    iosResources.set(iosResourcesDir)
    output.set(layout.buildDirectory.dir("generated/shared/assets"))
}

androidComponents {
    onVariants { variant ->
        variant.sources.res?.addGeneratedSourceDirectory(syncSharedResources, SyncSharedResources::resOutput)
        variant.sources.kotlin?.addGeneratedSourceDirectory(syncSharedResources, SyncSharedResources::kotlinOutput)
        variant.sources.assets?.addGeneratedSourceDirectory(syncSharedAssets, SyncSharedAssets::output)
    }
}

roborazzi {
    outputDir.set(file("src/test/screenshots"))
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.ui.graphics)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.material.icons)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    implementation(libs.media3.exoplayer)
    implementation(libs.media3.exoplayer.hls)
    implementation(libs.media3.session)
    implementation(libs.media3.datasource.okhttp)

    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)
    implementation(libs.glance.appwidget)
    implementation(libs.work.runtime)

    testImplementation(libs.junit)
    testImplementation(libs.androidx.test.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.kotlinx.coroutines.test)
    testImplementation(libs.okhttp.mockwebserver)
    testImplementation(platform(libs.compose.bom))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    testImplementation(libs.roborazzi.accessibility.check)
    testImplementation(libs.glance.appwidget.testing)
    testImplementation(libs.work.testing)
}
