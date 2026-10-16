import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/date_format.dart';
import '../core/phone_normalizer.dart';
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
  });

  final String? bloodGroup;
  final String? district;
  final String? area;
  final String query;
  final bool eligibleOnly;

  DonorFilter copyWith({
    Object? bloodGroup = _unset,
    Object? district = _unset,
    Object? area = _unset,
    String? query,
    bool? eligibleOnly,
  }) {
    return DonorFilter(
      bloodGroup: identical(bloodGroup, _unset) ? this.bloodGroup : bloodGroup as String?,
      district: identical(district, _unset) ? this.district : district as String?,
      area: identical(area, _unset) ? this.area : area as String?,
      query: query ?? this.query,
      eligibleOnly: eligibleOnly ?? this.eligibleOnly,
    );
  }
}

class DonorRepository {
  DonorRepository(this._db);

  final Database _db;

  String _escapeLike(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');

  Future<List<Donor>> search(DonorFilter filter, {DateTime? now}) async {
    final where = <String>[];
    final args = <Object?>[];

    if (filter.bloodGroup != null) {
      where.add('blood_group = ?');
      args.add(filter.bloodGroup);
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
      orderBy: 'name COLLATE NOCASE',
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

  Future<int> insert(Donor donor) async {
    try {
      return await _db.insert(AppConstants.tableDonors, donor.toMap());
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
    await _db.delete(AppConstants.tableDonors, where: 'id = ?', whereArgs: [id]);
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
}
