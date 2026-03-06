import java.io.File

group = "com.codexm.nativeplugin"
version = "0.0.7"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
        maven(url = uri("https://raw.githubusercontent.com/leleliu008/ndk-pkg-prefab-aar-maven-repo/master"))
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = uri("https://raw.githubusercontent.com/leleliu008/ndk-pkg-prefab-aar-maven-repo/master"))
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.codexm.nativeplugin"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        minSdk = 24
        targetSdk = 34

        externalNativeBuild {
            cmake {
                cppFlags += "-std=c++17 -fexceptions -frtti"
                arguments += "-DANDROID_STL=c++_shared"
            }
        }
    }

    buildFeatures {
        prefab = true
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
            jniLibs.srcDir(layout.buildDirectory.dir("generated/codexJniLibs"))
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    implementation("com.fpliu.ndk.pkg.prefab.android.21:openssl:3.1.2")
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}

val codexAssetRoot = file("src/main/assets/codex")
val generatedCodexJniLibsDir = layout.buildDirectory.dir("generated/codexJniLibs")

val generateCodexJniLibsTask = tasks.register("generateCodexJniLibs") {
    onlyIf { codexAssetRoot.exists() }
    inputs.dir(codexAssetRoot)
    outputs.dir(generatedCodexJniLibsDir)

    doLast {
        val outputDir = generatedCodexJniLibsDir.get().asFile
        outputDir.deleteRecursively()

        codexAssetRoot.listFiles()
            ?.filter { it.isDirectory }
            ?.forEach { abiDir ->
                val outAbiDir = File(outputDir, abiDir.name).apply { mkdirs() }
                val requiredSources = listOf(
                    "codex",
                    "codex-exec",
                    "rg",
                    "libcodex_z.so",
                    "libcodex_lzma.so",
                )

                val missing = requiredSources.filter { srcName ->
                    !File(abiDir, srcName).exists()
                }
                if (missing.isNotEmpty()) {
                    throw GradleException(
                        "缺少 Codex Android 运行时文件（ABI=${abiDir.name}）：${missing.joinToString(", ")}\n" +
                            "请先在仓库根目录执行：python3 scripts/fetch_android_codex_deps.py --abi ${abiDir.name}"
                    )
                }

                val mappings = mapOf(
                    "codex" to "libcodex.so",
                    "codex-exec" to "libcodex_exec.so",
                    "rg" to "librg.so",
                    "libcodex_z.so" to "libcodex_z.so",
                    "libcodex_lzma.so" to "libcodex_lzma.so",
                )

                mappings.forEach { (srcName, dstName) ->
                    val src = File(abiDir, srcName)
                    if (src.exists()) {
                        src.copyTo(File(outAbiDir, dstName), overwrite = true)
                    }
                }
            }
    }
}

tasks.named("preBuild").configure {
    dependsOn(generateCodexJniLibsTask)
}
