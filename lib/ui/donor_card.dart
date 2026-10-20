import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../domain/eligibility.dart';
import '../domain/milestones.dart';
import '../providers.dart';
import 'blood_widgets.dart';
import 'donor_details_sheet.dart';
import 'donor_form_screen.dart';

enum _CardAction { details, copyPhone, sms, logDonation, edit, delete }

class DonorCard extends ConsumerStatefulWidget {
  const DonorCard({
    super.key,
    required this.donor,
    this.isCompact = false,
  });

  final Donor donor;
  final bool isCompact;

  @override
  ConsumerState<DonorCard> createState() => _DonorCardState();
}

class _DonorCardState extends ConsumerState<DonorCard> {
  Future<void> _call() => DonorContactActions.call(context, widget.donor.phone);

  Future<void> _whatsapp() => DonorContactActions.whatsapp(
        context,
        phone: widget.donor.phone,
        donorName: widget.donor.name,
        bloodGroup: widget.donor.bloodGroup,
      );

  Future<void> _sms() => DonorContactActions.sms(
        context,
        phone: widget.donor.phone,
        donorName: widget.donor.name,
        bloodGroup: widget.donor.bloodGroup,
      );

  void _showDetails() {
    DonorDetailsSheet.show(context, widget.donor);
  }

  Future<void> _donatedToday() async {
    await handleMarkDonation(context, ref, widget.donor);
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: Strings.deleteTitle,
      message: Strings.deleteBody,
      confirmLabel: Strings.delete,
      isDestructive: true,
    );
    if (!confirmed) return;
    try {
      await ref.read(donorListProvider.notifier).remove(widget.donor.id!);
      if (mounted) {
        AppNotificationToast.show(
          context,
          message: Strings.donorDeleted,
          icon: Icons.delete_outline_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        AppNotificationToast.show(
          context,
          message: Strings.genericError,
          icon: Icons.error_outline_rounded,
          color: kCrimson,
        );
      }
    }
  }

  List<PopupMenuEntry<_CardAction>> _buildMenuItems() => const [
    PopupMenuItem(value: _CardAction.details, child: Text(Strings.donorDetails)),
    PopupMenuItem(value: _CardAction.copyPhone, child: Text(Strings.copyPhone)),
    PopupMenuItem(value: _CardAction.sms, child: Text(Strings.sms)),
    PopupMenuItem(value: _CardAction.logDonation, child: Text(Strings.donatedToday)),
    PopupMenuItem(value: _CardAction.edit, child: Text(Strings.edit)),
    PopupMenuItem(value: _CardAction.delete, child: Text(Strings.delete)),
  ];

  void _onAction(_CardAction action) {
    switch (action) {
      case _CardAction.details:
        _showDetails();
      case _CardAction.copyPhone:
        DonorContactActions.copyPhone(context, widget.donor.phone);
      case _CardAction.sms:
        _sms();
      case _CardAction.logDonation:
        _donatedToday();
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
    final isDark = theme.brightness == Brightness.dark;
    final selectedBloodGroup = ref.watch(filterProvider.select((f) => f.bloodGroup));
    final isCompatibleMatch = selectedBloodGroup != null && selectedBloodGroup != donor.bloodGroup;
    final milestone = DonorMilestone.forCount(donor.totalDonations);
    final eligibility = Eligibility.check(
      gender: donor.gender,
      lastDonationDate: donor.lastDonationDate,
      today: DateTime.now(),
    );
    final isEligible = eligibility.eligible;

    if (widget.isCompact) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3.5),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: donorCardBorderSide(theme, isCompatibleMatch: isCompatibleMatch),
        ),
        child: InkWell(
          onTap: _showDetails,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                BloodGroupBadge(
                  bloodGroup: donor.bloodGroup,
                  size: 44,
                  fontSize: 16,
                  filled: true,
                  isCompatibleMatch: isCompatibleMatch,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              donor.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            milestone.badgeIcon,
                            style: const TextStyle(fontSize: 13),
                            textScaler: TextScaler.noScaling,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              '${donor.area}, ${donor.district}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isEligible ? kEligibleGreen : kWaitSlate,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEligible ? Strings.readyToDonate : Strings.waitingStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isEligible ? kEligibleGreen : kWaitSlate,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: Strings.whatsapp,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 19),
                  visualDensity: VisualDensity.compact,
                  onPressed: _whatsapp,
                ),
                IconButton.filled(
                  tooltip: Strings.callNow,
                  style: IconButton.styleFrom(
                    backgroundColor: isEligible ? kEligibleGreen : (isDark ? Colors.white12 : Colors.grey.shade200),
                    foregroundColor: isEligible ? Colors.white : (isDark ? Colors.white70 : kWaitSlate),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(isEligible ? Icons.call_rounded : Icons.call_outlined, size: 18),
                  onPressed: _call,
                ),
                PopupMenuButton<_CardAction>(
                  tooltip: Strings.menu,
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: _onAction,
                  itemBuilder: (_) => _buildMenuItems(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: donorCardBorderSide(theme, isCompatibleMatch: isCompatibleMatch),
      ),
      child: InkWell(
        onTap: _showDetails,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Row: Blood Group Badge + Name/Location + 3-Dot Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BloodGroupBadge(
                    bloodGroup: donor.bloodGroup,
                    size: 52,
                    fontSize: 18,
                    filled: true,
                    isCompatibleMatch: isCompatibleMatch,
                  ),
                  const SizedBox(width: 12),

                  // Name & Location
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          donor.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
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
                    itemBuilder: (_) => _buildMenuItems(),
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
                  EligibilityPill(gender: donor.gender, lastDonationDate: donor.lastDonationDate),
                  if (donor.totalDonations > 0)
                    MilestoneBadge(totalDonations: donor.totalDonations),
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

              // 3. Clean Thumb-Zone Action Row (WhatsApp + Call)
              Row(
                children: [
                  const Spacer(),

                  // WhatsApp
                  IconButton.filledTonal(
                    tooltip: Strings.whatsapp,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: isDark ? 0.2 : 0.12),
                      foregroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.chat_bubble_rounded, size: 17),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _whatsapp();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Call Button
                  isEligible
                      ? FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: kEligibleGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            visualDensity: VisualDensity.compact,
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.call_rounded, size: 16),
                          label: const Text(
                            Strings.callNow,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _call();
                          },
                        )
                      : OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white70 : kWaitSlate,
                            side: BorderSide(
                              color: isDark ? Colors.white24 : Colors.grey.shade400,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            visualDensity: VisualDensity.compact,
                          ),
                          icon: const Icon(Icons.call_outlined, size: 15),
                          label: const Text(
                            Strings.call,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _call();
                          },
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
