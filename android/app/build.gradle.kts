plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("com.google.devtools.ksp")
}

val releaseBackendBaseUrl = providers.gradleProperty("xivdaily.releaseBaseUrl")
    .orElse("https://beginnerforever.eu.cc/")
val debugBackendBaseUrl = providers.gradleProperty("xivdaily.debugBaseUrl")
    .orElse("http://10.0.2.2:8000/")

android {
    namespace = "com.xivdaily.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.xivdaily.app"
        minSdk = 26
        targetSdk = 36
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    buildTypes {
        debug {
            // 本地联调只允许通过 debug 构建访问模拟器映射出来的宿主机服务。
            buildConfigField("String", "BACKEND_BASE_URL", "\"${debugBackendBaseUrl.get()}\"")
        }
        release {
            isMinifyEnabled = false
            // release 地址必须由构建参数覆盖，避免把开发地址带进正式包。
            buildConfigField("String", "BACKEND_BASE_URL", "\"${releaseBackendBaseUrl.get()}\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    jvmToolchain(17)
}

val debugUnitTestAsciiClasspathRoot = gradle.gradleUserHomeDir
    .resolve("caches/xivdaily/unit-test-classpath/${project.name}/debug")

val prepareDebugUnitTestAsciiClasspath by tasks.registering(org.gradle.api.tasks.Copy::class) {
    dependsOn(
        "compileDebugUnitTestKotlin",
        "processDebugUnitTestJavaRes",
        "bundleDebugClassesToRuntimeJar",
    )
    into(debugUnitTestAsciiClasspathRoot)
    from(layout.buildDirectory.dir("tmp/kotlin-classes/debugUnitTest")) {
        into("test-classes")
    }
    from(layout.buildDirectory.dir("intermediates/java_res/debugUnitTest/processDebugUnitTestJavaRes/out")) {
        into("test-resources")
    }
    from(
        layout.buildDirectory.file(
            "intermediates/runtime_app_classes_jar/debug/bundleDebugClassesToRuntimeJar/classes.jar"
        )
    ) {
        into("app-classes")
        rename { "app-classes.jar" }
    }
}

gradle.projectsEvaluated {
    tasks.named<org.gradle.api.tasks.testing.Test>("testDebugUnitTest") {
        dependsOn(prepareDebugUnitTestAsciiClasspath)
        // Windows JDK 读取 Gradle worker classpath 参数文件时会把中文项目路径解码错。
        testClassesDirs = files(debugUnitTestAsciiClasspathRoot.resolve("test-classes"))
        classpath = files(
            debugUnitTestAsciiClasspathRoot.resolve("test-classes"),
            debugUnitTestAsciiClasspathRoot.resolve("test-resources"),
            debugUnitTestAsciiClasspathRoot.resolve("app-classes/app-classes.jar"),
        ) + (classpath ?: files())
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2024.10.01")
    implementation(composeBom)
    androidTestImplementation(composeBom)

    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")
    implementation("androidx.navigation:navigation-compose:2.8.3")
    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")
    implementation("androidx.datastore:datastore-preferences:1.1.1")
    implementation("com.squareup.retrofit2:retrofit:2.11.0")
    implementation("com.squareup.retrofit2:converter-moshi:2.11.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.12.0")
    implementation("com.squareup.moshi:moshi-kotlin:1.15.1")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
}
