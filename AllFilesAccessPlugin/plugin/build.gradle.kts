plugins {
    id("com.android.library")
}

android {
    namespace = "com.drum.hero.allfilesaccess"
    compileSdk = 34
    buildToolsVersion = "37.0.0"

    defaultConfig {
        minSdk = 24
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    implementation("org.godotengine:godot:4.5.1.stable")
}
