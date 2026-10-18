import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../data/donor_repository.dart';
import '../domain/eligibility.dart';
import '../domain/milestones.dart';
import '../providers.dart';
import '../services/contact_service.dart';
import 'notification_center_sheet.dart';

export 'notification_center_sheet.dart' show AppNotificationToast;

/// রক্তের গ্রুপ প্রদর্শনকারী প্রিমিয়াম ব্যাজ উইজেট
class BloodGroupBadge extends StatelessWidget {
  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.size = 48,
    this.fontSize = 18,
    this.borderRadius = 12,
    this.filled = false,
    this.isCompatibleMatch = false,
  });

  final String bloodGroup;
  final double size;
  final double fontSize;
  final double borderRadius;
  final bool filled;
  final bool isCompatibleMatch;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return Container(
        width: size,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: kCrimson,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: kCrimson.withValues(alpha: 0.28),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              bloodGroup,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: fontSize,
                letterSpacing: 0.4,
              ),
            ),
            if (isCompatibleMatch) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.amber.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  Strings.matchBadge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D4037),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

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

/// ডোনার স্বীকৃতি মাইলস্টোন ব্যাজ
class MilestoneBadge extends StatelessWidget {
  const MilestoneBadge({
    super.key,
    required this.totalDonations,
    this.showCount = true,
  });

  final int totalDonations;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final milestone = DonorMilestone.forCount(totalDonations);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: milestone.badgeColor.withValues(alpha: isDark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: milestone.badgeColor.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(milestone.badgeIcon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            showCount
                ? '${milestone.title} • ${toBanglaDigits(totalDonations)} বার'
                : milestone.title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : milestone.badgeColor,
            ),
          ),
        ],
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
    final String tooltip;
    if (check.eligible) {
      label = Strings.readyToDonate;
      tooltip = Strings.donorReadyTooltip;
    } else {
      final daysBn = toBanglaDigits(check.daysLeft);
      label = 'আর $daysBn দিন পর যোগ্য';
      tooltip = '${Strings.nextEligiblePrefix} ${formatDateBn(check.nextEligibleDate!)}';
    }

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.5, vertical: 3.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
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
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
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

/// ডোনার কার্ডের ডায়নামিক বর্ডার (কমপ্যাক্ট ও ফুল কার্ড উভয়ের জন্য)
BorderSide donorCardBorderSide(ThemeData theme, {required bool isCompatibleMatch}) {
  final isDark = theme.brightness == Brightness.dark;
  return BorderSide(
    color: isCompatibleMatch
        ? Colors.amber.shade400
        : theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45),
    width: isCompatibleMatch ? 1.5 : 1.0,
  );
}

/// ডোনারের সাথে যোগাযোগের সার্বজনীন অ্যাকশন হেল্পার
class DonorContactActions {
  DonorContactActions._();

  static Future<void> call(BuildContext context, String phone) async {
    final ok = await ContactService.makeCall(phone);
    if (!ok && context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.callFailed,
        icon: Icons.call_end_rounded,
        color: kCrimson,
      );
    }
  }

  static Future<void> whatsapp(
    BuildContext context, {
    required String phone,
    required String donorName,
    required String bloodGroup,
    String? patientHospital,
  }) async {
    final ok = await ContactService.contactDonorWhatsApp(
      phone: phone,
      donorName: donorName,
      bloodGroup: bloodGroup,
      patientHospital: patientHospital,
    );
    if (!ok && context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.whatsappFailed,
        icon: Icons.chat_bubble_outline_rounded,
        color: kCrimson,
      );
    }
  }

  static Future<void> sms(
    BuildContext context, {
    required String phone,
    required String donorName,
    required String bloodGroup,
    String? patientHospital,
  }) async {
    final message = ContactService.composeDonorMessage(
      donorName: donorName,
      bloodGroup: bloodGroup,
      patientHospital: patientHospital,
    );
    final ok = await ContactService.openSms(phone: phone, message: message);
    if (!ok && context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.smsFailed,
        icon: Icons.sms_failed_rounded,
        color: kCrimson,
      );
    }
  }

  static Future<void> copyPhone(BuildContext context, String phone) async {
    await ContactService.copyToClipboard(phone);
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.phoneCopied,
        icon: Icons.copy_rounded,
      );
    }
  }
}

/// রক্তদানের তারিখ নির্বাচন ও ডাটাবেজে রেকর্ড করার সার্বজনীন লজিক
Future<bool> handleMarkDonation(
  BuildContext context,
  WidgetRef ref,
  Donor donor, {
  DateTime? initialDate,
}) async {
  final picked = initialDate ?? await pickDonationDate(context, firstDate: DateTime(1970));
  if (picked == null || !context.mounted) return false;

  final notifier = ref.read(donorListProvider.notifier);
  final previousLast = donor.lastDonationDate;
  final date = isoDate(picked);

  try {
    final result = await notifier.markDonated(donor.id!, date);
    if (!context.mounted) return false;
    if (result == MarkDonatedResult.alreadyLogged) {
      AppNotificationToast.show(
        context,
        message: Strings.alreadyLogged,
        icon: Icons.info_outline_rounded,
      );
      return false;
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text(Strings.donationSaved),
        action: SnackBarAction(
          label: Strings.undo,
          onPressed: () => notifier.undo(donor.id!, date, previousLast),
        ),
      ));
      return true;
    }
  } catch (_) {
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.genericError,
        icon: Icons.error_outline_rounded,
        color: kCrimson,
      );
    }
    return false;
  }
}
