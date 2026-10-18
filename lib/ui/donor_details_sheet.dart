import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../data/donor_repository.dart';
import '../domain/milestones.dart';
import '../providers.dart';
import '../services/contact_service.dart';
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

  Future<void> _call() async {
    final ok = await ContactService.makeCall(widget.donor.phone);
    if (!ok && mounted) {
      AppNotificationToast.show(context, message: Strings.callFailed, color: kCrimson);
    }
  }

  Future<void> _sendWhatsApp() async {
    final donor = widget.donor;
    final ok = await ContactService.contactDonorWhatsApp(
      donorName: donor.name,
      bloodGroup: donor.bloodGroup,
      phone: donor.phone,
    );
    if (!ok && mounted) {
      AppNotificationToast.show(context, message: Strings.whatsappFailed, color: kCrimson);
    }
  }

  Future<void> _sendSms() async {
    final donor = widget.donor;
    final message = ContactService.composeDonorMessage(
      donorName: donor.name,
      bloodGroup: donor.bloodGroup,
    );
    final ok = await ContactService.openSms(phone: donor.phone, message: message);
    if (!ok && mounted) {
      AppNotificationToast.show(context, message: Strings.smsFailed, color: kCrimson);
    }
  }

  Future<void> _addDonationDate() async {
    final donor = widget.donor;
    final picked = await pickDonationDate(context, firstDate: DateTime(1970));
    if (picked == null || !mounted) return;

    final notifier = ref.read(donorListProvider.notifier);
    final date = isoDate(picked);

    setState(() => _busy = true);
    try {
      final result = await notifier.markDonated(donor.id!, date);
      if (!mounted) return;
      if (result == MarkDonatedResult.alreadyLogged) {
        AppNotificationToast.show(context, message: Strings.alreadyLogged);
      } else {
        AppNotificationToast.show(context, message: Strings.donationSaved);
      }
    } catch (_) {
      if (mounted) {
        AppNotificationToast.show(context, message: Strings.genericError, color: kCrimson);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

    final milestone = DonorMilestone.forCount(donor.totalDonations);
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
                  size: 52,
                  fontSize: 20,
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
