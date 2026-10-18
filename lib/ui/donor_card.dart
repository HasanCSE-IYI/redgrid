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
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final ok = await launchUrl(Uri(scheme: 'tel', path: widget.donor.phone));
      if (!ok && mounted) messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    } catch (_) {
      if (mounted) messenger.showSnackBar(const SnackBar(content: Text(Strings.callFailed)));
    }
  }

  Future<void> _whatsapp() async {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();
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
    HapticFeedback.selectionClick();
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
        HapticFeedback.lightImpact();
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

  Widget _buildStatusPill(EligibilityResult result, bool isDark) {
    if (result.eligible) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B5E20).withValues(alpha: 0.35) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? const Color(0xFF2E7D32).withValues(alpha: 0.6) : const Color(0xFFA5D6A7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              widget.donor.lastDonationDate == null ? Strings.eligibleNoDate : Strings.readyToDonate,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_bottom_rounded,
              size: 13,
              color: isDark ? Colors.grey.shade400 : kWaitSlate,
            ),
            const SizedBox(width: 4),
            Text(
              Strings.eligibleIn(result.daysLeft, formatDateBn(result.nextEligibleDate!)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : kWaitSlate,
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final donor = widget.donor;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selectedBloodGroup = ref.watch(filterProvider.select((f) => f.bloodGroup));
    final isCompatibleMatch = selectedBloodGroup != null && selectedBloodGroup != donor.bloodGroup;
    final milestone = DonorMilestone.forCount(donor.totalDonations);

    final result = Eligibility.check(
      gender: donor.gender,
      lastDonationDate: donor.lastDonationDate,
      today: DateTime.now(),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isCompatibleMatch
              ? Colors.amber.shade400
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: isCompatibleMatch ? 1.4 : 1.0,
        ),
      ),
      child: InkWell(
        onTap: _showDetails,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row: Blood Group Badge + Name/Location + 3-Dot Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Blood Group Container
                  Container(
                    width: 52,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: kCrimson,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kCrimson.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          donor.bloodGroup,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isCompatibleMatch) ...[
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'ম্যাচ',
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
                  ),
                  const SizedBox(width: 12),

                  // Name, Milestone & Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                donor.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: milestone.title,
                              child: Text(
                                milestone.badgeIcon,
                                style: const TextStyle(fontSize: 14),
                                textScaler: TextScaler.noScaling,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
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
                        InkWell(
                          onTap: () => _onAction(_CardAction.copyPhone),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
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
                      ],
                    ),
                  ),

                  // 3-dot Menu
                  PopupMenuButton<_CardAction>(
                    tooltip: Strings.menu,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
              const SizedBox(height: 10),

              // 2. Status Pill + Lifetime Donations Pill
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildStatusPill(result, isDark),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      '🩸 ${toBanglaDigits(donor.totalDonations)} বার (${milestone.title})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),

              if (donor.notes != null && donor.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'নোট: ${donor.notes!.trim()}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 10),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 8),

              // 3. Ergonomic Thumb-Zone Action Row
              Row(
                children: [
                  // Secondary text action: SMS
                  IconButton(
                    tooltip: Strings.sms,
                    icon: const Icon(Icons.sms_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: _sms,
                  ),
                  // Secondary text action: Donated Today
                  IconButton(
                    tooltip: Strings.donatedToday,
                    icon: const Icon(Icons.bloodtype_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: _busy ? null : _donatedToday,
                  ),
                  const Spacer(),

                  // WhatsApp Action Button
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF25D366)),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _whatsapp,
                  ),
                  const SizedBox(width: 8),

                  // Large Primary Emergency Call Button
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                      elevation: 1,
                    ),
                    icon: const Icon(Icons.call_rounded, size: 16),
                    label: const Text(
                      Strings.callNow,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _call,
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
