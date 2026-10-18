import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../domain/eligibility.dart';

export 'notification_center_sheet.dart' show AppNotificationToast;

/// রক্তের গ্রুপ প্রদর্শনকারী প্রিমিয়াম ব্যাজ উইজেট
class BloodGroupBadge extends StatelessWidget {
  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.size = 48,
    this.fontSize = 18,
    this.borderRadius = 12,
  });

  final String bloodGroup;
  final double size;
  final double fontSize;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: kCrimson.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: kCrimson.withValues(alpha: 0.35), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Text(
        bloodGroup,
        style: TextStyle(
          color: kCrimson,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// রক্তদানের উপযুক্ততা (Eligibility) নির্দেশক স্ট্যাটাস পিল
class EligibilityPill extends StatelessWidget {
  const EligibilityPill({
    super.key,
    required this.gender,
    required this.lastDonationDate,
    this.today,
  });

  final String gender;
  final String? lastDonationDate;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final check = Eligibility.check(
      gender: gender,
      lastDonationDate: lastDonationDate,
      today: now,
    );

    final color = check.eligible ? kEligibleGreen : kWaitSlate;
    final icon = check.eligible ? Icons.check_circle_rounded : Icons.access_time_rounded;

    final String label;
    if (check.eligible) {
      label = Strings.readyToDonate;
    } else {
      final daysBn = toBanglaDigits(check.daysLeft);
      label = 'আর $daysBn দিন পর যোগ্য';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// রক্তদানের যোগ্যতা সম্পর্কিত পূর্ণাঙ্গ তথ্য ব্যানার
class EligibilityBanner extends StatelessWidget {
  const EligibilityBanner({
    super.key,
    required this.gender,
    required this.lastDonationDate,
    this.today,
  });

  final String gender;
  final String? lastDonationDate;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    final now = today ?? DateTime.now();
    final check = Eligibility.check(
      gender: gender,
      lastDonationDate: lastDonationDate,
      today: now,
    );

    final color = check.eligible ? kEligibleGreen : kWaitSlate;
    final icon = check.eligible ? Icons.check_circle_rounded : Icons.hourglass_bottom_rounded;

    final String text;
    if (check.eligible) {
      text = lastDonationDate == null ? Strings.eligibleNoDate : Strings.eligible;
    } else {
      text = Strings.eligibleIn(check.daysLeft, formatDateBn(check.nextEligibleDate!));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: color,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// স্ট্যান্ডার্ড কনফার্মেশন ডায়ালগ
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = Strings.continueLabel,
  String cancelLabel = Strings.cancel,
  bool isDestructive = false,
}) async {
  HapticFeedback.mediumImpact();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Text(message, style: const TextStyle(fontSize: 14)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: kCrimson,
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// রক্তদানের তারিখ নির্বাচনের স্ট্যান্ডার্ড ডেট পিকার
Future<DateTime?> pickDonationDate(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  HapticFeedback.lightImpact();
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initialDate ?? now,
    firstDate: firstDate ?? DateTime(2000),
    lastDate: lastDate ?? now,
  );
}
