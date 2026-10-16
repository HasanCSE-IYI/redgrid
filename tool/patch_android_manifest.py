#!/usr/bin/env python3
"""Android বিল্ড ও কনফিগারেশন প্যাচ টুল:
1. Android 11+ এ tel: কল কাজ করার জন্য AndroidManifest.xml এ <queries> যোগ করে।
2. flutter_plugin_android_lifecycle / file_picker ইত্যাদিতে compileSdk 36 সমাধান করতে
   .pub-cache এর প্লাগিনসমূহ এবং app build.gradle-কে compileSdk 36 এ আপডেট করে।
3. local.properties কনফিগারেশন আপডেট করে।
একাধিকবার চালালেও নিরাপদ (idempotent)।"""
import os
import pathlib
import re
import subprocess
import sys

ANDROID_DIR = pathlib.Path("android")
MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")

MARKER = "android.intent.action.DIAL"
INTENT = """    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
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


def patch_pub_cache() -> None:
    # Run flutter pub get first if flutter is available so packages exist in pub-cache
    try:
        subprocess.run(["flutter", "pub", "get"], check=False)
    except Exception:
        pass

    cache_dirs = []
    if "PUB_CACHE" in os.environ:
        cache_dirs.append(pathlib.Path(os.environ["PUB_CACHE"]))
    cache_dirs.append(pathlib.Path.home() / ".pub-cache")

    def bump_sdk(match):
        val = int(match.group(2))
        return f"{match.group(1)}{max(val, 36)}"

    patched_count = 0
    for c_dir in cache_dirs:
        if not c_dir.exists():
            continue
        for gradle_file in c_dir.rglob("*build.gradle*"):
            try:
                text = gradle_file.read_text(encoding="utf-8")
                orig = text
                text = re.sub(r'(compileSdkVersion\s+)([0-9]+)', bump_sdk, text)
                text = re.sub(r'(compileSdk\s*=\s*)([0-9]+)', bump_sdk, text)
                text = re.sub(
                    r'(compileSdkVersion\s*\(\s*)([0-9]+)(\s*\))',
                    lambda m: f"{m.group(1)}{max(int(m.group(2)), 36)}{m.group(3)}",
                    text,
                )
                text = re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 36', text)
                text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
                if text != orig:
                    gradle_file.write_text(text, encoding="utf-8")
                    pkg_name = gradle_file.parent.parent.name if gradle_file.parent.name == "android" else gradle_file.parent.name
                    print(f"Patched {pkg_name}/{gradle_file.name} compileSdk to 36")
                    patched_count += 1
            except Exception:
                pass
    print(f"Total pub-cache plugins patched to compileSdk 36: {patched_count}")


def main() -> int:
    manifest_ok = patch_manifest()
    patch_local_properties()
    patch_app_gradle()
    patch_pub_cache()
    if not ANDROID_DIR.exists():
        return 0
    return 0 if manifest_ok else 1


if __name__ == "__main__":
    sys.exit(main())
