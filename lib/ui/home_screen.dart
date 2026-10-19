import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/areas.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor_repository.dart' show DonorFilter, DonorSort;
import '../domain/compatibility.dart';
import '../providers.dart';
import '../services/sync_service.dart';
import 'about_dialog.dart';
import 'data_tools.dart';
import 'donor_card.dart';
import 'donor_form_screen.dart';
import 'emergency_request_dialog.dart';
import 'guidelines_sheet.dart';
import 'notification_center_sheet.dart';
import 'sync_settings_dialog.dart';

enum _MenuAction { backup, restore, syncSettings, guidelines, about }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounce;
  late final TextEditingController _searchController;
  bool _isCompactView = false;

  void _openAddDonor() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DonorFormScreen()),
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doSilentStartupSync();
    });
  }

  Future<void> _doSilentStartupSync() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    ref.read(syncStatusProvider.notifier).sync(silent: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(filterProvider.notifier).setQuery(value);
    });
  }

  Future<void> _doSync() async {
    final result = await ref.read(syncStatusProvider.notifier).sync();
    if (!mounted) return;
    final msg = switch (result.status) {
      SyncStatus.success =>
        Strings.cloudSyncSuccess(result.donorCount, result.logCount),
      SyncStatus.noUrl => Strings.cloudSyncNoUrl,
      SyncStatus.failed => Strings.cloudSyncError(result.errorMessage ?? ''),
      _ => null,
    };
    if (msg != null) {
      AppNotificationToast.show(
        context,
        message: msg,
        icon: result.isSuccess ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
        color: result.isSuccess ? kEligibleGreen : kCrimson,
      );
    }
  }

  void _onMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.backup:
        shareBackup(context, ref);
      case _MenuAction.restore:
        restoreBackup(context, ref);
      case _MenuAction.syncSettings:
        _showSyncDialog(context);
      case _MenuAction.guidelines:
        GuidelinesSheet.show(context);
      case _MenuAction.about:
        AboutAppDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final donors = ref.watch(donorListProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final areaOptions = filter.district == null
        ? const <String>[]
        : (kAreasByDistrict[filter.district] ?? const <String>[]);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 26,
                height: 26,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              Strings.appTitle,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFFFF5252)
                    : kCrimson,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: Strings.addDonor,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: _openAddDonor,
          ),
          // জরুরি রক্তের আবেদন বোতাম
          IconButton(
            tooltip: Strings.emergencyBannerTitle,
            icon: const Icon(Icons.emergency_rounded, color: kCrimson),
            onPressed: () {
              HapticFeedback.lightImpact();
              EmergencyRequestDialog.show(
                context,
                bloodGroup: filter.bloodGroup,
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(notificationProvider).maybeWhen(
                    data: (state) => state.unreadCount,
                    orElse: () => 0,
                  );
              return IconButton(
                tooltip: Strings.notifications,
                icon: unreadCount > 0
                    ? Badge.count(
                        count: unreadCount,
                        backgroundColor: kCrimson,
                        textColor: Colors.white,
                        child: const Icon(Icons.notifications_active_rounded),
                      )
                    : const Icon(Icons.notifications_outlined),
                onPressed: () => NotificationCenterSheet.show(context),
              );
            },
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: Strings.menu,
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MenuAction.syncSettings, child: Text(Strings.cloudSyncTitle)),
              PopupMenuItem(value: _MenuAction.guidelines, child: Text(Strings.donationGuidelines)),
              PopupMenuItem(value: _MenuAction.backup, child: Text(Strings.backup)),
              PopupMenuItem(value: _MenuAction.restore, child: Text(Strings.restore)),
              PopupMenuItem(value: _MenuAction.about, child: Text(Strings.about)),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
            onRefresh: _doSync,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // স্মার্ট নোটিফিকেশন ব্যানার
                        const HomeNotificationBanner(),

                        // ড্যাশবোর্ড হিরো স্ট্যাটাস বার (Apple Health / KPI স্টাইল)
                        _DashboardMetricsBar(
                          isEligibleFilterActive: filter.eligibleOnly,
                          onToggleEligible: () {
                            HapticFeedback.selectionClick();
                            notifier.setEligibleOnly(!filter.eligibleOnly);
                          },
                        ),

                        // সার্চ বক্স
                        TextField(
                          controller: _searchController,
                          onChanged: _onQueryChanged,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: Strings.searchHint,
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    tooltip: Strings.clear,
                                    icon: const Icon(Icons.clear_rounded, size: 20),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _searchController.clear();
                                      ref.read(filterProvider.notifier).setQuery('');
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // রক্তের গ্রুপ নির্বাচক
                        _BloodGroupSelector(
                          selectedGroup: filter.bloodGroup,
                          onGroupSelected: (group) {
                            HapticFeedback.selectionClick();
                            notifier.setBloodGroup(group);
                          },
                        ),
                        const SizedBox(height: 10),

                        // জেলা ও এলাকা ড্রপডাউন
                        Row(
                          children: [
                            Expanded(
                              child: _FilterDropdown(
                                hint: Strings.allDistricts,
                                value: filter.district,
                                options: kAreasByDistrict.keys.toList(),
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  notifier.setDistrict(val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FilterDropdown(
                                hint: Strings.allAreas,
                                value: filter.area,
                                options: areaOptions,
                                onChanged: filter.district == null
                                    ? null
                                    : (val) {
                                        HapticFeedback.selectionClick();
                                        notifier.setArea(val);
                                      },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // দ্রুত ফিল্টার পিলস (প্রস্তুত ডোনার ও সামঞ্জস্যপূর্ণ ম্যাচ)
                        Row(
                          children: [
                            Expanded(
                              child: _FilterTogglePill(
                                icon: filter.eligibleOnly
                                    ? Icons.check_circle_rounded
                                    : Icons.access_time_rounded,
                                label: Strings.eligibleOnly,
                                isActive: filter.eligibleOnly,
                                activeColor: kEligibleGreen,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  notifier.setEligibleOnly(!filter.eligibleOnly);
                                },
                              ),
                            ),
                            if (filter.bloodGroup != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _FilterTogglePill(
                                  icon: filter.includeCompatible
                                      ? Icons.check_circle_rounded
                                      : Icons.swap_horiz_rounded,
                                  label: 'সামঞ্জস্যপূর্ণ সহ (${BloodCompatibility.compatibleDonorsFor(filter.bloodGroup!).length})',
                                  isActive: filter.includeCompatible,
                                  activeColor: kCrimson,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    notifier.setIncludeCompatible(!filter.includeCompatible);
                                  },
                                ),
                              ),
                            ],
                          ],
                        ),

                        // সক্রিয় ফিল্টার ট্যাগসমূহ (এক নজরে দেখা ও দ্রুত মুছে ফেলা)
                        if (filter.bloodGroup != null ||
                            filter.district != null ||
                            filter.area != null ||
                            filter.eligibleOnly ||
                            filter.query.isNotEmpty ||
                            filter.sortBy != DonorSort.nameAsc) ...[
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                if (filter.bloodGroup != null)
                                  _ActiveFilterTag(
                                    label: 'গ্রুপ: ${filter.bloodGroup}',
                                    onRemove: () => notifier.setBloodGroup(null),
                                  ),
                                if (filter.district != null)
                                  _ActiveFilterTag(
                                    label: 'জেলা: ${filter.district}',
                                    onRemove: () => notifier.setDistrict(null),
                                  ),
                                if (filter.area != null)
                                  _ActiveFilterTag(
                                    label: 'এলাকা: ${filter.area}',
                                    onRemove: () => notifier.setArea(null),
                                  ),
                                if (filter.eligibleOnly)
                                  _ActiveFilterTag(
                                    label: 'শুধুমাত্র প্রস্তুত',
                                    onRemove: () => notifier.setEligibleOnly(false),
                                  ),
                                if (filter.sortBy != DonorSort.nameAsc)
                                  _ActiveFilterTag(
                                    label: switch (filter.sortBy) {
                                      DonorSort.readyFirst => Strings.sortReadyFirst,
                                      DonorSort.mostDonations => Strings.sortMostDonations,
                                      _ => '',
                                    },
                                    onRemove: () => notifier.setSortBy(DonorSort.nameAsc),
                                  ),
                                if (filter.query.isNotEmpty)
                                  _ActiveFilterTag(
                                    label: '"${filter.query}"',
                                    onRemove: () {
                                      _searchController.clear();
                                      notifier.setQuery('');
                                    },
                                  ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _searchController.clear();
                                    notifier.reset();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text(
                                      Strings.clearFilter,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: kCrimson,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                  ],
                ),
              ),
            ),
            ...donors.when<List<Widget>>(
              skipLoadingOnReload: true,
              loading: () => [
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (error, _) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _MessageState(
                    icon: Icons.error_outline,
                    title: Strings.errorLoad,
                    actionLabel: Strings.retry,
                    onAction: () => ref.invalidate(donorListProvider),
                  ),
                ),
              ],
              data: (list) => list.isEmpty
                  ? [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _SmartEmptyState(
                          filter: filter,
                          onAddDonor: _openAddDonor,
                          onFindCompatible: () {
                            notifier.setIncludeCompatible(true);
                          },
                          onResetEligible: () {
                            notifier.setEligibleOnly(false);
                          },
                          onResetFilters: () {
                            _searchController.clear();
                            notifier.reset();
                          },
                          onCreateEmergency: () {
                            EmergencyRequestDialog.show(
                              context,
                              bloodGroup: filter.bloodGroup,
                            );
                          },
                        ),
                      ),
                    ]
                  : [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: Row(
                            children: [
                              Text(
                                '${toBanglaDigits(list.length)} জন ডোনার পাওয়া গেছে',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (filter.bloodGroup != null ||
                                  filter.district != null ||
                                  filter.area != null ||
                                  filter.eligibleOnly ||
                                  filter.query.isNotEmpty ||
                                  filter.sortBy != DonorSort.nameAsc) ...[
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _searchController.clear();
                                    notifier.reset();
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'ফিল্টার মুছুন',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kCrimson,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              // সর্টিং নির্বাচক
                              PopupMenuButton<DonorSort>(
                                tooltip: Strings.sortBy,
                                onSelected: (sort) {
                                  HapticFeedback.selectionClick();
                                  notifier.setSortBy(sort);
                                },
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: DonorSort.nameAsc,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.sort_by_alpha_rounded,
                                          size: 18,
                                          color: filter.sortBy == DonorSort.nameAsc ? kCrimson : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Strings.sortName,
                                          style: TextStyle(
                                            fontWeight: filter.sortBy == DonorSort.nameAsc ? FontWeight.bold : FontWeight.normal,
                                            color: filter.sortBy == DonorSort.nameAsc ? kCrimson : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: DonorSort.readyFirst,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 18,
                                          color: filter.sortBy == DonorSort.readyFirst ? kEligibleGreen : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Strings.sortReadyFirst,
                                          style: TextStyle(
                                            fontWeight: filter.sortBy == DonorSort.readyFirst ? FontWeight.bold : FontWeight.normal,
                                            color: filter.sortBy == DonorSort.readyFirst ? kEligibleGreen : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: DonorSort.mostDonations,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.military_tech_rounded,
                                          size: 18,
                                          color: filter.sortBy == DonorSort.mostDonations ? Colors.amber.shade800 : null,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Strings.sortMostDonations,
                                          style: TextStyle(
                                            fontWeight: filter.sortBy == DonorSort.mostDonations ? FontWeight.bold : FontWeight.normal,
                                            color: filter.sortBy == DonorSort.mostDonations ? Colors.amber.shade800 : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: filter.sortBy != DonorSort.nameAsc
                                        ? kCrimson.withValues(alpha: isDark ? 0.2 : 0.1)
                                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: filter.sortBy != DonorSort.nameAsc
                                          ? kCrimson.withValues(alpha: 0.4)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sort_rounded,
                                        size: 14,
                                        color: filter.sortBy != DonorSort.nameAsc ? kCrimson : theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        switch (filter.sortBy) {
                                          DonorSort.nameAsc => Strings.sortName,
                                          DonorSort.readyFirst => Strings.sortReadyFirst,
                                          DonorSort.mostDonations => Strings.sortMostDonations,
                                        },
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: filter.sortBy != DonorSort.nameAsc ? FontWeight.bold : FontWeight.w600,
                                          color: filter.sortBy != DonorSort.nameAsc ? kCrimson : theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: _isCompactView ? Strings.viewDetailed : Strings.viewCompact,
                                child: InkWell(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _isCompactView = !_isCompactView);
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isCompactView ? Icons.view_agenda_outlined : Icons.view_headline_rounded,
                                          size: 15,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _isCompactView ? Strings.viewDetailed : Strings.viewCompact,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) => DonorCard(
                          key: ValueKey(list[index].id),
                          donor: list[index],
                          isCompact: _isCompactView,
                        ),
                      ),
                      // নিচের কার্ডের জন্য অতিরিক্ত ফাঁকা জায়গা
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    ],
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showSyncDialog(BuildContext context) {
    SyncSettingsDialog.show(
      context,
      onSaved: () {
        _doSync();
      },
    );
  }
}


class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String hint;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = value != null && options.contains(value);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? const Color(0xFF332024) : const Color(0xFFFDE8E8))
            : (isDark ? const Color(0xFF1E232A) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSelected
              ? kCrimson.withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF2E3846) : const Color(0xFFE5E7EB)),
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: isSelected ? value : null,
          hint: Text(
            hint,
            style: TextStyle(
              fontSize: 13,
              color: onChanged == null
                  ? theme.disabledColor
                  : theme.colorScheme.onSurfaceVariant,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: isSelected ? kCrimson : theme.colorScheme.onSurfaceVariant,
          ),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected
                ? (isDark ? const Color(0xFFFF8A80) : kCrimson)
                : theme.colorScheme.onSurface,
          ),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                hint,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final option in options)
              DropdownMenuItem<String?>(
                value: option,
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: option == value ? FontWeight.w600 : FontWeight.normal,
                    color: option == value
                        ? (isDark ? const Color(0xFFFF8A80) : kCrimson)
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _BloodGroupSelector extends StatelessWidget {
  const _BloodGroupSelector({
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  static const _groups = <String?>[
    null,
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
    'Oh',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final group = _groups[index];
          return _BloodGroupPill(
            group: group,
            isSelected: selectedGroup == group,
            onTap: () {
              if (group == null || selectedGroup == group) {
                onGroupSelected(null);
              } else {
                onGroupSelected(group);
              }
            },
          );
        },
      ),
    );
  }
}

class _BloodGroupPill extends StatelessWidget {
  const _BloodGroupPill({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final String? group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final label = group ?? Strings.allGroups;
    final isRare = group == 'Oh';

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                  )
                : null,
            color: isSelected
                ? null
                : (isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFB71C1C)
                  : theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kCrimson.withValues(alpha: 0.32),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  letterSpacing: group == null ? 0 : 0.4,
                ),
              ),
              if (isRare && !isSelected) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isRare) {
      return Tooltip(
        message: 'বোম্বে ফেনোটাইপ (বিরল রক্তের গ্রুপ)',
        child: button,
      );
    }

    return button;
  }
}

class _SmartEmptyState extends StatelessWidget {
  const _SmartEmptyState({
    required this.filter,
    required this.onAddDonor,
    required this.onFindCompatible,
    required this.onResetEligible,
    required this.onResetFilters,
    required this.onCreateEmergency,
  });

  final DonorFilter filter;
  final VoidCallback onAddDonor;
  final VoidCallback onFindCompatible;
  final VoidCallback onResetEligible;
  final VoidCallback onResetFilters;
  final VoidCallback onCreateEmergency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasActiveFilter = filter.bloodGroup != null ||
        filter.district != null ||
        filter.area != null ||
        filter.eligibleOnly ||
        filter.query.isNotEmpty;

    String subtitle;
    if (filter.bloodGroup != null && filter.district != null) {
      subtitle = '${filter.district}-এ ${filter.bloodGroup} গ্রুপের কোনো ডোনার পাওয়া যায়নি।';
    } else if (filter.bloodGroup != null) {
      subtitle = '${filter.bloodGroup} গ্রুপের কোনো ডোনার পাওয়া যায়নি।';
    } else if (filter.query.isNotEmpty) {
      subtitle = '"${filter.query}" দিয়ে কোনো তথ্য পাওয়া যায়নি।';
    } else if (filter.district != null) {
      subtitle = '${filter.district}-এ কোনো ডোনার পাওয়া যায়নি।';
    } else {
      subtitle = Strings.emptyHint;
    }

    final compatibleGroups = filter.bloodGroup != null
        ? BloodCompatibility.compatibleDonorsFor(filter.bloodGroup!)
        : const <String>[];
    final canOfferCompatible = filter.bloodGroup != null &&
        !filter.includeCompatible &&
        compatibleGroups.length > 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kCrimson.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bloodtype_outlined,
                  size: 38,
                  color: kCrimson,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                Strings.emptyList,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!hasActiveFilter) ...[
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onAddDonor();
                  },
                  icon: const Icon(Icons.person_add_rounded),
                  label: const Text(Strings.addDonor),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCrimson,
                    foregroundColor: Colors.white,
                  ),
                ),
              ] else ...[
                if (canOfferCompatible) ...[
                  FilledButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onFindCompatible();
                    },
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(
                      '${Strings.findCompatibleAction} (${compatibleGroups.join(', ')})',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onResetFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text(Strings.resetFilters),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onCreateEmergency();
                  },
                  icon: const Icon(Icons.emergency_rounded, color: kCrimson, size: 18),
                  label: const Text(
                    Strings.createEmergencyPost,
                    style: TextStyle(color: kCrimson, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ড্যাশবোর্ড হিরো স্ট্যাটাস বার (Apple Health / KPI স্টাইল)
class _DashboardMetricsBar extends ConsumerWidget {
  const _DashboardMetricsBar({
    required this.isEligibleFilterActive,
    required this.onToggleEligible,
  });

  final bool isEligibleFilterActive;
  final VoidCallback onToggleEligible;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(donorStatsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return statsAsync.maybeWhen(
      data: (stats) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              // ১. মোট ডোনার
              Expanded(
                child: _MetricCard(
                  label: Strings.totalDonors,
                  value: '${toBanglaDigits(stats.totalDonors)} জন',
                  icon: Icons.people_alt_rounded,
                  accentColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),

              // ২. প্রস্তুত আজ (ট্যাপযোগ্য ফিল্টার)
              Expanded(
                child: _MetricCard(
                  label: Strings.readyDonors,
                  value: '${toBanglaDigits(stats.eligibleToday)} জন',
                  icon: Icons.favorite_rounded,
                  accentColor: kEligibleGreen,
                  isDark: isDark,
                  isActive: isEligibleFilterActive,
                  onTap: onToggleEligible,
                  badgeText: isEligibleFilterActive ? 'সক্রিয়' : null,
                ),
              ),
              const SizedBox(width: 8),

              // ৩. মোট রক্তদান
              Expanded(
                child: _MetricCard(
                  label: Strings.totalDonations,
                  value: '${toBanglaDigits(stats.totalDonations)} বার',
                  icon: Icons.water_drop_rounded,
                  accentColor: isDark ? const Color(0xFFFF5252) : kCrimson,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
    required this.isDark,
    this.isActive = false,
    this.badgeText,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isDark;
  final bool isActive;
  final String? badgeText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isTappable = onTap != null;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: isDark ? 0.22 : 0.12)
            : (isDark ? const Color(0xFF161B22) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? accentColor.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? accentColor.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4.5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: accentColor),
              ),
              const Spacer(),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? accentColor
                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
              letterSpacing: 0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (isTappable) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap!();
          },
          borderRadius: BorderRadius.circular(14),
          child: card,
        ),
      );
    }
    return card;
  }
}

/// দ্রুত ফিল্টার পিল বোতাম
class _FilterTogglePill extends StatelessWidget {
  const _FilterTogglePill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: isDark ? 0.2 : 0.12)
                : (isDark ? const Color(0xFF1E232A) : const Color(0xFFF3F4F6)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? activeColor.withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF2E3846) : const Color(0xFFE5E7EB)),
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? activeColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                    color: isActive ? activeColor : theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// সক্রিয় ফিল্টার অপসারণযোগ্য ট্যাগ
class _ActiveFilterTag extends StatelessWidget {
  const _ActiveFilterTag({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
      decoration: BoxDecoration(
        color: kCrimson.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: kCrimson.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: kCrimson,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: kCrimson),
            ),
          ),
        ],
      ),
    );
  }
}


