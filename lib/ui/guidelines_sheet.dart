import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/strings_bn.dart';

/// রক্তদান সহায়িকা, যোগ্যতা ও স্বাস্থ্যবিধি সংক্রান্ত নির্দেশিকা শিট।
class GuidelinesSheet extends StatelessWidget {
  const GuidelinesSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const GuidelinesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        children: [
          // ড্র্যাগ হ্যান্ডেল
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // হেডার
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: kCrimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.health_and_safety_rounded, color: kCrimson, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        Strings.guidelinesTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        Strings.guidelinesSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: Strings.cancel,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // গাইডলাইন কনটেন্ট তালিকা
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _GuidelineCard(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: kEligibleGreen,
                  title: 'কারা রক্ত দিতে পারবেন (শারীরিক যোগ্যতা)',
                  items: const [
                    'বয়স: ১৮ থেকে ৬০ বছর (নিয়মিত ডোনারদের ক্ষেত্রে ৬৫ বছর পর্যন্ত)।',
                    'ওজন: পুরুষদের ক্ষেত্রে অন্তত ৫০ কেজি, নারীদের ক্ষেত্রে অন্তত ৪৫ কেজি।',
                    'হিমোগ্লোবিন: পুরুষদের ন্যূনতম ১২.৫ গ্রাম/ডেসিলিটার, নারীদের ১২.০ গ্রাম/ডেসিলিটার।',
                    'রক্তচাপ ও পালস: রক্তচাপ সিস্টলিক ১০০-১৪০ ও ডায়াস্টলিক ৬০-৯০ মিমি মার্কারির মধ্যে স্বাভাবিক হতে হবে।',
                    'বিরতি: পুরুষদের ক্ষেত্রে অন্তত ৩ মাস (৯০ দিন) এবং নারীদের ক্ষেত্রে ৪ মাস (১২০ দিন) পূর্বে রক্তদান করেননি।',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _GuidelineCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFE65100),
                  title: 'কারা সাময়িক রক্ত দিতে পারবেন না (অস্থায়ী বিরতি)',
                  items: const [
                    'অ্যান্টিবায়োটিক বা রক্ত পাতলাকারী ওষুধ সেবনরত থাকলে (কোর্স শেষ হওয়ার অন্তত ৭ দিন পর)।',
                    'দাঁত তোলা বা ছোট সার্জারি করালে অন্তত ১ মাস বিরতি প্রয়োজন।',
                    'বড় কোনো অপারেশন বা নিজে রক্ত গ্রহণ করলে অন্তত ১২ মাস বিরতি দিতে হবে।',
                    'ট্যাটু, পিয়ার্সিং বা আকুপাংচার করালে অন্তত ৬ মাস বিরতি বাধ্যতামূলক।',
                    'টাইফয়েড, ম্যালেরিয়া বা জন্ডিস হলে সুস্থ হওয়ার নির্দিষ্ট মেয়াদ পর্যন্ত রক্ত দেওয়া নিষেধ।',
                    'গর্ভবতী বা স্তন্যদানকারী মায়েরা প্রসব ও স্তন্যদান সম্পন্ন হওয়ার ৬ মাস পর্যন্ত রক্ত দিতে পারবেন না।',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _GuidelineCard(
                  icon: Icons.water_drop_outlined,
                  iconColor: const Color(0xFF0288D1),
                  title: 'রক্তদানের পূর্বে প্রস্তুতি',
                  items: const [
                    'পূর্ববর্তী রাতে অন্তত ৬ থেকে ৮ ঘণ্টা পর্যাপ্ত ও ভালো ঘুম নিশ্চিত করুন।',
                    'রক্তদানের ২-৩ ঘণ্টা পূর্বে পুষ্টিকর ও সহজপাচ্য খাবার খান; কখনোই খালি পেটে রক্ত দেবেন না।',
                    'রক্তদানের আগে প্রচুর পানি, ফলের জুস বা তরল পান করুন।',
                    'রক্তদানের পূর্ববর্তী অন্তত ৩ ঘণ্টা ধূমপান এবং চা/কফি পরিহার করা উত্তম।',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _GuidelineCard(
                  icon: Icons.bed_outlined,
                  iconColor: const Color(0xFF5E35B1),
                  title: 'রক্তদানের পরবর্তী যত্ন ও সতর্কতা',
                  items: const [
                    'রক্তদানের পর তাড়াহুড়ো না করে অন্তত ১৫-২০ মিনিট বেডে বা চেয়ারে শান্তভাবে বিশ্রাম নিন।',
                    'রক্তদানের পর স্যালাইন, জুস বা অন্তত ২-৩ গ্লাস বিশুদ্ধ পানি পান করুন।',
                    'পরবর্তী ৪-৫ ঘণ্টা ভারী ওজন তোলা, ব্যায়াম বা কায়িক পরিশ্রম করা পরিহার করুন।',
                    'ইনজেকশন পয়েন্টের প্লাস্টার বা ব্যান্ডেজ অন্তত ৩-৪ ঘণ্টা লাগিয়ে রাখুন।',
                    'হঠাৎ মাথা ঘুরলে তৎক্ষণাৎ বসে বা শুয়ে পড়ুন এবং পা দুটি সামান্য উঁচু করে রাখুন।',
                  ],
                  isDark: isDark,
                ),
                const SizedBox(height: 12),

                _GuidelineCard(
                  icon: Icons.volunteer_activism_rounded,
                  iconColor: kCrimson,
                  title: 'রক্তদানের বৈজ্ঞানিক উপকারিতা',
                  items: const [
                    'নিয়মিত রক্তদানে শরীরে অতিরিক্ত ক্ষতিকর আয়রন হ্রাস পায়, যা হৃদরোগ ও স্ট্রোকের ঝুঁকি কমায়।',
                    'অস্থিমজ্জা (Bone marrow) উদ্দীপিত হয়ে দ্রুত নতুন ও সতেজ লোহিত রক্তকণিকা তৈরি করে।',
                    'বিনামূল্যে রক্তচাপ, হেপাটাইটিস বি ও সি, সিফিলিস ও ম্যালেরিয়ার প্রাথমিক পরীক্ষা হয়ে যায়।',
                    'মানসিক প্রশান্তি বাড়ে এবং একটি মূল্যবান মানবজীবন বাঁচানোর আনন্দ পাওয়া যায়।',
                  ],
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidelineCard extends StatelessWidget {
  const _GuidelineCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.items,
    required this.isDark,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final List<String> items;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: iconColor.withValues(alpha: isDark ? 0.25 : 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
