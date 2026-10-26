plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "org.congressionalappchallenge.bridge"
    compileSdk = 37

    defaultConfig {
        applicationId = "org.congressionalappchallenge.bridge"
        minSdk = 31
        targetSdk = 36
        versionCode = 102
        versionName = "1.0.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    val releaseStore = System.getenv("BRIDGE_RELEASE_STORE_FILE")
    signingConfigs {
        if (!releaseStore.isNullOrBlank()) {
            create("bridgeRelease") {
                storeFile = file(releaseStore)
                storePassword = System.getenv("BRIDGE_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("BRIDGE_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("BRIDGE_RELEASE_KEY_PASSWORD")
            }
        }
    }
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            if (!releaseStore.isNullOrBlank()) signingConfig = signingConfigs.getByName("bridgeRelease")
        }
    }

    buildFeatures {
        compose = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("com.google.mlkit:translate:17.0.3")
    implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")

    debugImplementation("androidx.compose.ui:ui-tooling")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
}
