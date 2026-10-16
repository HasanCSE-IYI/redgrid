import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';

/// ডেটাবেস খোলা, স্কিমা তৈরি ও মাইগ্রেশন হুক।
class AppDatabase {
  AppDatabase._();

  static const _fileName = 'redgrid.db';

  static Future<Database> open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _fileName),
      version: AppConstants.schemaVersion,
      onConfigure: configure,
      onCreate: create,
      onUpgrade: upgrade,
    );
  }

  static Future<void> configure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
    await db.rawQuery('PRAGMA journal_mode = WAL');
  }

  static Future<void> create(Database db, int version) async {
    final groups = AppConstants.bloodGroups.map((g) => "'$g'").join(',');
    final genders = AppConstants.genders.map((g) => "'$g'").join(',');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableDonors} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        blood_group TEXT NOT NULL CHECK (blood_group IN ($groups)),
        gender TEXT NOT NULL DEFAULT 'MALE' CHECK (gender IN ($genders)),
        phone TEXT NOT NULL UNIQUE,
        consent_to_share INTEGER NOT NULL DEFAULT 0 CHECK (consent_to_share IN (0, 1)),
        district TEXT NOT NULL,
        area TEXT NOT NULL,
        last_donation_date TEXT,
        total_donations INTEGER NOT NULL DEFAULT 0 CHECK (total_donations >= 0),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableLogs} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        donor_id INTEGER NOT NULL REFERENCES ${AppConstants.tableDonors}(id) ON DELETE CASCADE,
        donation_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE (donor_id, donation_date)
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_donors_lookup ON ${AppConstants.tableDonors} (blood_group, district, area)');
    await db.execute(
        'CREATE INDEX idx_logs_donor_date ON ${AppConstants.tableLogs} (donor_id, donation_date)');
  }

  /// ভবিষ্যতে স্কিমা বদলালে এখানে ধাপে ধাপে মাইগ্রেশন যোগ হবে।
  static Future<void> upgrade(Database db, int oldVersion, int newVersion) async {}
}
