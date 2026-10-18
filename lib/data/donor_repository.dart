import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/date_format.dart';
import '../core/input_validator.dart';
import '../core/phone_normalizer.dart';
import '../domain/compatibility.dart';
import '../domain/eligibility.dart';
import 'donor.dart';

class DuplicatePhoneException implements Exception {
  const DuplicatePhoneException();
}

enum MarkDonatedResult { created, alreadyLogged }

const Object _unset = Object();

class DonorFilter {
  const DonorFilter({
    this.bloodGroup,
    this.district,
    this.area,
    this.query = '',
    this.eligibleOnly = false,
    this.includeCompatible = false,
  });

  final String? bloodGroup;
  final String? district;
  final String? area;
  final String query;
  final bool eligibleOnly;
  final bool includeCompatible;

  DonorFilter copyWith({
    Object? bloodGroup = _unset,
    Object? district = _unset,
    Object? area = _unset,
    String? query,
    bool? eligibleOnly,
    bool? includeCompatible,
  }) {
    return DonorFilter(
      bloodGroup: identical(bloodGroup, _unset) ? this.bloodGroup : bloodGroup as String?,
      district: identical(district, _unset) ? this.district : district as String?,
      area: identical(area, _unset) ? this.area : area as String?,
      query: query ?? this.query,
      eligibleOnly: eligibleOnly ?? this.eligibleOnly,
      includeCompatible: includeCompatible ?? this.includeCompatible,
    );
  }
}

class DonorStats {
  const DonorStats({
    required this.totalDonors,
    required this.eligibleToday,
    required this.totalDonations,
  });

  final int totalDonors;
  final int eligibleToday;
  final int totalDonations;
}

class DonorRepository {
  DonorRepository(this._db);

  final Database _db;

  String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  Future<List<Donor>> search(DonorFilter filter, {DateTime? now}) async {
    final where = <String>[];
    final args = <Object?>[];
    String orderBy = 'name COLLATE NOCASE';

    if (filter.bloodGroup != null) {
      if (filter.includeCompatible) {
        final compatible = BloodCompatibility.compatibleDonorsFor(filter.bloodGroup!);
        final placeholders = List.filled(compatible.length, '?').join(', ');
        where.add('blood_group IN ($placeholders)');
        args.addAll(compatible);
        final safeGroup = filter.bloodGroup!.replaceAll("'", "''");
        orderBy = "CASE WHEN blood_group = '$safeGroup' THEN 0 ELSE 1 END, name COLLATE NOCASE";
      } else {
        where.add('blood_group = ?');
        args.add(filter.bloodGroup);
      }
    }
    if (filter.district != null) {
      where.add('district = ?');
      args.add(filter.district);
    }
    if (filter.area != null) {
      where.add('area = ?');
      args.add(filter.area);
    }

    final query = filter.query.trim();
    if (query.isNotEmpty) {
      final parts = <String>["name LIKE ? ESCAPE '\\'"];
      args.add('%${_escapeLike(query)}%');
      final digits = PhoneNormalizer.searchDigits(query);
      if (digits.isNotEmpty) {
        parts.add("phone LIKE ? ESCAPE '\\'");
        args.add('%$digits%');
      }
      where.add('(${parts.join(' OR ')})');
    }

    final rows = await _db.query(
      AppConstants.tableDonors,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    var donors = rows.map(Donor.fromMap).toList();

    if (filter.eligibleOnly) {
      final today = now ?? DateTime.now();
      donors = donors
          .where((d) => Eligibility.check(
                gender: d.gender,
                lastDonationDate: d.lastDonationDate,
                today: today,
              ).eligible)
          .toList();
    }
    return donors;
  }

  Future<Donor?> getById(int id) async {
    final rows = await _db.query(
      AppConstants.tableDonors,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Donor.fromMap(rows.first);
  }

  Future<int> insert(Donor donor) async {
    try {
      return await _db.transaction((txn) async {
        await txn.delete(
          AppConstants.tableDeleted,
          where: 'phone = ?',
          whereArgs: [donor.phone],
        );
        return await txn.insert(AppConstants.tableDonors, donor.toMap());
      });
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw const DuplicatePhoneException();
      rethrow;
    }
  }

  Future<void> update(Donor donor) async {
    try {
      await _db.update(
        AppConstants.tableDonors,
        donor.toMap(),
        where: 'id = ?',
        whereArgs: [donor.id],
      );
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) throw const DuplicatePhoneException();
      rethrow;
    }
  }

  Future<void> delete(int id) async {
    await _db.transaction((txn) async {
      final rows = await txn.query(
        AppConstants.tableDonors,
        columns: ['phone'],
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isNotEmpty) {
        final phone = rows.first['phone'] as String;
        await txn.insert(
          AppConstants.tableDeleted,
          {'phone': phone, 'deleted_at': isoNow()},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await txn.delete(AppConstants.tableDonors, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// এক লেনদেনে: একই তারিখের লগ থাকলে থামে, নইলে লগ যোগ করে শেষ তারিখ ও মোট সংখ্যা হালনাগাদ করে।
  Future<MarkDonatedResult> markDonated(int donorId, String date) {
    return _db.transaction<MarkDonatedResult>((txn) async {
      final existing = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM ${AppConstants.tableLogs} WHERE donor_id = ? AND donation_date = ?',
        [donorId, date],
      ));
      if ((existing ?? 0) > 0) return MarkDonatedResult.alreadyLogged;

      final stamp = isoNow();
      await txn.insert(AppConstants.tableLogs, {
        'donor_id': donorId,
        'donation_date': date,
        'created_at': stamp,
      });

      final total = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
            [donorId],
          )) ??
          0;

      final rows = await txn.query(
        AppConstants.tableDonors,
        columns: ['last_donation_date'],
        where: 'id = ?',
        whereArgs: [donorId],
      );
      if (rows.isEmpty) throw StateError('donor $donorId not found');

      final current = rows.first['last_donation_date'] as String?;
      // ISO তারিখ অভিধানক্রমে তুলনা করা যায়।
      final newLast = (current == null || date.compareTo(current) > 0) ? date : current;

      await txn.update(
        AppConstants.tableDonors,
        {'last_donation_date': newLast, 'total_donations': total, 'updated_at': stamp},
        where: 'id = ?',
        whereArgs: [donorId],
      );
      return MarkDonatedResult.created;
    });
  }

  /// লগটি মুছে মোট সংখ্যা লগ থেকে গুনে ঠিক করে এবং আগের শেষ তারিখ ফিরিয়ে দেয়।
  Future<void> undoDonation(int donorId, String date, String? previousLastDate) {
    return _db.transaction<void>((txn) async {
      await txn.delete(
        AppConstants.tableLogs,
        where: 'donor_id = ? AND donation_date = ?',
        whereArgs: [donorId, date],
      );
      final total = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
            [donorId],
          )) ??
          0;
      await txn.update(
        AppConstants.tableDonors,
        {
          'last_donation_date': previousLastDate,
          'total_donations': total,
          'updated_at': isoNow(),
        },
        where: 'id = ?',
        whereArgs: [donorId],
      );
    });
  }

  /// হোম ড্যাশবোর্ডের জন্য সামগ্রিক পরিসংখ্যান গণনা করে।
  Future<DonorStats> getStats({DateTime? now}) async {
    final donors = await search(const DonorFilter(), now: now);
    final today = now ?? DateTime.now();
    int eligible = 0;
    int donations = 0;
    for (final d in donors) {
      donations += d.totalDonations;
      if (Eligibility.check(
        gender: d.gender,
        lastDonationDate: d.lastDonationDate,
        today: today,
      ).eligible) {
        eligible++;
      }
    }
    return DonorStats(
      totalDonors: donors.length,
      eligibleToday: eligible,
      totalDonations: donations,
    );
  }

  /// নির্দিষ্ট ডোনারের পূর্বের সব রক্তদানের তারিখ তালিকা (নতুন থেকে পুরোনো)।
  Future<List<String>> getDonationDates(int donorId) async {
    final rows = await _db.query(
      AppConstants.tableLogs,
      columns: ['donation_date'],
      where: 'donor_id = ?',
      whereArgs: [donorId],
      orderBy: 'donation_date DESC',
    );
    return rows.map((r) => r['donation_date'] as String).toList();
  }

  /// নির্দিষ্ট তারিখের রক্তদান মুছে ফেলে মোট সংখ্যা ও শেষ তারিখ স্বয়ংক্রিয়ভাবে পুনর্নির্ধারণ করে।
  Future<void> deleteDonationDate(int donorId, String date) {
    return _db.transaction<void>((txn) async {
      await txn.delete(
        AppConstants.tableLogs,
        where: 'donor_id = ? AND donation_date = ?',
        whereArgs: [donorId, date],
      );
      final total = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
            [donorId],
          )) ??
          0;
      final maxRow = await txn.rawQuery(
        'SELECT MAX(donation_date) as max_date FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
        [donorId],
      );
      final newLast = maxRow.isNotEmpty ? (maxRow.first['max_date'] as String?) : null;
      await txn.update(
        AppConstants.tableDonors,
        {
          'last_donation_date': newLast,
          'total_donations': total,
          'updated_at': isoNow(),
        },
        where: 'id = ?',
        whereArgs: [donorId],
      );
    });
  }

  // ==========================================
  // App Settings (Key-Value)
  // ==========================================

  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      AppConstants.tableSettings,
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.insert(
      AppConstants.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSetting(String key) async {
    await _db.delete(
      AppConstants.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  // ==========================================
  // Cloud Sync Helpers
  // ==========================================

  Future<List<Map<String, dynamic>>> getDonorsForSync({String? since}) async {
    final rows = await _db.query(
      AppConstants.tableDonors,
      columns: [
        'name',
        'blood_group',
        'gender',
        'phone',
        'consent_to_share',
        'district',
        'area',
        'last_donation_date',
        'total_donations',
        'notes',
        'created_at',
        'updated_at',
      ],
      where: since != null
          ? 'updated_at > ? AND consent_to_share = 1'
          : 'consent_to_share = 1',
      whereArgs: since != null ? [since] : null,
      orderBy: 'updated_at ASC',
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<Map<String, dynamic>>> getLogsForSync({String? since}) async {
    final sql = '''
      SELECT d.phone AS donor_phone, l.donation_date, l.created_at
      FROM ${AppConstants.tableLogs} l
      JOIN ${AppConstants.tableDonors} d ON l.donor_id = d.id
      WHERE d.consent_to_share = 1
      ${since != null ? 'AND l.created_at > ?' : ''}
      ORDER BY l.created_at ASC
    ''';
    final rows = await _db.rawQuery(sql, since != null ? [since] : null);
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<List<String>> getDeletedPhonesForSync() async {
    final rows = await _db.query(AppConstants.tableDeleted, columns: ['phone']);
    return rows.map((r) => r['phone'] as String).toList();
  }

  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> donors,
    required List<Map<String, dynamic>> logs,
    required List<String> deletedPhones,
    required String syncedAt,
  }) async {
    await _db.transaction((txn) async {
      // 1. Process deletions
      for (final phone in deletedPhones) {
        await txn.delete(AppConstants.tableDonors, where: 'phone = ?', whereArgs: [phone]);
        await txn.delete(AppConstants.tableDeleted, where: 'phone = ?', whereArgs: [phone]);
      }

      // 2. Process donors (Last-Write-Wins on updated_at with schema validation)
      for (final remote in donors) {
        final rawPhone = remote['phone'];
        if (rawPhone is! String) continue;
        final phone = PhoneNormalizer.normalize(rawPhone);
        if (phone == null) continue;

        final remoteUpdatedAt = remote['updated_at'] as String? ?? isoNow();

        final donorMap = <String, Object?>{
          'name': remote['name'],
          'blood_group': remote['blood_group'],
          'gender': remote['gender'] ?? 'MALE',
          'phone': phone,
          'consent_to_share':
              (remote['consent_to_share'] == 1 || remote['consent_to_share'] == true) ? 1 : 0,
          'district': remote['district'],
          'area': remote['area'],
          'last_donation_date': remote['last_donation_date'],
          'total_donations': remote['total_donations'] is int ? remote['total_donations'] : 0,
          'notes': remote['notes'],
          'created_at': remote['created_at'] is String ? remote['created_at'] : isoNow(),
          'updated_at': remoteUpdatedAt,
        };

        // Client-side validation: skip corrupted/invalid records to prevent CHECK constraint failures
        final validationError = InputValidator.validateDonorMap(donorMap);
        if (validationError != null) {
          continue;
        }

        final existing = await txn.query(
          AppConstants.tableDonors,
          columns: ['id', 'updated_at'],
          where: 'phone = ?',
          whereArgs: [phone],
        );

        if (existing.isEmpty) {
          await txn.delete(AppConstants.tableDeleted, where: 'phone = ?', whereArgs: [phone]);
          await txn.insert(AppConstants.tableDonors, donorMap);
        } else {
          final localUpdatedAt = existing.first['updated_at'] as String;
          final localId = existing.first['id'] as int;
          if (remoteUpdatedAt.compareTo(localUpdatedAt) >= 0) {
            await txn.update(
              AppConstants.tableDonors,
              donorMap,
              where: 'id = ?',
              whereArgs: [localId],
            );
          }
        }
      }

      // 3. Process donation logs
      for (final log in logs) {
        final rawPhone = log['donor_phone'];
        final rawDate = log['donation_date'];
        if (rawPhone is! String || rawDate is! String) continue;
        final donorPhone = PhoneNormalizer.normalize(rawPhone);
        if (donorPhone == null) continue;
        final donationDate = rawDate.trim();
        final createdAt = log['created_at'] is String ? (log['created_at'] as String) : isoNow();

        final donorRows = await txn.query(
          AppConstants.tableDonors,
          columns: ['id'],
          where: 'phone = ?',
          whereArgs: [donorPhone],
        );

        if (donorRows.isNotEmpty) {
          final donorId = donorRows.first['id'] as int;
          await txn.insert(
            AppConstants.tableLogs,
            {
              'donor_id': donorId,
              'donation_date': donationDate,
              'created_at': createdAt,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          // Reconcile total and max donation date
          final count = Sqflite.firstIntValue(await txn.rawQuery(
            'SELECT COUNT(*) FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
            [donorId],
          )) ?? 0;
          final maxRow = await txn.rawQuery(
            'SELECT MAX(donation_date) as max_date FROM ${AppConstants.tableLogs} WHERE donor_id = ?',
            [donorId],
          );
          final maxDate = maxRow.isNotEmpty ? (maxRow.first['max_date'] as String?) : null;

          await txn.update(
            AppConstants.tableDonors,
            {
              'total_donations': count,
              'last_donation_date': maxDate,
            },
            where: 'id = ?',
            whereArgs: [donorId],
          );
        }
      }

      // 4. Clean up acknowledged deletions
      await txn.delete(
        AppConstants.tableDeleted,
        where: 'deleted_at <= ?',
        whereArgs: [syncedAt],
      );

      // 5. Store last_synced_at setting
      await txn.insert(
        AppConstants.tableSettings,
        {'key': AppConstants.settingLastSynced, 'value': syncedAt},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }
}

