import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _call() async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = widget.donor.phone;
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: phone));
      if (!ok && mounted) {
        messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
      }
    }
  }

  Future<void> _sendWhatsApp() async {
    final messenger = ScaffoldMessenger.of(context);
    final donor = widget.donor;
    final message = ContactService.composeDonorMessage(
      donorName: donor.name,
      bloodGroup: donor.bloodGroup,
    );
    final ok = await ContactService.openWhatsApp(phone: donor.phone, message: message);
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.whatsappFailed)));
    }
  }

  Future<void> _sendSms() async {
    final messenger = ScaffoldMessenger.of(context);
    final donor = widget.donor;
    final message = ContactService.composeDonorMessage(
      donorName: donor.name,
      bloodGroup: donor.bloodGroup,
    );
    final ok = await ContactService.openSms(phone: donor.phone, message: message);
    if (!ok && mounted) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.smsFailed)));
    }
  }

  Future<void> _addDonationDate() async {
    final donor = widget.donor;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1970),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(donorListProvider.notifier);
    final date = isoDate(picked);

    setState(() => _busy = true);
    try {
      final result = await notifier.markDonated(donor.id!, date);
      messenger.hideCurrentSnackBar();
      if (result == MarkDonatedResult.alreadyLogged) {
        messenger.showSnackBar(const SnackBar(content: Text(Strings.alreadyLogged)));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text(Strings.donationSaved)));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteDate(String date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.deleteLogConfirmTitle),
        content: const Text(Strings.deleteLogConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(Strings.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(donorListProvider.notifier).deleteDonationDate(widget.donor.id!, date);
      messenger.showSnackBar(const SnackBar(content: Text(Strings.logDeleted)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
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

    final milestone = DonorMilestone.forCount(donor.totalDonations);
    final result = Eligibility.check(
      gender: donor.gender,
      lastDonationDate: donor.lastDonationDate,
      today: DateTime.now(),
    );

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: kCrimson,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    donor.bloodGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(donor.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${donor.area}, ${donor.district}', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: milestone.badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: milestone.badgeColor.withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(milestone.badgeIcon, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 4),
                                Text(
                                  milestone.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: milestone.badgeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'মোট: ${toBanglaDigits(donor.totalDonations)} বার',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (result.eligible ? kEligibleGreen : kWaitSlate).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (result.eligible ? kEligibleGreen : kWaitSlate).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  result.eligible ? Icons.check_circle : Icons.hourglass_bottom,
                  color: result.eligible ? kEligibleGreen : kWaitSlate,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    result.eligible
                        ? (donor.lastDonationDate == null ? Strings.eligibleNoDate : Strings.eligible)
                        : Strings.eligibleIn(result.daysLeft, formatDateBn(result.nextEligibleDate!)),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: result.eligible ? kEligibleGreen : kWaitSlate,
                    ),
                  ),
                ),
              ],
            ),
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
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: dates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFFFEBEE),
                        child: Icon(Icons.bloodtype, size: 16, color: kCrimson),
                      ),
                      title: Text(
                        formatIsoDateBn(date),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(date, style: theme.textTheme.bodySmall),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                        tooltip: Strings.delete,
                        onPressed: () => _deleteDate(date),
                      ),
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
