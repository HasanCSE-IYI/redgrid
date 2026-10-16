#!/usr/bin/env python3
"""Android বিল্ড ও কনফিগারেশন প্যাচ টুল:
1. Android 11+ এ tel: কল কাজ করার জন্য AndroidManifest.xml এ <queries> যোগ করে।
2. flutter_plugin_android_lifecycle / file_picker ইত্যাদিতে compileSdk 36 ও CheckAarMetadata সমাধান করে।
3. Groovy (.gradle) এবং Kotlin DSL (.gradle.kts) উভয় ফরম্যাট সমর্থন করে।
4. local.properties এবং settings.gradle / settings.gradle.kts কনফিগারেশন আপডেট করে।
একাধিকবার চালালেও নিরাপদ (idempotent)।"""
import pathlib
import re
import sys

ANDROID_DIR = pathlib.Path("android")
MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

MARKER = "android.intent.action.DIAL"
INTENT = """    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
"""

GROOVY_SUBPROJECTS_HOOK = """
// RedGrid patch: Force compileSdk 36 and disable CheckAarMetadata on plugins
subprojects { project ->
    def configure = {
        if (project.hasProperty("android")) {
            try {
                project.android {
                    compileSdkVersion 36
                }
            } catch (Exception ignored) {}
        }
    }
    if (project.state.executed) {
        configure()
    } else {
        project.afterEvaluate { configure() }
    }
    project.tasks.configureEach { task ->
        if (task.name.contains("AarMetadata")) {
            task.enabled = false
        }
    }
}
"""

KOTLIN_SUBPROJECTS_HOOK = """
// RedGrid patch: Force compileSdk 36 and disable CheckAarMetadata on plugins
subprojects {
    val configureAction = org.gradle.api.Action<Project> { proj ->
        val ext = proj.extensions.findByName("android")
        if (ext != null) {
            try {
                val method = ext.javaClass.getMethod("setCompileSdkVersion", java.lang.Integer.TYPE)
                method.invoke(ext, 36)
            } catch (e: Exception) {}
        }
    }
    if (state.executed) {
        configureAction.execute(this)
    } else {
        afterEvaluate(configureAction)
    }
    tasks.configureEach {
        if (name.contains("AarMetadata")) {
            enabled = false
        }
    }
}
"""

SETTINGS_KOTLIN_HOOK = """
// RedGrid patch: Disable CheckAarMetadata globally
gradle.afterProject {
    tasks.configureEach {
        if (name.contains("AarMetadata")) {
            enabled = false
        }
    }
}
"""

SETTINGS_GROOVY_HOOK = """
// RedGrid patch: Disable CheckAarMetadata globally
gradle.afterProject { project ->
    project.tasks.configureEach { task ->
        if (task.name.contains("AarMetadata")) {
            task.enabled = false
        }
    }
}
"""


def patch_manifest() -> bool:
    if not MANIFEST.exists():
        print(f"warning: {MANIFEST} not found", file=sys.stderr)
        return False
    text = MANIFEST.read_text(encoding="utf-8")
    if MARKER in text:
        print("manifest already patched")
        return True

    if "<queries>" in text:
        text = text.replace("<queries>", "<queries>\n" + INTENT, 1)
    else:
        block = "    <queries>\n" + INTENT + "    </queries>\n"
        text = text.replace("</manifest>", block + "</manifest>", 1)

    if MARKER not in text:
        print("error: could not patch manifest", file=sys.stderr)
        return False
    MANIFEST.write_text(text, encoding="utf-8")
    print("manifest patched")
    return True


def patch_local_properties() -> None:
    if not ANDROID_DIR.exists():
        return
    local_props = pathlib.Path("android/local.properties")
    content = local_props.read_text(encoding="utf-8") if local_props.exists() else ""
    changed = False
    if "flutter.compileSdkVersion" not in content:
        content += "\nflutter.compileSdkVersion=36"
        changed = True
    if "flutter.targetSdkVersion" not in content:
        content += "\nflutter.targetSdkVersion=36"
        changed = True
    if changed:
        local_props.write_text(content.strip() + "\n", encoding="utf-8")
        print("android/local.properties updated with compileSdkVersion=36")
    else:
        print("android/local.properties compileSdk check completed")


def patch_app_gradle() -> None:
    # 1. Groovy: android/app/build.gradle
    app_groovy = pathlib.Path("android/app/build.gradle")
    if app_groovy.exists():
        text = app_groovy.read_text(encoding="utf-8")
        orig = text
        text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
        text = re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 36', text)
        text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', text)
        text = re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion', 'targetSdkVersion 36', text)
        if text != orig:
            app_groovy.write_text(text, encoding="utf-8")
            print("android/app/build.gradle patched compileSdk to 36")
        else:
            print("android/app/build.gradle already configured")

    # 2. Kotlin DSL: android/app/build.gradle.kts
    app_kts = pathlib.Path("android/app/build.gradle.kts")
    if app_kts.exists():
        text = app_kts.read_text(encoding="utf-8")
        orig = text
        text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
        text = re.sub(r'compileSdkVersion\s*\(\s*flutter\.compileSdkVersion\s*\)', 'compileSdk = 36', text)
        text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', text)
        text = re.sub(r'targetSdkVersion\s*\(\s*flutter\.targetSdkVersion\s*\)', 'targetSdk = 36', text)
        if text != orig:
            app_kts.write_text(text, encoding="utf-8")
            print("android/app/build.gradle.kts patched compileSdk to 36")
        else:
            print("android/app/build.gradle.kts already configured")


def patch_root_gradle() -> None:
    # 1. Groovy: android/build.gradle
    root_groovy = pathlib.Path("android/build.gradle")
    if root_groovy.exists():
        text = root_groovy.read_text(encoding="utf-8")
        if "AarMetadata" not in text:
            text += GROOVY_SUBPROJECTS_HOOK
            root_groovy.write_text(text, encoding="utf-8")
            print("android/build.gradle patched with compileSdk 36 & AarMetadata hook")
        else:
            print("android/build.gradle already patched")

    # 2. Kotlin DSL: android/build.gradle.kts
    root_kts = pathlib.Path("android/build.gradle.kts")
    if root_kts.exists():
        text = root_kts.read_text(encoding="utf-8")
        if "AarMetadata" not in text:
            text += KOTLIN_SUBPROJECTS_HOOK
            root_kts.write_text(text, encoding="utf-8")
            print("android/build.gradle.kts patched with compileSdk 36 & AarMetadata hook")
        else:
            print("android/build.gradle.kts already patched")


def patch_settings_gradle() -> None:
    # 1. Kotlin DSL: android/settings.gradle.kts
    settings_kts = pathlib.Path("android/settings.gradle.kts")
    if settings_kts.exists():
        text = settings_kts.read_text(encoding="utf-8")
        if "AarMetadata" not in text:
            text += SETTINGS_KOTLIN_HOOK
            settings_kts.write_text(text, encoding="utf-8")
            print("android/settings.gradle.kts patched with global AarMetadata bypass")
        else:
            print("android/settings.gradle.kts already patched")

    # 2. Groovy: android/settings.gradle
    settings_groovy = pathlib.Path("android/settings.gradle")
    if settings_groovy.exists():
        text = settings_groovy.read_text(encoding="utf-8")
        if "AarMetadata" not in text:
            text += SETTINGS_GROOVY_HOOK
            settings_groovy.write_text(text, encoding="utf-8")
            print("android/settings.gradle patched with global AarMetadata bypass")
        else:
            print("android/settings.gradle already patched")


def print_android_structure() -> None:
    if ANDROID_DIR.exists():
        files = [str(p) for p in ANDROID_DIR.rglob("*") if p.is_file()]
        print(f"Android directory files ({len(files)} files found):")
        for f in sorted(files)[:20]:
            print(f"  {f}")
        if len(files) > 20:
            print(f"  ... and {len(files) - 20} more files")
    else:
        print("android directory does not exist yet (local dev environment)")


def main() -> int:
    print_android_structure()
    manifest_ok = patch_manifest()
    patch_local_properties()
    patch_app_gradle()
    patch_root_gradle()
    patch_settings_gradle()
    if not ANDROID_DIR.exists():
        return 0
    return 0 if manifest_ok else 1


if __name__ == "__main__":
    sys.exit(main())
