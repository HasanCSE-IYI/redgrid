import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/data/app_database.dart';
import 'package:redgrid/data/donor.dart';
import 'package:redgrid/data/donor_repository.dart';
import 'package:redgrid/domain/compatibility.dart';
import 'package:redgrid/domain/milestones.dart';
import 'package:redgrid/services/contact_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Donor _makeDonor({
  required String name,
  required String bloodGroup,
  required String phone,
  String? lastDate,
}) {
  return Donor(
    name: name,
    bloodGroup: bloodGroup,
    gender: 'MALE',
    phone: phone,
    consentToShare: true,
    district: 'ঢাকা',
    area: 'মিরপুর',
    lastDonationDate: lastDate,
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('BloodCompatibility Unit Tests', () {
    test('A+ এর জন্য সামঞ্জস্যপূর্ণ দাতা সমূহ', () {
      final donors = BloodCompatibility.compatibleDonorsFor('A+');
      expect(donors, containsAllInOrder(['A+', 'A-', 'O+', 'O-']));
      expect(donors.first, 'A+');
    });

    test('AB+ সর্বজনীন গ্রহীতা (Universal Recipient)', () {
      final donors = BloodCompatibility.compatibleDonorsFor('AB+');
      expect(donors, containsAll(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']));
    });

    test('O- শুধুমাত্র O- থেকে রক্ত গ্রহণ করতে পারে', () {
      final donors = BloodCompatibility.compatibleDonorsFor('O-');
      expect(donors, ['O-']);
    });

    test('O- সর্বজনীন দাতা (Universal Donor)', () {
      final recipients = BloodCompatibility.canDonateTo('O-');
      expect(recipients, containsAll(['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']));
    });

    test('isCompatible সঠিক ফলাফল দেয়', () {
      expect(BloodCompatibility.isCompatible(donorGroup: 'O-', recipientGroup: 'B+'), isTrue);
      expect(BloodCompatibility.isCompatible(donorGroup: 'B+', recipientGroup: 'A+'), isFalse);
      expect(BloodCompatibility.isCompatible(donorGroup: 'A+', recipientGroup: 'AB+'), isTrue);
    });
  });

  group('DonorMilestone Tests', () {
    test('রক্তদানের সংখ্যার ভিত্তিতে সঠিক ব্যাজ প্রদান', () {
      expect(DonorMilestone.forCount(0).title, 'নতুন ডোনার');
      expect(DonorMilestone.forCount(1).title, 'নিয়মিত ডোনার');
      expect(DonorMilestone.forCount(3).title, 'ব্রোঞ্জ ডোনার');
      expect(DonorMilestone.forCount(5).title, 'সিলভার ডোনার');
      expect(DonorMilestone.forCount(10).title, 'গোল্ডেন লাইফসেভার');
      expect(DonorMilestone.forCount(25).title, 'গোল্ডেন লাইফসেভার');
    });
  });

  group('ContactService Tests', () {
    test('হোয়াটসঅ্যাপের জন্য ফোন নম্বর রূপান্তর', () {
      expect(ContactService.formatForWhatsApp('01712345678'), '8801712345678');
      expect(ContactService.formatForWhatsApp('+8801712345678'), '8801712345678');
    });

    test('জরুরি পোস্ট ফরম্যাট প্রস্তুত', () {
      final post = ContactService.composeBroadcastPost(
        bloodGroup: 'B+',
        units: '১ ব্যাগ',
        hospital: 'ঢাকা মেডিকেল কলেজ',
        when: 'আজ বিকেল ৫টা',
        reason: 'জরুরি সার্জারি',
        contactPhone: '01711111111',
      );
      expect(post, contains('B+'));
      expect(post, contains('ঢাকা মেডিকেল কলেজ'));
      expect(post, contains('01711111111'));
      expect(post, contains('জরুরি_রক্তের_প্রয়োজন'));
    });

    test('মার্জিত ডোনার বার্তা প্রস্তুত', () {
      final msg = ContactService.composeDonorMessage(
        donorName: 'সাকিব',
        bloodGroup: 'O+',
        patientHospital: 'পিজি হাসপাতাল',
      );
      expect(msg, contains('সাকিব'));
      expect(msg, contains('O+'));
      expect(msg, contains('পিজি হাসপাতাল'));
    });
  });

  group('Repository Compatibility & Timeline Tests', () {
    late Database db;
    late DonorRepository repo;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: AppDatabase.configure,
        onCreate: AppDatabase.create,
      );
      repo = DonorRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('সামঞ্জস্যপূর্ণ গ্রুপ সহ সার্চ এবং সঠিক অগ্রাধিকার ক্রম', () async {
      await repo.insert(_makeDonor(name: 'জাহিদ', bloodGroup: 'O+', phone: '01700000001'));
      await repo.insert(_makeDonor(name: 'আরিফ', bloodGroup: 'A+', phone: '01700000002'));
      await repo.insert(_makeDonor(name: 'কামাল', bloodGroup: 'A-', phone: '01700000003'));
      await repo.insert(_makeDonor(name: 'তানভীর', bloodGroup: 'B+', phone: '01700000004'));
      await repo.insert(_makeDonor(name: 'নিলয়', bloodGroup: 'AB+', phone: '01700000005'));

      // সাধারণ সার্চ (শুধু A+)
      final exactOnly = await repo.search(const DonorFilter(bloodGroup: 'A+'));
      expect(exactOnly.length, 1);
      expect(exactOnly.first.bloodGroup, 'A+');

      // সামঞ্জস্যপূর্ণ গ্রুপ সহ সার্চ (A+, A-, O+, O-)
      final compatible = await repo.search(
        const DonorFilter(bloodGroup: 'A+', includeCompatible: true),
      );
      expect(compatible.length, 3);
      final groups = compatible.map((d) => d.bloodGroup).toList();
      expect(groups, containsAll(['A+', 'A-', 'O+']));
      // A+ exact match সবার আগে র‍্যাঙ্ক হবে
      expect(compatible.first.bloodGroup, 'A+');
    });

    test('getStats সঠিক পরিসংখ্যান দেয়', () async {
      final id1 = await repo.insert(_makeDonor(name: 'ডোনার ১', bloodGroup: 'A+', phone: '01700000011'));
      final id2 = await repo.insert(_makeDonor(name: 'ডোনার ২', bloodGroup: 'B+', phone: '01700000012'));
      await repo.markDonated(id1, '2026-01-01');
      await repo.markDonated(id1, '2026-05-01');
      await repo.markDonated(id2, '2026-03-01');

      final stats = await repo.getStats();
      expect(stats.totalDonors, 2);
      expect(stats.totalDonations, 3);
      expect(stats.eligibleToday, isNonNegative);
    });

    test('রক্তদানের তারিখ তালিকা এবং নির্দিষ্ট তারিখ মুছে ফেলা', () async {
      final id = await repo.insert(_makeDonor(name: 'হাসান', bloodGroup: 'O+', phone: '01700000021'));
      await repo.markDonated(id, '2026-01-15');
      await repo.markDonated(id, '2026-04-20');
      await repo.markDonated(id, '2026-08-10');

      var dates = await repo.getDonationDates(id);
      expect(dates, ['2026-08-10', '2026-04-20', '2026-01-15']);

      var donor = (await repo.search(const DonorFilter(query: 'হাসান'))).single;
      expect(donor.totalDonations, 3);
      expect(donor.lastDonationDate, '2026-08-10');

      // সর্বশেষ রক্তদানের তারিখটি মুছে ফেলা
      await repo.deleteDonationDate(id, '2026-08-10');

      dates = await repo.getDonationDates(id);
      expect(dates, ['2026-04-20', '2026-01-15']);

      donor = (await repo.search(const DonorFilter(query: 'হাসান'))).single;
      expect(donor.totalDonations, 2);
      expect(donor.lastDonationDate, '2026-04-20');
    });
  });
}
