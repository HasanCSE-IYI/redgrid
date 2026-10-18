import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/data/donor.dart';
import 'package:redgrid/domain/app_notification.dart';

void main() {
  group('AppNotification', () {
    test('fromDonorEligibility returns null when donor has no lastDonationDate', () {
      final donor = Donor(
        id: 1,
        name: 'রাকিব হাসান',
        bloodGroup: 'A+',
        gender: 'MALE',
        phone: '01712345678',
        district: 'ঢাকা',
        area: 'ধানমন্ডি',
      );
      final alert = AppNotification.fromDonorEligibility(donor);
      expect(alert, isNull);
    });

    test('fromDonorEligibility returns alert when cooldown is completed', () {
      final today = DateTime.utc(2026, 10, 18);
      // Male donor with last donation 95 days ago (cooldown 90 days)
      final donor = Donor(
        id: 2,
        name: 'তানভীর আহমেদ',
        bloodGroup: 'B+',
        gender: 'MALE',
        phone: '01812345678',
        district: 'চট্টগ্রাম',
        area: 'জিইসি',
        lastDonationDate: '2026-07-10', // 100 days ago
      );
      final alert = AppNotification.fromDonorEligibility(donor, today: today);
      expect(alert, isNotNull);
      expect(alert!.type, NotificationType.donorReady);
      expect(alert.title, contains('তানভীর আহমেদ'));
      expect(alert.title, contains('B+'));
      expect(alert.message, contains('চট্টগ্রাম'));
      expect(alert.donorPhone, '01812345678');
    });

    test('fromDonorEligibility returns null when cooldown is not yet completed', () {
      final today = DateTime.utc(2026, 10, 18);
      // Male donor donated 30 days ago (needs 90 days)
      final donor = Donor(
        id: 3,
        name: 'সাকিব আল হাসান',
        bloodGroup: 'O+',
        gender: 'MALE',
        phone: '01912345678',
        district: 'ঢাকা',
        area: 'মিরপুর',
        lastDonationDate: '2026-09-18',
      );
      final alert = AppNotification.fromDonorEligibility(donor, today: today);
      expect(alert, isNull);
    });

    test('copyWith updates properties correctly', () {
      final item = AppNotification(
        id: 'test_1',
        type: NotificationType.system,
        title: 'টেস্ট নোটিফিকেশন',
        message: 'এটি একটি বার্তা',
        timestamp: DateTime.utc(2026, 10, 18),
        isRead: false,
      );

      final updated = item.copyWith(isRead: true, title: 'আপডেটেড টাইটেল');
      expect(updated.isRead, isTrue);
      expect(updated.title, 'আপডেটেড টাইটেল');
      expect(updated.id, 'test_1');
      expect(updated.type, NotificationType.system);
    });
  });
}
