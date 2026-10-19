import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'core/constants.dart';
import 'core/digits.dart';
import 'data/donor.dart';
import 'data/donor_repository.dart';
import 'domain/app_notification.dart';
import 'services/backup_service.dart';
import 'services/sync_service.dart';

/// main() এ খোলা ডেটাবেস দিয়ে override করা হয়।
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final donorRepositoryProvider =
    Provider<DonorRepository>((ref) => DonorRepository(ref.watch(databaseProvider)));

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(databaseProvider)));

class FilterNotifier extends Notifier<DonorFilter> {
  @override
  DonorFilter build() => const DonorFilter();

  void setBloodGroup(String? value) => state = state.copyWith(
        bloodGroup: value,
        includeCompatible: value == null ? false : state.includeCompatible,
      );
  void setIncludeCompatible(bool value) => state = state.copyWith(includeCompatible: value);
  void setDistrict(String? value) => state = state.copyWith(district: value, area: null);
  void setArea(String? value) => state = state.copyWith(area: value);
  void setQuery(String value) => state = state.copyWith(query: value);
  void setEligibleOnly(bool value) => state = state.copyWith(eligibleOnly: value);
  void setSortBy(DonorSort sort) => state = state.copyWith(sortBy: sort);
  void reset() => state = const DonorFilter();
}

final filterProvider = NotifierProvider<FilterNotifier, DonorFilter>(FilterNotifier.new);

class DonorListNotifier extends AsyncNotifier<List<Donor>> {
  DonorRepository get _repo => ref.read(donorRepositoryProvider);

  @override
  Future<List<Donor>> build() {
    final filter = ref.watch(filterProvider);
    return ref.watch(donorRepositoryProvider).search(filter);
  }

  void _notifyMutation([int? donorId]) {
    ref.invalidateSelf();
    ref.invalidate(donorStatsProvider);
    if (donorId != null) {
      ref.invalidate(donationDatesProvider(donorId));
    }
    ref.read(syncStatusProvider.notifier).triggerAutoSync();
  }

  Future<void> add(Donor donor) async {
    await _repo.insert(donor);
    _notifyMutation();
  }

  Future<void> edit(Donor donor) async {
    await _repo.update(donor);
    _notifyMutation();
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    _notifyMutation(id);
  }

  Future<MarkDonatedResult> markDonated(int donorId, String date) async {
    final result = await _repo.markDonated(donorId, date);
    _notifyMutation(donorId);
    return result;
  }

  Future<void> undo(int donorId, String date, String? previousLastDate) async {
    await _repo.undoDonation(donorId, date, previousLastDate);
    _notifyMutation(donorId);
  }

  Future<void> deleteDonationDate(int donorId, String date) async {
    await _repo.deleteDonationDate(donorId, date);
    _notifyMutation(donorId);
  }
}

final donorListProvider =
    AsyncNotifierProvider<DonorListNotifier, List<Donor>>(DonorListNotifier.new);

final donorStatsProvider = FutureProvider.autoDispose<DonorStats>((ref) async {
  return ref.watch(donorRepositoryProvider).getStats();
});

final donationDatesProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, donorId) async {
  return ref.watch(donorRepositoryProvider).getDonationDates(donorId);
});

// ==========================================
// Cloud Sync
// ==========================================

final syncServiceProvider =
    Provider<SyncService>((ref) => SyncService(ref.watch(donorRepositoryProvider)));

class SyncStatusNotifier extends Notifier<SyncResult> {
  Timer? _autoSyncDebounce;

  @override
  SyncResult build() => const SyncResult.idle();

  /// পরিবর্তন সংঘটিত হওয়ার পর নিরবচ্ছিন্ন ব্যাকগ্রাউন্ড সিঙ্ক চালু করে
  void triggerAutoSync() {
    _autoSyncDebounce?.cancel();
    _autoSyncDebounce = Timer(const Duration(milliseconds: 1500), () {
      sync(silent: true);
    });
  }

  Future<SyncResult> sync({bool silent = false}) async {
    if (!silent) {
      state = const SyncResult(status: SyncStatus.syncing);
    }
    final result = await ref.read(syncServiceProvider).sync();
    state = result;
    if (result.isSuccess) {
      ref.invalidate(donorListProvider);
      ref.invalidate(donorStatsProvider);
      if (result.donorCount > 0 || result.logCount > 0) {
        ref.read(notificationProvider.notifier).addNotification(
          AppNotification(
            id: 'sync_${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.syncSuccess,
            title: 'ক্লাউড সিঙ্ক সম্পন্ন',
            message:
                '${toBanglaDigits(result.donorCount)} জন নতুন ডোনার ও ${toBanglaDigits(result.logCount)} টি রেকর্ড আপডেট হয়েছে।',
            timestamp: DateTime.now(),
          ),
        );
      }
    } else if (!silent && result.status == SyncStatus.failed) {
      ref.read(notificationProvider.notifier).addNotification(
        AppNotification(
          id: 'sync_err_${DateTime.now().millisecondsSinceEpoch}',
          type: NotificationType.syncAlert,
          title: 'সিঙ্ক সতর্কতা',
          message: result.errorMessage ?? 'ইন্টারনেট সমস্যা',
          timestamp: DateTime.now(),
        ),
      );
    }
    return result;
  }

  void reset() => state = const SyncResult.idle();
}

final syncStatusProvider =
    NotifierProvider<SyncStatusNotifier, SyncResult>(SyncStatusNotifier.new);

// ==========================================
// Notifications & Alerts
// ==========================================

class NotificationState {
  const NotificationState({
    this.notifications = const [],
    this.readIds = const {},
    this.dismissedIds = const {},
    this.lastDismissedBannerId,
  });

  final List<AppNotification> notifications;
  final Set<String> readIds;
  final Set<String> dismissedIds;
  final String? lastDismissedBannerId;

  List<AppNotification> get visibleNotifications =>
      notifications.where((n) => !dismissedIds.contains(n.id)).toList();

  int get unreadCount =>
      visibleNotifications.where((n) => !readIds.contains(n.id)).length;

  AppNotification? get activeBannerNotification {
    final unread = visibleNotifications.where((n) => !readIds.contains(n.id)).toList();
    if (unread.isEmpty) return null;
    final first = unread.first;
    if (first.id == lastDismissedBannerId) return null;
    return first;
  }
}

class NotificationNotifier extends AsyncNotifier<NotificationState> {
  final List<AppNotification> _dynamicNotifications = [];
  Set<String> _readIds = {};
  Set<String> _dismissedIds = {};
  String? _lastDismissedBannerId;

  @override
  Future<NotificationState> build() async {
    final repo = ref.watch(donorRepositoryProvider);
    // ডোনার তালিকায় পরিবর্তন হলে নোটিফিকেশন স্বয়ংক্রিয়ভাবে হালনাগাদ হবে
    ref.watch(donorListProvider);

    // পঠিত এবং বাতিলকৃত আইডি লোড
    final readRaw = await repo.getSetting(AppConstants.settingReadNotifications);
    if (readRaw != null && readRaw.isNotEmpty) {
      try {
        _readIds = (jsonDecode(readRaw) as List<dynamic>).map((e) => e.toString()).toSet();
      } catch (_) {}
    }

    final dismissedRaw = await repo.getSetting(AppConstants.settingDismissedNotifications);
    if (dismissedRaw != null && dismissedRaw.isNotEmpty) {
      try {
        _dismissedIds = (jsonDecode(dismissedRaw) as List<dynamic>).map((e) => e.toString()).toSet();
      } catch (_) {}
    }

    _lastDismissedBannerId = await repo.getSetting(AppConstants.settingBannerDismissed);

    // রক্তদানের কুলডাউন সম্পন্ন হওয়া ডোনারদের অ্যালার্ট সংগ্রহ
    final allDonors = await repo.search(const DonorFilter());
    final eligibilityAlerts = <AppNotification>[];
    for (final d in allDonors) {
      final alert = AppNotification.fromDonorEligibility(d);
      if (alert != null) {
        eligibilityAlerts.add(alert);
      }
    }

    final all = <AppNotification>[
      ..._dynamicNotifications,
      ...eligibilityAlerts,
    ];

    all.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return NotificationState(
      notifications: all,
      readIds: _readIds,
      dismissedIds: _dismissedIds,
      lastDismissedBannerId: _lastDismissedBannerId,
    );
  }

  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    final repo = ref.read(donorRepositoryProvider);
    await repo.setSetting(AppConstants.settingReadNotifications, jsonEncode(_readIds.toList()));
    ref.invalidateSelf();
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    for (final n in current.visibleNotifications) {
      _readIds.add(n.id);
    }
    final repo = ref.read(donorRepositoryProvider);
    await repo.setSetting(AppConstants.settingReadNotifications, jsonEncode(_readIds.toList()));
    ref.invalidateSelf();
  }

  Future<void> dismiss(String id) async {
    _dismissedIds.add(id);
    final repo = ref.read(donorRepositoryProvider);
    await repo.setSetting(AppConstants.settingDismissedNotifications, jsonEncode(_dismissedIds.toList()));
    ref.invalidateSelf();
  }

  Future<void> dismissBanner(String id) async {
    _lastDismissedBannerId = id;
    final repo = ref.read(donorRepositoryProvider);
    await repo.setSetting(AppConstants.settingBannerDismissed, id);
    ref.invalidateSelf();
  }

  Future<void> clearAll() async {
    final current = state.valueOrNull;
    if (current == null) return;
    for (final n in current.visibleNotifications) {
      _dismissedIds.add(n.id);
    }
    final repo = ref.read(donorRepositoryProvider);
    await repo.setSetting(AppConstants.settingDismissedNotifications, jsonEncode(_dismissedIds.toList()));
    ref.invalidateSelf();
  }

  void addNotification(AppNotification n) {
    _dynamicNotifications.removeWhere((item) => item.id == n.id);
    _dynamicNotifications.insert(0, n);
    ref.invalidateSelf();
  }
}

final notificationProvider =
    AsyncNotifierProvider<NotificationNotifier, NotificationState>(NotificationNotifier.new);
