import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../domain/milestones.dart';
import '../services/contact_service.dart';
import 'blood_widgets.dart';

/// রক্তদাতাকে সম্মাননা ও ধন্যবাদ জানানোর জন্য মার্জিত প্রিভিউ ডায়ালগ।
class AppreciationDialog extends StatelessWidget {
  const AppreciationDialog({super.key, required this.donor});

  final Donor donor;

  static Future<void> show(BuildContext context, Donor donor) {
    HapticFeedback.lightImpact();
    return showDialog<void>(
      context: context,
      builder: (_) => AppreciationDialog(donor: donor),
    );
  }

  String _buildText() {
    final milestone = DonorMilestone.forCount(donor.totalDonations);
    return ContactService.composeAppreciationMessage(
      donorName: donor.name,
      bloodGroup: donor.bloodGroup,
      totalDonations: donor.totalDonations,
      milestoneTitle: milestone.title,
    );
  }

  Future<void> _sendWhatsApp(BuildContext context) async {
    final text = _buildText();
    final ok = await ContactService.openWhatsApp(
      phone: donor.phone,
      message: text,
    );
    if (!ok && context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.whatsappFailed,
        color: kCrimson,
      );
    }
  }

  Future<void> _copy(BuildContext context) async {
    final text = _buildText();
    await ContactService.copyToClipboard(text);
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.appreciationCopied,
        icon: Icons.copy_rounded,
        color: kEligibleGreen,
      );
    }
  }

  Future<void> _share() async {
    final text = _buildText();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'লাইফসেভার সম্মাননা - ${donor.name}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final milestone = DonorMilestone.forCount(donor.totalDonations);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      elevation: 6,
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // হেডার
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kCrimson.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_rounded, color: kCrimson, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      Strings.appreciationTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: Strings.cancel,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // সার্টিফিকেট স্টাইল প্রিভিউ কার্ড
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                      : const Color(0xFFFDF8F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: kCrimson.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kCrimson.withValues(alpha: isDark ? 0.1 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    BloodGroupBadge(
                      bloodGroup: donor.bloodGroup,
                      size: 46,
                      fontSize: 17,
                      filled: true,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      donor.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: milestone.badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: milestone.badgeColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        '${milestone.badgeIcon} ${milestone.title} • ${toBanglaDigits(donor.totalDonations)} বার রক্তদান',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : milestone.badgeColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: kCrimson.withValues(alpha: 0.2),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'আপনার নিঃস্বার্থ রক্তদানে আজ রক্ষা পেয়েছে একটি মূল্যবান মানবজীবন। মানবতার সেবায় এমন অসাধারণ আত্মত্যাগের জন্য আমাদের আন্তরিক অভিনন্দন ও গভীর কৃতজ্ঞতা।',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '— RedGrid লাইফসেভার নেটওয়ার্ক',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFFF8A80) : kCrimson,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // একশন বাটনসমূহ
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _copy(context),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Copy',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      ),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Share',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // সরাসরি WhatsApp-এ সম্মাননা বার্তা পাঠানোর মূল বাটন
              FilledButton.icon(
                onPressed: () => _sendWhatsApp(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Send via WhatsApp',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
