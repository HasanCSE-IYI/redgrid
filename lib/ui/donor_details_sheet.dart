import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../providers.dart';
import 'blood_widgets.dart';

/// বাংলা মাসের নাম দিয়ে পূর্ণাঙ্গ তারিখ ফরম্যাট (যেমন: ১৯ অক্টোবর, ২০২৬)
String _formatFullDateBn(String isoDate) {
  final parsed = parseIsoDate(isoDate);
  if (parsed == null) return toBanglaDigits(isoDate);
  const months = [
    'জানুয়ারি',
    'ফেব্রুয়ারি',
    'মার্চ',
    'এপ্রিল',
    'মে',
    'জুন',
    'জুলাই',
    'আগস্ট',
    'সেপ্টেম্বর',
    'অক্টোবর',
    'নভেম্বর',
    'ডিসেম্বর',
  ];
  final day = toBanglaDigits(parsed.day);
  final month = months[parsed.month - 1];
  final year = toBanglaDigits(parsed.year);
  return '$day $month, $year';
}

/// রক্তদানের আপেক্ষিক সময় (যেমন: আজকে • সর্বশেষ রক্তদান, ৩ মাস আগে)
String _formatDonationSubtitle(String isoDate, int index) {
  final parsed = parseIsoDate(isoDate);
  if (parsed == null) return '';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(parsed.year, parsed.month, parsed.day);
  final diffDays = today.difference(date).inDays;

  final String relative;
  if (diffDays == 0) {
    relative = 'আজকে';
  } else if (diffDays == 1) {
    relative = 'গতকাল';
  } else if (diffDays < 30) {
    relative = '${toBanglaDigits(diffDays)} দিন আগে';
  } else if (diffDays < 365) {
    final months = (diffDays / 30).floor();
    relative = '${toBanglaDigits(months <= 0 ? 1 : months)} মাস আগে';
  } else {
    final years = (diffDays / 365).floor();
    relative = '${toBanglaDigits(years <= 0 ? 1 : years)} বছর আগে';
  }

  if (index == 0) {
    return '$relative • সর্বশেষ রক্তদান';
  }
  return relative;
}

/// ডোনার প্রোফাইল, সরাসরি যোগাযোগ এবং রক্তদানের ইতিহাস টাইমলাইন।
class DonorDetailsSheet extends ConsumerStatefulWidget {
  const DonorDetailsSheet({super.key, required this.donor});

  final Donor donor;

  static Future<void> show(BuildContext context, Donor donor) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => DonorDetailsSheet(donor: donor),
    );
  }

  @override
  ConsumerState<DonorDetailsSheet> createState() => _DonorDetailsSheetState();
}

class _DonorDetailsSheetState extends ConsumerState<DonorDetailsSheet> {
  bool _busy = false;

  Future<void> _call() => DonorContactActions.call(context, widget.donor.phone);

  Future<void> _sendWhatsApp() => DonorContactActions.whatsapp(
        context,
        phone: widget.donor.phone,
        donorName: widget.donor.name,
        bloodGroup: widget.donor.bloodGroup,
      );

  Future<void> _sendSms() => DonorContactActions.sms(
        context,
        phone: widget.donor.phone,
        donorName: widget.donor.name,
        bloodGroup: widget.donor.bloodGroup,
      );

  Future<void> _addDonationDate() async {
    setState(() => _busy = true);
    await handleMarkDonation(context, ref, widget.donor);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _deleteDate(String date) async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteLogConfirmTitle,
      message: Strings.deleteLogConfirmBody,
      confirmLabel: Strings.delete,
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(donorListProvider.notifier).deleteDonationDate(widget.donor.id!, date);
      if (mounted) {
        AppNotificationToast.show(context, message: Strings.logDeleted);
      }
    } catch (_) {
      if (mounted) {
        AppNotificationToast.show(context, message: Strings.genericError, color: kCrimson);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final donorsList = ref.watch(donorListProvider).asData?.value;
    // রিফ্রেশ হওয়া ডোনার ইনস্ট্যান্স ব্যবহার করা যাতে মোট দানের সংখ্যা রিয়েল-টাইম আপডেট থাকে
    final donor = donorsList?.firstWhere(
          (d) => d.id == widget.donor.id,
          orElse: () => widget.donor,
        ) ??
        widget.donor;

    final historyAsync = ref.watch(donationDatesProvider(donor.id!));

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BloodGroupBadge(
                  bloodGroup: donor.bloodGroup,
                  size: 54,
                  fontSize: 20,
                  filled: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        donor.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${donor.area}, ${donor.district}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // ফোন নম্বর ও কপি অপশন
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: donor.phone));
                          HapticFeedback.lightImpact();
                          AppNotificationToast.show(context, message: Strings.phoneCopied);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 13,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                donor.phone,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.copy_rounded,
                                size: 12,
                                color: theme.colorScheme.primary.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          MilestoneBadge(totalDonations: donor.totalDonations, showCount: true),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              donor.isFemale ? 'নারী ডোনার' : 'পুরুষ ডোনার',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
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
          if (donor.notes != null && donor.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.sticky_note_2_outlined,
                    size: 15,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      donor.notes!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          // যোগ্যতা স্ট্যাটাস ব্যানার
          EligibilityBanner(
            gender: donor.gender,
            lastDonationDate: donor.lastDonationDate,
          ),
          const SizedBox(height: 12),
          // যোগাযোগ বোতামসমূহ (Call, WhatsApp, SMS)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: Row(
                children: [
                  // কল করুন (Call)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _call,
                      style: FilledButton.styleFrom(
                        backgroundColor: kCrimson,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.call_rounded, size: 17),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Strings.call,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // হোয়াটসঅ্যাপ (WhatsApp)
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _sendWhatsApp,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Strings.whatsapp,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // মেসেজ (SMS)
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _sendSms,
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF262C36)
                            : const Color(0xFFEDF2F7),
                        foregroundColor: isDark
                            ? Colors.white
                            : const Color(0xFF2D3748),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.sms_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Strings.sms,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Divider(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      Strings.donationHistory,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        toBanglaDigits(donor.totalDonations),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _addDonationDate,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'তারিখ যোগ',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: historyAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text(Strings.errorLoad)),
              data: (dates) {
                if (dates.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            Strings.noHistory,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    final fullDateStr = _formatFullDateBn(date);
                    final subtitleStr = _formatDonationSubtitle(date, index);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? kCrimson.withValues(alpha: 0.15)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: index == 0
                                      ? kCrimson.withValues(alpha: 0.6)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                  width: index == 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(
                                Icons.water_drop_rounded,
                                size: 14,
                                color: index == 0 ? kCrimson : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (index < dates.length - 1)
                              Container(
                                width: 2,
                                height: 38,
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullDateStr,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                if (subtitleStr.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitleStr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: index == 0
                                          ? (isDark
                                              ? const Color(0xFFFF8A80)
                                              : kCrimson)
                                          : theme.colorScheme.onSurfaceVariant,
                                      fontWeight: index == 0 ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 19,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                          tooltip: Strings.delete,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _deleteDate(date),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
