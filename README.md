# RedGrid - Offline Blood Donor Directory

A 100% offline, privacy-focused life-saver blood donor directory.  
Tech Stack: **Flutter (Material 3) + Riverpod + SQLite (sqflite)**

---

## 🩸 Key & Life-Saving Features

1. **Smart Compatibility Matching**:
   - Automated blood compatibility filtering based on standard red blood cell (RBC) transfusion rules (e.g., for an $A^+$ recipient, compatible donors are $A^+, A^-, O^+, O^-$).
   - Prioritizes Exact Match donors at the top of the list followed by compatible donors.
   - Comprehensive mapping for 9 blood groups, including the rare Bombay phenotype ($Oh$).

2. **Direct Contact Integration (WhatsApp, SMS & Call)**:
   - One-tap phone call, direct WhatsApp chat, or SMS messaging for emergency donor outreach.
   - Pre-formatted polite emergency message templates.
   - Automatic fallback to clipboard copy and user feedback if the messaging app is not installed.

3. **Emergency Blood Request & Social Post Formatter**:
   - Compose well-structured emergency blood request posts with hospital/location, blood group, units needed, time, reason, and contact phone number.
   - One-tap post copy or direct sharing to social media platforms (Facebook, WhatsApp, etc.).
   - **"Find Donors" Action**: Automatically configures search filters and displays eligible matching donors already saved in the app.

4. **Home Dashboard Statistics & Donation History Timeline**:
   - Real-time statistics cards showing Total Donors, Ready Today (Eligible Donors), and Total Donations.
   - Comprehensive donation history timeline for each donor (sorted newest to oldest) with the ability to delete mistaken logs.
   - Donor recognition milestone badges based on lifetime donation count:
     - 🌱 **New Donor** (0 donations)
     - 🩸 **Regular Donor** (1–2 donations)
     - 🥉 **Bronze Donor** (3–4 donations)
     - 🥈 **Silver Donor** (5–9 donations)
     - 🥇 **Golden Lifesaver** (10+ donations)

5. **100% Offline Backup & Restore**:
   - Create and restore full database backups via JSON without requiring any internet connection.
   - Automatic pre-restore safety snapshot (`pre_restore_*.json`) stored in the app documents directory before overwriting data.

---

## Getting Started

```bash
flutter create --org com.example --project-name redgrid redgrid_app
cd redgrid_app
# Replace with this repository's lib/, test/, pubspec.yaml, analysis_options.yaml
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter run
```

---

## Android Configuration

In `android/app/src/main/AndroidManifest.xml` inside the `<manifest>` tag (required for seamless Call, SMS, and WhatsApp intents on Android 11+):

```xml
<queries>
  <intent>
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
</queries>
```

In `android/app/build.gradle`, set `minSdkVersion` to at least 21.

---

## Bengali Fonts (Optional Offline Fonts)

To bundle Bengali fonts offline:
1. Place Noto Sans Bengali font files under `assets/fonts/`.
2. Uncomment the `fonts:` section in `pubspec.yaml`.
3. Add `fontFamily: 'NotoSansBengali'` to the `ThemeData` configuration in `lib/app.dart`.

---

## Privacy & Data Security

- All donor information is stored 100% locally in the device's SQLite database; there is zero server-side tracking, analytics, or internet data transmission.
- Keep exported backup files in a secure place, as they contain phone numbers and personal donor details in unencrypted JSON.
- An automatic local copy (`pre_restore_*.json`) is saved before any database restoration operation to prevent accidental data loss.

---

## GitHub Actions CI & Release APK

- Automated CI pipeline runs on every push and pull request via `.github/workflows/build.yml`.
- Build steps: Setup Java 17 & Flutter stable → Scaffold Android platform files → Patch AndroidManifest & Gradle compileSdk → `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build apk --release`.
- Download the production APK directly from the **`redgrid-apk`** artifact in GitHub Actions run outputs (`app-release.apk`) to install on any Android device.
