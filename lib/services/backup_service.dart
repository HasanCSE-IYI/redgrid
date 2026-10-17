import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../core/constants.dart';
import '../core/date_format.dart';
import '../core/input_validator.dart';
import '../core/phone_normalizer.dart';
import '../core/strings_bn.dart';

class BackupException implements Exception {
  const BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// যাচাই করা, রিস্টোরের জন্য প্রস্তুত তথ্য।
class RestoreData {
  const RestoreData({required this.donors, required this.logs});
  final List<Map<String, Object?>> donors;
  final List<Map<String, Object?>> logs;
}

class BackupService {
  BackupService(
    this._db, {
    Future<Directory> Function()? tempDir,
    Future<Directory> Function()? docsDir,
  })  : _tempDir = tempDir ?? getTemporaryDirectory,
        _docsDir = docsDir ?? getApplicationDocumentsDirectory;

  final Database _db;
  final Future<Directory> Function() _tempDir;
  final Future<Directory> Function() _docsDir;

  String _stamp() => DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');

  Future<Map<String, Object?>> buildBackup() async {
    final donors = await _db.query(AppConstants.tableDonors, orderBy: 'id');
    final logs = await _db.query(AppConstants.tableLogs, orderBy: 'id');
    return {
      'schema_version': AppConstants.schemaVersion,
      'exported_at': isoNow(),
      'donors': donors,
      'donation_logs': logs,
    };
  }

  Future<File> writeBackupFile() async {
    final dir = await _tempDir();
    final file = File(p.join(dir.path, 'redgrid_backup_${_stamp()}.json'));
    return file.writeAsString(jsonEncode(await buildBackup()), flush: true);
  }

  Future<void> shareBackup() async {
    final file = await writeBackupFile();
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        text: Strings.backupShareText,
      ),
    );
  }

  /// ফাইলের লেখা পার্স ও যাচাই করে। কোনো সমস্যা থাকলে [BackupException]।
  RestoreData parseBackup(String text, {DateTime? now}) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const BackupException(Strings.restoreBadFile);
    }
    if (decoded is! Map) throw const BackupException(Strings.restoreBadFile);

    final version = decoded['schema_version'];
    if (version is! int || version < 1) throw const BackupException(Strings.restoreBadFile);
    if (version > AppConstants.schemaVersion) {
      throw const BackupException(Strings.restoreNewerVersion);
    }

    final rawDonors = decoded['donors'];
    final rawLogs = decoded['donation_logs'];
    if (rawDonors is! List || rawLogs is! List) {
      throw const BackupException(Strings.restoreBadFile);
    }

    final stamp = isoNow();
    final ids = <int>{};
    final phones = <String>{};
    final donors = <Map<String, Object?>>[];

    for (final raw in rawDonors) {
      if (raw is! Map) throw const BackupException(Strings.restoreBadFile);
      final row = Map<String, Object?>.from(raw);

      final id = row['id'];
      if (id is! int || id < 1 || !ids.add(id)) {
        throw BackupException(Strings.restoreBadRow('id'));
      }

      final rawPhone = row['phone'];
      final phone = rawPhone is String ? PhoneNormalizer.normalize(rawPhone) : null;
      if (phone == null || !phones.add(phone)) {
        throw BackupException(Strings.restoreBadRow(Strings.errPhone));
      }
      row['phone'] = phone;

      if (row['consent_to_share'] == true) {
        row['consent_to_share'] = 1;
      } else if (row['consent_to_share'] == false) {
        row['consent_to_share'] = 0;
      }

      final error = InputValidator.validateDonorMap(row, now: now);
      if (error != null) throw BackupException(Strings.restoreBadRow(error));

      donors.add({
        'id': id,
        'name': (row['name'] as String).trim(),
        'blood_group': row['blood_group'],
        'gender': row['gender'],
        'phone': phone,
        'consent_to_share': row['consent_to_share'],
        'district': (row['district'] as String).trim(),
        'area': (row['area'] as String).trim(),
        'last_donation_date': row['last_donation_date'],
        'total_donations': row['total_donations'],
        'notes': row['notes'],
        'created_at': row['created_at'] is String ? row['created_at'] : stamp,
        'updated_at': row['updated_at'] is String ? row['updated_at'] : stamp,
      });
    }

    final logKeys = <String>{};
    final logs = <Map<String, Object?>>[];
    for (final raw in rawLogs) {
      if (raw is! Map) throw const BackupException(Strings.restoreBadFile);
      final donorId = raw['donor_id'];
      final date = raw['donation_date'];
      if (donorId is! int || !ids.contains(donorId) || date is! String || parseIsoDate(date) == null) {
        throw BackupException(Strings.restoreBadRow('donation_logs'));
      }
      if (!logKeys.add('$donorId|$date')) {
        throw BackupException(Strings.restoreBadRow('donation_logs'));
      }
      logs.add({
        'donor_id': donorId,
        'donation_date': date,
        'created_at': raw['created_at'] is String ? raw['created_at'] : stamp,
      });
    }

    return RestoreData(donors: donors, logs: logs);
  }

  /// আগে বর্তমান তথ্যের কপি রাখে, তারপর এক লেনদেনে সব প্রতিস্থাপন করে।
  /// কোনো ধাপে ব্যর্থ হলে পুরো লেনদেন রোলব্যাক হয়।
  Future<void> restore(RestoreData data) async {
    final dir = await _docsDir();
    final copy = File(p.join(dir.path, 'pre_restore_${_stamp()}.json'));
    await copy.writeAsString(jsonEncode(await buildBackup()), flush: true);

    await _db.transaction((txn) async {
      await txn.delete(AppConstants.tableLogs);
      await txn.delete(AppConstants.tableDonors);
      final batch = txn.batch();
      for (final donor in data.donors) {
        batch.insert(AppConstants.tableDonors, donor);
      }
      for (final log in data.logs) {
        batch.insert(AppConstants.tableLogs, log);
      }
      await batch.commit(noResult: true);
    });
  }
}
