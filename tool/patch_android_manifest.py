#!/usr/bin/env python3
"""Android 11+ এ tel: কল কাজ করার জন্য AndroidManifest.xml এ <queries> যোগ করে।
একাধিকবার চালালেও নিরাপদ (আগে থেকে থাকলে কিছু বদলায় না)।"""
import pathlib
import sys

MANIFEST = pathlib.Path("android/app/src/main/AndroidManifest.xml")
MARKER = "android.intent.action.DIAL"
INTENT = """    <intent>
        <action android:name="android.intent.action.DIAL" />
        <data android:scheme="tel" />
    </intent>
"""


def main() -> int:
    if not MANIFEST.exists():
        print(f"error: {MANIFEST} not found", file=sys.stderr)
        return 1
    text = MANIFEST.read_text(encoding="utf-8")
    if MARKER in text:
        print("manifest already patched")
        return 0

    if "<queries>" in text:
        text = text.replace("<queries>", "<queries>\n" + INTENT, 1)
    else:
        block = "    <queries>\n" + INTENT + "    </queries>\n"
        text = text.replace("</manifest>", block + "</manifest>", 1)

    if MARKER not in text:
        print("error: could not patch manifest", file=sys.stderr)
        return 1
    MANIFEST.write_text(text, encoding="utf-8")
    print("manifest patched")
    return 0


if __name__ == "__main__":
    sys.exit(main())
