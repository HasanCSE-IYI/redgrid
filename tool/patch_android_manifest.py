#!/usr/bin/env python3
"""Android বিল্ড ও কনফিগারেশন প্যাচ টুল:
1. Android 11+ এ tel: কল কাজ করার জন্য AndroidManifest.xml এ <queries> যোগ করে।
2. flutter_plugin_android_lifecycle / file_picker ইত্যাদিতে compileSdk 36 ও CheckAarMetadata সমাধান করে।
একাধিকবার চালালেও নিরাপদ (idempotent)।"""
import pathlib
import re
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")
ROOT_GRADLE = pathlib.Path("android/build.gradle")
APP_GRADLE = pathlib.Path("android/app/build.gradle")

MARKER = "android.intent.action.DIAL"
INTENT = """    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
"""

GRADLE_HOOK = """
// RedGrid patch: Force compileSdk 36 and disable CheckAarMetadata on plugins
subprojects { project ->
    project.afterEvaluate {
        if (project.hasProperty("android")) {
            try {
                project.android {
                    compileSdkVersion 36
                }
            } catch (Exception ignored) {}
        }
        project.tasks.matching { it.name.contains("AarMetadata") }.configureEach {
            enabled = false
        }
    }
}
"""


def patch_manifest() -> bool:
    if not MANIFEST.exists():
        print(f"error: {MANIFEST} not found", file=sys.stderr)
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


def patch_gradle() -> None:
    # 1. Root build.gradle
    if ROOT_GRADLE.exists():
        text = ROOT_GRADLE.read_text(encoding="utf-8")
        if "AarMetadata" not in text:
            text += GRADLE_HOOK
            ROOT_GRADLE.write_text(text, encoding="utf-8")
            print("root build.gradle patched with compileSdk 36 & AarMetadata hook")
        else:
            print("root build.gradle already patched")

    # 2. App build.gradle
    if APP_GRADLE.exists():
        text = APP_GRADLE.read_text(encoding="utf-8")
        orig = text
        text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
        text = re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 36', text)
        if text != orig:
            APP_GRADLE.write_text(text, encoding="utf-8")
            print("android/app/build.gradle patched compileSdk to 36")
        else:
            print("android/app/build.gradle compileSdk check completed")


def main() -> int:
    manifest_ok = patch_manifest()
    patch_gradle()
    return 0 if manifest_ok else 1


if __name__ == "__main__":
    sys.exit(main())
