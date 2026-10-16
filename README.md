# রেডগ্রিড v7.0 MVP

ইন্টারনেট ছাড়া চলা রক্তদাতা ডিরেক্টরি। Flutter (Material 3) + Riverpod + SQLite।

## চালানোর ধাপ

```bash
flutter create --org com.example --project-name redgrid redgrid_app
cd redgrid_app
# এই জিপের lib/, test/, pubspec.yaml, analysis_options.yaml দিয়ে প্রতিস্থাপন করুন
flutter pub get
flutter analyze
flutter test
flutter run
```

## Android সেটআপ (আবশ্যক)

`android/app/src/main/AndroidManifest.xml` এ `<manifest>` ট্যাগের ভেতরে (`<application>` এর আগে) যোগ করুন, নইলে Android 11+ এ কল বাটন কাজ করবে না:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>
</queries>
```

`android/app/build.gradle` এ `minSdkVersion` কমপক্ষে ২১ রাখুন।

## বাংলা ফন্ট

`assets/fonts/` এ Noto Sans Bengali ফাইল রেখে `pubspec.yaml` এর `fonts:` অংশের কমেন্ট খুলুন এবং `app.dart` এর `ThemeData` এ `fontFamily: 'NotoSansBengali'` যোগ করুন।

## গোপনীয়তা ও সীমা

- সব তথ্য শুধু এই ফোনে থাকে; কোনো নেটওয়ার্ক কোড নেই।
- ব্যাকআপ ফাইল এনক্রিপ্টেড নয় এবং তাতে সবার ফোন নম্বর আছে, শেয়ার করার আগে ভাবুন।
- ডেটাবেস ফাইল এনক্রিপ্টেড নয়।
- জেলা ফিল্টারে শুধু সিড করা জেলা (চট্টগ্রাম, ঢাকা) আছে; অন্য জেলার ডোনার নাম বা নম্বর দিয়ে খোঁজা যাবে।
- রিস্টোরের আগে অ্যাপের ডকুমেন্টস ফোল্ডারে `pre_restore_*.json` নামে বর্তমান তথ্যের কপি রাখা হয়।

## GitHub Actions দিয়ে APK বিল্ড

১. এই ফোল্ডারের সব ফাইল (`.github/`, `tool/`, `lib/`, `test/`, `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`, `README.md`) একটি GitHub রিপোর `main` ব্র্যাঞ্চে পুশ করুন।
২. রিপোর **Actions** ট্যাবে "Build Android APK" চলবে (পুশ, পুল রিকোয়েস্ট বা হাতে "Run workflow" চেপে)।
৩. ধাপগুলো: Java 17 ও Flutter stable সেটআপ → `android/` না থাকলে তৈরি → ম্যানিফেস্টে `tel` queries বসানো → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --release`।
৪. শেষ হলে রান পেজের **Artifacts** থেকে `redgrid-apk` নামিয়ে `app-release.apk` ফোনে ইনস্টল করুন।

সীমা:
- এই APK ডিবাগ কী দিয়ে সাইন করা, ইন্সটল করা যায় কিন্তু Play Store এ দেওয়া যাবে না। Play Store এর জন্য নিজের keystore ও GitHub Secrets দিয়ে সাইনিং যোগ করতে হবে।
- `flutter analyze` এ deprecation টাইপের info নোটিশ বিল্ড থামায় না (`--no-fatal-infos`), কিন্তু warning বা error থামাবে।
- ওয়ার্কফ্লো আমার এখানে চালিয়ে দেখা হয়নি; প্রথম রানে কোনো ধাপ ব্যর্থ হলে লগ দেখে ঠিক করুন।
