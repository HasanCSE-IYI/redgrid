import '../core/constants.dart';
import '../core/date_format.dart';

class EligibilityResult {
  const EligibilityResult({required this.eligible, this.nextEligibleDate, this.daysLeft = 0});

  final bool eligible;

  /// অযোগ্য হলে যে তারিখ থেকে যোগ্য হবে (UTC, শুধু তারিখ)।
  final DateTime? nextEligibleDate;
  final int daysLeft;
}

class Eligibility {
  Eligibility._();

  static int cooldownDays(String gender) =>
      gender == AppConstants.genderFemale ? AppConstants.femaleCooldownDays : AppConstants.maleCooldownDays;

  /// পুরুষ ৯০ দিন, মহিলা ১২০ দিন। আগের দানের তারিখ না থাকলে যোগ্য।
  static EligibilityResult check({
    required String gender,
    required String? lastDonationDate,
    required DateTime today,
  }) {
    final last = parseIsoDate(lastDonationDate);
    if (last == null) return const EligibilityResult(eligible: true);

    final next = last.add(Duration(days: cooldownDays(gender)));
    final daysLeft = next.difference(dateOnlyUtc(today)).inDays;
    if (daysLeft <= 0) return const EligibilityResult(eligible: true);
    return EligibilityResult(eligible: false, nextEligibleDate: next, daysLeft: daysLeft);
  }
}
