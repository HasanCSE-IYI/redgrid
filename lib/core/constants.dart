/// অ্যাপের স্থির মানগুলো এক জায়গায়।
class AppConstants {
  AppConstants._();

  static const bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-', 'Oh'];

  static const genderMale = 'MALE';
  static const genderFemale = 'FEMALE';
  static const genders = [genderMale, genderFemale];

  static const maleCooldownDays = 90;
  static const femaleCooldownDays = 120;

  static const schemaVersion = 2;

  static const maxNameLength = 80;
  static const maxPlaceLength = 60;
  static const maxNotesLength = 300;

  static const tableDonors = 'donors';
  static const tableLogs = 'donation_logs';
  static const tableDeleted = 'deleted_donors';
  static const tableSettings = 'app_settings';

  static const settingCloudUrl = 'cloud_sync_url';
  static const settingSyncKey = 'cloud_sync_key';
  static const settingLastSynced = 'cloud_last_synced';

  /// বিল্ট-ইন ক্লাউড সিঙ্ক ডিফল্ট
  static const defaultCloudUrl = 'https://redgrid-sync.rauaha.workers.dev';
  static const defaultSyncKey = 'rg_sec_2026_9b8e4f1a';
  static const appAgentHeader = 'RedGrid/1.0';
}
