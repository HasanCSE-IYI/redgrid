import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/date_format.dart';
import 'package:redgrid/data/app_database.dart';
import 'package:redgrid/data/donor.dart';
import 'package:redgrid/data/donor_repository.dart';
import 'package:redgrid/services/backup_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// আজকের তারিখ থেকে হিসাব করা তারিখ (ভ্যালিডেটর ভবিষ্যতের তারিখ বাতিল করে)।
String daysAgo(int n) => isoDate(DateTime.now().subtract(Duration(days: n)));

final String recent = daysAgo(15);
final String older = daysAgo(150);

Donor _donor({String phone = '01712345678', String name = 'রহিম', String? last}) => Donor(
      name: name,
      bloodGroup: 'A+',
      gender: 'MALE',
      phone: phone,
      consentToShare: true,
      district: 'ঢাকা',
      area: 'উত্তরা',
      lastDonationDate: last,
      createdAt: '2026-01-01T00:00:00Z',
      updatedAt: '2026-01-01T00:00:00Z',
    );

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late DonorRepository repo;
  late Directory docs;
  late BackupService backup;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onConfigure: AppDatabase.configure,
      onCreate: AppDatabase.create,
    );
    repo = DonorRepository(db);
    docs = Directory.systemTemp.createTempSync('redgrid_test');
    backup = BackupService(db, tempDir: () async => docs, docsDir: () async => docs);
  });

  tearDown(() async {
    await db.close();
    docs.deleteSync(recursive: true);
  });

  test('একই নম্বরে দ্বিতীয় ডোনার যোগ হয় না', () async {
    await repo.insert(_donor());
    expect(() => repo.insert(_donor(name: 'করিম')), throwsA(isA<DuplicatePhoneException>()));
  });

  test('আজ রক্ত দিয়েছেন: বারবার চাপলে দুইবার গণনা হয় না', () async {
    final id = await repo.insert(_donor());
    expect(await repo.markDonated(id, recent), MarkDonatedResult.created);
    expect(await repo.markDonated(id, recent), MarkDonatedResult.alreadyLogged);

    final donor = (await repo.search(const DonorFilter())).single;
    expect(donor.totalDonations, 1);
    expect(donor.lastDonationDate, recent);
  });

  test('পুরনো তারিখের দান শেষ তারিখ কমায় না', () async {
    final id = await repo.insert(_donor());
    await repo.markDonated(id, recent);
    await repo.markDonated(id, older);
    final donor = (await repo.search(const DonorFilter())).single;
    expect(donor.totalDonations, 2);
    expect(donor.lastDonationDate, recent);
  });

  test('Undo আগের মান ফেরায়', () async {
    final id = await repo.insert(_donor(last: daysAgo(200)));
    await repo.markDonated(id, recent);
    await repo.undoDonation(id, recent, daysAgo(200));

    final donor = (await repo.search(const DonorFilter())).single;
    expect(donor.totalDonations, 0);
    expect(donor.lastDonationDate, daysAgo(200));
  });

  test('ডোনার মুছলে লগও মোছে', () async {
    final id = await repo.insert(_donor());
    await repo.markDonated(id, recent);
    await repo.delete(id);
    expect(await db.query('donation_logs'), isEmpty);
  });

  test('নাম ও ফোন দিয়ে সার্চ', () async {
    await repo.insert(_donor());
    await repo.insert(_donor(phone: '01812345678', name: 'সালমা'));
    expect((await repo.search(const DonorFilter(query: 'সালমা'))).length, 1);
    expect((await repo.search(const DonorFilter(query: '০১৮১২'))).length, 1);
    expect((await repo.search(const DonorFilter(query: '+8801712'))).length, 1);
  });

  test('শুধু যোগ্য ফিল্টার', () async {
    await repo.insert(_donor(last: daysAgo(6)));
    await repo.insert(_donor(phone: '01812345678', name: 'সালমা', last: daysAgo(300)));
    final eligible = await repo.search(
      const DonorFilter(eligibleOnly: true),
    );
    expect(eligible.single.name, 'সালমা');
  });

  group('ব্যাকআপ ও রিস্টোর', () {
    test('ব্যাকআপ থেকে রিস্টোর ডেটা ফেরায়', () async {
      final id = await repo.insert(_donor());
      await repo.markDonated(id, recent);

      final text = jsonEncode(await backup.buildBackup());
      await repo.delete(id);
      await repo.insert(_donor(phone: '01999999999', name: 'অন্য'));

      await backup.restore(backup.parseBackup(text));

      final donors = await repo.search(const DonorFilter());
      expect(donors.single.name, 'রহিম');
      expect(donors.single.totalDonations, 1);
      expect(await db.query('donation_logs'), hasLength(1));
      expect(docs.listSync().any((f) => f.path.contains('pre_restore_')), isTrue);
    });

    test('খারাপ ফাইল বাতিল হয়, বর্তমান তথ্য অক্ষত থাকে', () async {
      await repo.insert(_donor());
      final bad = jsonEncode({
        'schema_version': 1,
        'donors': [
          {..._donor().toMap(), 'id': 1},
          {..._donor(name: 'করিম').toMap(), 'id': 2},
        ],
        'donation_logs': <Object>[],
      });
      expect(() => backup.parseBackup(bad), throwsA(isA<BackupException>()));
      expect(await repo.search(const DonorFilter()), hasLength(1));
    });

    test('নতুন স্কিমা ভার্সন প্রত্যাখ্যাত', () {
      final text = jsonEncode({'schema_version': 99, 'donors': <Object>[], 'donation_logs': <Object>[]});
      expect(() => backup.parseBackup(text), throwsA(isA<BackupException>()));
    });

    test('ভাঙা JSON প্রত্যাখ্যাত', () {
      expect(() => backup.parseBackup('{oops'), throwsA(isA<BackupException>()));
    });
  });
}
