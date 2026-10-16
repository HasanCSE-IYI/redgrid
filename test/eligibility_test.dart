import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/constants.dart';
import 'package:redgrid/core/date_format.dart';
import 'package:redgrid/domain/eligibility.dart';

void main() {
  final today = DateTime.utc(2026, 10, 16);
  String daysAgo(int n) => isoDate(today.subtract(Duration(days: n)));

  test('আগের দান না থাকলে যোগ্য', () {
    final r = Eligibility.check(gender: AppConstants.genderMale, lastDonationDate: null, today: today);
    expect(r.eligible, isTrue);
  });

  group('পুরুষ ৯০ দিন', () {
    test('ঠিক ৯০ দিন পরে যোগ্য', () {
      final r = Eligibility.check(
          gender: AppConstants.genderMale, lastDonationDate: daysAgo(90), today: today);
      expect(r.eligible, isTrue);
    });
    test('৮৯ দিনে অযোগ্য, আর ১ দিন বাকি', () {
      final r = Eligibility.check(
          gender: AppConstants.genderMale, lastDonationDate: daysAgo(89), today: today);
      expect(r.eligible, isFalse);
      expect(r.daysLeft, 1);
      expect(r.nextEligibleDate, today);
    });
  });

  group('মহিলা ১২০ দিন', () {
    test('ঠিক ১২০ দিন পরে যোগ্য', () {
      final r = Eligibility.check(
          gender: AppConstants.genderFemale, lastDonationDate: daysAgo(120), today: today);
      expect(r.eligible, isTrue);
    });
    test('১১৯ দিনে অযোগ্য', () {
      final r = Eligibility.check(
          gender: AppConstants.genderFemale, lastDonationDate: daysAgo(119), today: today);
      expect(r.eligible, isFalse);
      expect(r.daysLeft, 1);
    });
    test('৯০ দিনে মহিলা এখনো অযোগ্য', () {
      final r = Eligibility.check(
          gender: AppConstants.genderFemale, lastDonationDate: daysAgo(90), today: today);
      expect(r.eligible, isFalse);
      expect(r.daysLeft, 30);
    });
  });

  test('ভুল তারিখ হলে তারিখ নেই ধরে যোগ্য', () {
    final r = Eligibility.check(
        gender: AppConstants.genderMale, lastDonationDate: '2026-02-31', today: today);
    expect(r.eligible, isTrue);
  });
}
