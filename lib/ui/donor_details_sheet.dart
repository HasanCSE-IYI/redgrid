import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../providers.dart';
import 'blood_widgets.dart';

/// ডোনার প্রোফাইল, সরাসরি যোগাযোগ এবং রক্তদানের ইতিহাস টাইমলাইন।
class DonorDetailsSheet extends ConsumerStatefulWidget {
  const DonorDetailsSheet({super.key, required this.donor});

  final Donor donor;

  static Future<void> show(BuildContext context, Donor donor) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    final donorsList = ref.watch(donorListProvider).asData?.value;
    // রিফ্রেশ হওয়া ডোনার ইনস্ট্যান্স ব্যবহার করা যাতে মোট দানের সংখ্যা রিয়েল-টাইম আপডেট থাকে
    final donor = donorsList?.firstWhere(
          (d) => d.id == widget.donor.id,
          orElse: () => widget.donor,
        ) ??
        widget.donor;

    final historyAsync = ref.watch(donationDatesProvider(donor.id!));

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
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
                      Text(donor.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              '${donor.area}, ${donor.district}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      MilestoneBadge(totalDonations: donor.totalDonations, showCount: true),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // যোগ্যতা স্ট্যাটাস ব্যানার
          EligibilityBanner(
            gender: donor.gender,
            lastDonationDate: donor.lastDonationDate,
          ),
          const SizedBox(height: 12),
          // যোগাযোগ বোতামসমূহ
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call, size: 18),
                    label: const Text(Strings.call),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sendWhatsApp,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text(Strings.whatsapp),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendSms,
                    icon: const Icon(Icons.sms, size: 18),
                    label: const Text(Strings.sms),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  Strings.donationHistory,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _busy ? null : _addDonationDate,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(Strings.addDonationDate),
                ),
              ],
            ),
          ),
          Expanded(
            child: historyAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text(Strings.errorLoad)),
              data: (dates) {
                if (dates.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        Strings.noHistory,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: kCrimson.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                                border: Border.all(color: kCrimson.withValues(alpha: 0.4)),
                              ),
                              child: const Icon(Icons.water_drop_rounded, size: 14, color: kCrimson),
                            ),
                            if (index < dates.length - 1)
                              Container(
                                width: 2,
                                height: 36,
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
                                  formatIsoDateBn(date),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  date,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 19, color: Colors.grey),
                          tooltip: Strings.delete,
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
