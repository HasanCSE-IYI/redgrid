import 'package:flutter/material.dart';

/// রক্তদানের সংখ্যার ভিত্তিতে ডোনারদের জন্য স্বীকৃতিসূচক ব্যাজ।
class DonorMilestone {
  const DonorMilestone({
    required this.title,
    required this.badgeIcon,
    required this.badgeColor,
  });

  final String title;
  final String badgeIcon;
  final Color badgeColor;

  static DonorMilestone forCount(int count) {
    if (count >= 10) {
      return const DonorMilestone(
        title: 'গোল্ডেন লাইফসেভার',
        badgeIcon: '🥇',
        badgeColor: Color(0xFFD4AF37),
      );
    } else if (count >= 5) {
      return const DonorMilestone(
        title: 'সিলভার ডোনার',
        badgeIcon: '🥈',
        badgeColor: Color(0xFF78909C),
      );
    } else if (count >= 3) {
      return const DonorMilestone(
        title: 'ব্রোঞ্জ ডোনার',
        badgeIcon: '🥉',
        badgeColor: Color(0xFFCD7F32),
      );
    } else if (count >= 1) {
      return const DonorMilestone(
        title: 'নিয়মিত ডোনার',
        badgeIcon: '🩸',
        badgeColor: Color(0xFFC62828),
      );
    } else {
      return const DonorMilestone(
        title: 'নতুন ডোনার',
        badgeIcon: '🌱',
        badgeColor: Color(0xFF2E7D32),
      );
    }
  }
}
