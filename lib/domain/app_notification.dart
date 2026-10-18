import '../core/date_format.dart';
import '../core/digits.dart';
import '../data/donor.dart';
import 'eligibility.dart';

/// বিজ্ঞপ্তির ধরন
enum NotificationType {
  donorReady, // রক্তদানে প্রস্তুত ডোনার
  syncSuccess, // ক্লাউড সিঙ্ক সফল
  syncAlert, // সিঙ্ক সতর্কতা
  emergencyNotice, // জরুরি রক্তের আবেদন
  system, // সিস্টেম
}

/// অ্যাপের নোটিফিকেশন মডেল
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    this.donorId,
    this.donorName,
    this.donorPhone,
    this.bloodGroup,
    this.district,
    this.area,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final int? donorId;
  final String? donorName;
  final String? donorPhone;
  final String? bloodGroup;
  final String? district;
  final String? area;

  AppNotification copyWith({
    String? id,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    int? donorId,
    String? donorName,
    String? donorPhone,
    String? bloodGroup,
    String? district,
    String? area,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      donorId: donorId ?? this.donorId,
      donorName: donorName ?? this.donorName,
      donorPhone: donorPhone ?? this.donorPhone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      district: district ?? this.district,
      area: area ?? this.area,
    );
  }

  /// ডোনার অবজেক্ট থেকে রক্তদানের উপযুক্ততার নোটিফিকেশন তৈরি
  static AppNotification? fromDonorEligibility(Donor donor, {DateTime? today}) {
    if (donor.lastDonationDate == null || donor.id == null) return null;
    final now = today ?? DateTime.now();
    final check = Eligibility.check(
      gender: donor.gender,
      lastDonationDate: donor.lastDonationDate,
      today: now,
    );

    if (!check.eligible) return null;

    final lastDate = parseIsoDate(donor.lastDonationDate);
    if (lastDate == null) return null;

    final cooldown = Eligibility.cooldownDays(donor.gender);
    final eligibleSince = lastDate.add(Duration(days: cooldown));
    final daysPassed = dateOnlyUtc(now).difference(dateOnlyUtc(eligibleSince)).inDays;

    // শুধুমাত্র গত ৩০ দিনের মধ্যে উপযুক্ত হওয়া অথবা আজ উপযুক্ত হওয়া ডোনারদের অ্যালার্ট
    if (daysPassed < 0 || daysPassed > 30) return null;

    final timingText = daysPassed == 0
        ? 'আজ থেকে রক্তদানের জন্য প্রস্তুত!'
        : '${toBanglaDigits(daysPassed)} দিন আগে রক্তদানের বিরতি পূর্ণ হয়েছে।';

    return AppNotification(
      id: 'ready_donor_${donor.id}_${donor.lastDonationDate}',
      type: NotificationType.donorReady,
      title: 'রক্তদাতা ${donor.name} (${donor.bloodGroup}) প্রস্তুত',
      message: '$timingText (${donor.district})',
      timestamp: eligibleSince,
      donorId: donor.id,
      donorName: donor.name,
      donorPhone: donor.phone,
      bloodGroup: donor.bloodGroup,
      district: donor.district,
      area: donor.area,
    );
  }
}
