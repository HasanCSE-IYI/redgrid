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

INTENT = """    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="sms" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <package android:name="com.whatsapp" />
    <package android:name="com.whatsapp.w4b" />
"""


PERMISSIONS = """    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
"""


def patch_manifest() -> bool:
    if not MANIFEST.exists():
        print(f"warning: {MANIFEST} not found", file=sys.stderr)
        return False
    text = MANIFEST.read_text(encoding="utf-8")
    changed = False

    if "android.permission.INTERNET" not in text:
        if "<application" in text:
            text = text.replace("<application", PERMISSIONS + "    <application", 1)
            changed = True
            print("manifest patched with INTERNET and ACCESS_NETWORK_STATE permissions")

    if 'android:allowBackup="true"' in text:
        text = text.replace('android:allowBackup="true"', 'android:allowBackup="false"')
        changed = True
        print("manifest patched with android:allowBackup=false")
    elif "android:allowBackup" not in text and "<application" in text:
        text = text.replace("<application", '<application android:allowBackup="false"', 1)
        changed = True
        print("manifest patched with android:allowBackup=false")

    if 'android:usesCleartextTraffic="true"' in text:
        text = text.replace('android:usesCleartextTraffic="true"', 'android:usesCleartextTraffic="false"')
        changed = True
        print("manifest patched with android:usesCleartextTraffic=false")
    elif "android:usesCleartextTraffic" not in text and "<application" in text:
        text = text.replace("<application", '<application android:usesCleartextTraffic="false"', 1)
        changed = True
        print("manifest patched with android:usesCleartextTraffic=false")

    if 'android:scheme="sms"' not in text or 'android.intent.action.DIAL' not in text:
        if "<queries>" in text:
            if "android.intent.action.DIAL" in text:
                extra = """    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="sms" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" />
    </intent>
    <package android:name="com.whatsapp" />
    <package android:name="com.whatsapp.w4b" />
"""
                text = text.replace("<queries>", "<queries>\n" + extra, 1)
            else:
                text = text.replace("<queries>", "<queries>\n" + INTENT, 1)
        else:
            block = "    <queries>\n" + INTENT + "    </queries>\n"
            text = text.replace("</manifest>", block + "</manifest>", 1)
        changed = True
        print("manifest patched with tel, sms, https, and whatsapp queries")

    if changed:
        MANIFEST.write_text(text, encoding="utf-8")
    else:
        print("manifest already up to date")
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


def patch_file(p: pathlib.Path) -> bool:
    try:
        text = p.read_text(encoding="utf-8")
        orig = text

        def bump_sdk(match):
            val = int(match.group(2))
            return f"{match.group(1)}{max(val, 36)}"

        # 1. Direct replacement of flutter.compileSdkVersion and flutter.targetSdkVersion
        text = re.sub(r'flutter\.compileSdkVersion', '36', text)
        text = re.sub(r'flutter\.targetSdkVersion', '36', text)

        # 2. Numeric compileSdk / compileSdkVersion (e.g. compileSdk 34, compileSdkVersion 34, compileSdk = 34, compileSdk(34))
        # Use [ \t]* so newlines are never consumed
        text = re.sub(r'(\bcompileSdk(?:Version)?[ \t]*=?[ \t]*\(?[ \t]*)([0-9]+)', bump_sdk, text)

        if text != orig:
            p.write_text(text, encoding="utf-8")
            return True
    except Exception:
        pass
    return False


def patch_app_gradle() -> None:
    app_groovy = pathlib.Path("android/app/build.gradle")
    if app_groovy.exists() and patch_file(app_groovy):
        print("android/app/build.gradle patched compileSdk to 36")

    app_kts = pathlib.Path("android/app/build.gradle.kts")
    if app_kts.exists() and patch_file(app_kts):
        print("android/app/build.gradle.kts patched compileSdk to 36")


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

    patched_count = 0
    for c_dir in cache_dirs:
        if not c_dir.exists():
            continue
        for gradle_file in c_dir.rglob("*build.gradle*"):
            if patch_file(gradle_file):
                pkg_name = gradle_file.parent.parent.name if gradle_file.parent.name == "android" else gradle_file.parent.name
                print(f"Patched {pkg_name}/{gradle_file.name} compileSdk to 36")
                patched_count += 1
    print(f"Total pub-cache plugins patched to compileSdk 36: {patched_count}")


def patch_launcher_icons() -> None:
    res_dir = pathlib.Path("android/app/src/main/res")
    source_res = pathlib.Path("assets/icon/android_res")
    if source_res.exists() and res_dir.exists():
        import shutil
        for density_dir in source_res.iterdir():
            if density_dir.is_dir():
                target_dir = res_dir / density_dir.name
                target_dir.mkdir(parents=True, exist_ok=True)
                src_icon = density_dir / "ic_launcher.png"
                if src_icon.exists():
                    shutil.copy2(src_icon, target_dir / "ic_launcher.png")
                    print(f"Copied {density_dir.name}/ic_launcher.png to android res")

    try:
        subprocess.run(["dart", "run", "flutter_launcher_icons"], check=False)
    except Exception:
        pass


def main() -> int:
    manifest_ok = patch_manifest()
    patch_local_properties()
    patch_app_gradle()
    patch_pub_cache()
    patch_launcher_icons()
    if not ANDROID_DIR.exists():
        return 0
    return 0 if manifest_ok else 1


if __name__ == "__main__":
    sys.exit(main())
