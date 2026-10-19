import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app.dart';
import '../core/date_format.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../domain/app_notification.dart';
import '../providers.dart';
import '../services/contact_service.dart';
import 'donor_details_sheet.dart';

/// বিজ্ঞপ্তিসমূহ ও সিস্টেম অ্যালার্ট দেখার মডাল বটম শিট
class NotificationCenterSheet extends ConsumerStatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationCenterSheet(),
    );
  }

  @override
  ConsumerState<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends ConsumerState<NotificationCenterSheet> {
  int _selectedFilterIndex = 0; // 0: সব, 1: প্রস্তুত ডোনার, 2: সিঙ্ক ও সিস্টেম

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationAsync = ref.watch(notificationProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ড্র্যাগ হ্যান্ডেল
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // হেডার বার
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: kCrimson.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: kCrimson, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  Strings.notifications,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                notificationAsync.when(
                  data: (state) => state.unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: kCrimson,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            toBanglaDigits(state.unreadCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const Spacer(),
                notificationAsync.when(
                  data: (state) => Row(
                    children: [
                      if (state.unreadCount > 0)
                        TextButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ref.read(notificationProvider.notifier).markAllAsRead();
                          },
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text(Strings.markAllAsRead, style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      if (state.visibleNotifications.isNotEmpty)
                        IconButton(
                          tooltip: Strings.clearAll,
                          icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            ref.read(notificationProvider.notifier).clearAll();
                          },
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ফিল্টার ট্যাব চিপস
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip(0, Strings.filterAll),
                const SizedBox(width: 8),
                _buildFilterChip(1, Strings.filterReady),
                const SizedBox(width: 8),
                _buildFilterChip(2, Strings.filterSync),
              ],
            ),
          ),
          const Divider(height: 12),

          // বিজ্ঞপ্তির তালিকা
          Expanded(
            child: notificationAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text(err.toString())),
              data: (state) {
                final visible = state.visibleNotifications.where((n) {
                  if (_selectedFilterIndex == 1) {
                    return n.type == NotificationType.donorReady;
                  } else if (_selectedFilterIndex == 2) {
                    return n.type == NotificationType.syncSuccess ||
                        n.type == NotificationType.syncAlert ||
                        n.type == NotificationType.system;
                  }
                  return true;
                }).toList();

                if (visible.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 56,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            Strings.noNotifications,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Strings.noNotificationsDesc,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  itemCount: visible.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final isRead = state.readIds.contains(item.id);

                    return Dismissible(
                      key: ValueKey(item.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(Icons.delete_outline, color: Colors.red.shade800),
                      ),
                      onDismissed: (_) {
                        HapticFeedback.lightImpact();
                        ref.read(notificationProvider.notifier).dismiss(item.id);
                      },
                      child: _NotificationCard(
                        notification: item,
                        isRead: isRead,
                        onTap: () {
                          if (!isRead) {
                            ref.read(notificationProvider.notifier).markAsRead(item.id);
                          }
                        },
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

  Widget _buildFilterChip(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// একক নোটিফিকেশন কার্ড
class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({
    required this.notification,
    required this.isRead,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // আইকন ও রঙ নির্ধারণ
    final (IconData icon, Color color, Color bgColor) = switch (notification.type) {
      NotificationType.donorReady => (
          Icons.favorite_rounded,
          kEligibleGreen,
          kEligibleGreen.withValues(alpha: 0.12),
        ),
      NotificationType.syncSuccess => (
          Icons.cloud_done_rounded,
          Colors.blue.shade700,
          Colors.blue.shade50,
        ),
      NotificationType.syncAlert => (
          Icons.cloud_off_rounded,
          Colors.orange.shade800,
          Colors.orange.shade50,
        ),
      NotificationType.emergencyNotice => (
          Icons.emergency_share_rounded,
          kCrimson,
          kCrimson.withValues(alpha: 0.12),
        ),
      NotificationType.system => (
          Icons.info_outline_rounded,
          theme.colorScheme.primary,
          theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
    };

    return Material(
      color: isRead
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isRead
                  ? theme.colorScheme.outlineVariant.withValues(alpha: 0.3)
                  : color.withValues(alpha: 0.4),
              width: isRead ? 0.8 : 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isRead ? FontWeight.w600 : FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: const BoxDecoration(
                                  color: kCrimson,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.message,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRelativeTimeBn(notification.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // যদি প্রস্তুত ডোনার অ্যালার্ট হয়, তাহলে ডাইরেক্ট কল ও WhatsApp অ্যাকশন বাটন
              if (notification.type == NotificationType.donorReady &&
                  notification.donorPhone != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (notification.donorId != null)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final repo = ref.read(donorRepositoryProvider);
                          final donor = await repo.getById(notification.donorId!);
                          if (donor != null && context.mounted) {
                            DonorDetailsSheet.show(context, donor);
                          }
                        },
                        icon: const Icon(Icons.person_outline_rounded, size: 15),
                        label: const Text(Strings.profileAction, style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final msg = ContactService.composeDonorMessage(
                          donorName: notification.donorName ?? '',
                          bloodGroup: notification.bloodGroup ?? '',
                        );
                        ContactService.openWhatsApp(
                          phone: notification.donorPhone!,
                          message: msg,
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                      label: const Text(Strings.whatsappAction, style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        final uri = Uri(scheme: 'tel', path: notification.donorPhone!);
                        launchUrl(uri);
                      },
                      icon: const Icon(Icons.call_rounded, size: 15),
                      label: const Text(Strings.callAction, style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: kEligibleGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// হোমস্ক্রিনে প্রদর্শনের জন্য স্মার্ট নোটিফিকেশন ব্যানার
class HomeNotificationBanner extends ConsumerWidget {
  const HomeNotificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationAsync = ref.watch(notificationProvider);
    final theme = Theme.of(context);

    return notificationAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (state) {
        final bannerItem = state.activeBannerNotification;
        if (bannerItem == null) return const SizedBox.shrink();

        final (IconData icon, Color color, Color bg) = switch (bannerItem.type) {
          NotificationType.donorReady => (
              Icons.favorite_rounded,
              kEligibleGreen,
              kEligibleGreen.withValues(alpha: 0.1),
            ),
          NotificationType.syncSuccess => (
              Icons.cloud_done_rounded,
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            ),
          NotificationType.syncAlert => (
              Icons.cloud_off_rounded,
              Colors.orange.shade800,
              Colors.orange.shade50,
            ),
          NotificationType.emergencyNotice => (
              Icons.emergency_rounded,
              kCrimson,
              kCrimson.withValues(alpha: 0.1),
            ),
          NotificationType.system => (
              Icons.info_outline_rounded,
              theme.colorScheme.primary,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            ),
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                NotificationCenterSheet.show(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bannerItem.title,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            bannerItem.message,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        NotificationCenterSheet.show(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        Strings.viewDetails,
                        style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      tooltip: Strings.cancel,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(notificationProvider.notifier).dismissBanner(bannerItem.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// আধুনিক ফ্লোটিং নোটিফিকেশন বার (Toast helper)
class AppNotificationToast {
  AppNotificationToast._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline_rounded,
    Color? color,
    Duration duration = const Duration(seconds: 3),
  }) {
    HapticFeedback.lightImpact();
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        elevation: 4,
        content: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        duration: duration,
      ),
    );
  }
}
