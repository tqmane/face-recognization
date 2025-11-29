plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.tqmane.similarityquiz"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.tqmane.similarityquiz"
        minSdk = 33  // Android 13以上
        targetSdk = 34
        versionCode = 11
        versionName = "2.0.0"
    }

    // 署名設定（環境変数が設定されている場合のみ有効）
    val keystoreFile = System.getenv("KEYSTORE_FILE")
    val keystorePassword = System.getenv("KEYSTORE_PASSWORD")
    val keyAliasName = System.getenv("KEY_ALIAS")
    val keyPasswordValue = System.getenv("KEY_PASSWORD")
    
    val canSign = !keystoreFile.isNullOrEmpty() && 
                  !keystorePassword.isNullOrEmpty() && 
                  !keyAliasName.isNullOrEmpty() && 
                  !keyPasswordValue.isNullOrEmpty()

    if (canSign) {
        signingConfigs {
            create("release") {
                storeFile = file(keystoreFile!!)
                storePassword = keystorePassword
                keyAlias = keyAliasName
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (canSign) {
                signingConfig = signingConfigs.getByName("release")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")
    implementation("com.google.code.gson:gson:2.10.1")
    
    // HTMLパース用（画像スクレイピング）
    implementation("org.jsoup:jsoup:1.17.2")
    
    // コルーチン
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
