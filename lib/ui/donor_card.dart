import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'donor_details_sheet.dart';
import 'donor_form_screen.dart';

enum _CardAction { details, copyPhone, edit, delete }

class DonorCard extends ConsumerStatefulWidget {
  const DonorCard({super.key, required this.donor});

  final Donor donor;

  @override
  ConsumerState<DonorCard> createState() => _DonorCardState();
}

class _DonorCardState extends ConsumerState<DonorCard> {
  bool _busy = false;

  Future<void> _call() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: widget.donor.phone));
      if (!ok && mounted) messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    } catch (_) {
      if (mounted) messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    }
  }

  Future<void> _whatsapp() async {
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

  Future<void> _sms() async {
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

  void _showDetails() {
    DonorDetailsSheet.show(context, widget.donor);
  }

  Future<void> _donatedToday() async {
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
    final previousLast = donor.lastDonationDate;
    final date = isoDate(picked);

    setState(() => _busy = true);
    try {
      final result = await notifier.markDonated(donor.id!, date);
      messenger.hideCurrentSnackBar();
      if (result == MarkDonatedResult.alreadyLogged) {
        messenger.showSnackBar(const SnackBar(content: Text(Strings.alreadyLogged)));
      } else {
        messenger.showSnackBar(SnackBar(
          content: const Text(Strings.donationSaved),
          action: SnackBarAction(
            label: Strings.undo,
            onPressed: () => notifier.undo(donor.id!, date, previousLast),
          ),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(donorListProvider.notifier);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.deleteTitle),
        content: const Text(Strings.deleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Strings.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text(Strings.delete)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await notifier.remove(widget.donor.id!);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
    }
  }

  void _onAction(_CardAction action) {
    switch (action) {
      case _CardAction.details:
        _showDetails();
      case _CardAction.copyPhone:
        Clipboard.setData(ClipboardData(text: widget.donor.phone));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(Strings.phoneCopied), duration: Duration(seconds: 2)),
        );
      case _CardAction.edit:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DonorFormScreen(donor: widget.donor)),
        );
      case _CardAction.delete:
        _delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final donor = widget.donor;
    final theme = Theme.of(context);
    final filter = ref.watch(filterProvider);
    final isCompatibleMatch = filter.bloodGroup != null && filter.bloodGroup != donor.bloodGroup;
    final milestone = DonorMilestone.forCount(donor.totalDonations);

    final result = Eligibility.check(
      gender: donor.gender,
      lastDonationDate: donor.lastDonationDate,
      today: DateTime.now(),
    );

    final String statusText;
    final IconData statusIcon;
    final Color statusColor;
    if (result.eligible) {
      statusText = donor.lastDonationDate == null ? Strings.eligibleNoDate : Strings.eligible;
      statusIcon = Icons.check_circle;
      statusColor = kEligibleGreen;
    } else {
      statusText = Strings.eligibleIn(result.daysLeft, formatDateBn(result.nextEligibleDate!));
      statusIcon = Icons.hourglass_bottom;
      statusColor = kWaitSlate;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: _showDetails,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: kCrimson,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          donor.bloodGroup,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isCompatibleMatch) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            Strings.compatibleBadge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                donor.name,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              milestone.badgeIcon,
                              style: const TextStyle(fontSize: 14),
                              textScaler: TextScaler.noScaling,
                            ),
                          ],
                        ),
                        Text('${donor.area}, ${donor.district}', style: theme.textTheme.bodyMedium),
                        Text(
                          donor.phone,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: Strings.call,
                        icon: const Icon(Icons.call, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: _call,
                      ),
                      IconButton(
                        tooltip: Strings.whatsapp,
                        icon: const Icon(Icons.chat_bubble_outline, size: 20, color: Color(0xFF25D366)),
                        visualDensity: VisualDensity.compact,
                        onPressed: _whatsapp,
                      ),
                      IconButton(
                        tooltip: Strings.sms,
                        icon: const Icon(Icons.sms_outlined, size: 20),
                        visualDensity: VisualDensity.compact,
                        onPressed: _sms,
                      ),
                      PopupMenuButton<_CardAction>(
                        tooltip: Strings.menu,
                        onSelected: _onAction,
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: _CardAction.details, child: Text(Strings.donorDetails)),
                          PopupMenuItem(value: _CardAction.copyPhone, child: Text(Strings.copyPhone)),
                          PopupMenuItem(value: _CardAction.edit, child: Text(Strings.edit)),
                          PopupMenuItem(value: _CardAction.delete, child: Text(Strings.delete)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(statusIcon, size: 18, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    Strings.donationCount(toBanglaDigits(donor.totalDonations)),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '• ${milestone.title}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: milestone.badgeColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (donor.notes != null && donor.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'নোট: ${donor.notes!.trim()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _showDetails,
                    icon: const Icon(Icons.history, size: 16),
                    label: const Text(Strings.donorDetails),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _donatedToday,
                    icon: const Icon(Icons.bloodtype, size: 16),
                    label: const Text(Strings.donatedToday),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
