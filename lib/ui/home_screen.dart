import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/areas.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../data/donor_repository.dart' show DonorFilter;
import '../domain/compatibility.dart';
import '../providers.dart';
import '../services/sync_service.dart';
import 'about_dialog.dart';
import 'data_tools.dart';
import 'donor_card.dart';
import 'donor_form_screen.dart';
import 'emergency_request_dialog.dart';
import 'notification_center_sheet.dart';
import 'sync_settings_dialog.dart';

enum _MenuAction { backup, restore, syncSettings, about }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounce;
  late final TextEditingController _searchController;
  bool _isFabExtended = true;
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
          // জরুরি রক্তের আবেদন বোতাম
          IconButton(
            tooltip: Strings.emergencyBannerTitle,
            icon: const Icon(Icons.emergency_share_rounded, color: kCrimson),
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
              PopupMenuItem(value: _MenuAction.backup, child: Text(Strings.backup)),
              PopupMenuItem(value: _MenuAction.restore, child: Text(Strings.restore)),
              PopupMenuItem(value: _MenuAction.about, child: Text(Strings.about)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_add_donor',
        isExtended: _isFabExtended,
        tooltip: Strings.addDonor,
        backgroundColor: kCrimson,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          Strings.addDonor,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        onPressed: _openAddDonor,
      ),
      body: SafeArea(
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isFabExtended) setState(() => _isFabExtended = false);
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isFabExtended) setState(() => _isFabExtended = true);
              }
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: _doSync,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // স্মার্ট নোটিফিকেশন ব্যানার
                        const HomeNotificationBanner(),
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
                        const SizedBox(height: 8),
                        // রক্তের গ্রুপ নির্বাচক
                        _BloodGroupSelector(
                          selectedGroup: filter.bloodGroup,
                          onGroupSelected: (group) {
                            HapticFeedback.selectionClick();
                            notifier.setBloodGroup(group);
                          },
                        ),
                        if (filter.bloodGroup != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setIncludeCompatible(!filter.includeCompatible);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: filter.includeCompatible
                                    ? kCrimson.withValues(alpha: 0.1)
                                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: filter.includeCompatible
                                      ? kCrimson.withValues(alpha: 0.4)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    filter.includeCompatible ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                                    size: 16,
                                    color: filter.includeCompatible ? kCrimson : theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'সামঞ্জস্যপূর্ণ রক্তদাতা সহ (${BloodCompatibility.compatibleDonorsFor(filter.bloodGroup!).join(', ')})',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: filter.includeCompatible ? FontWeight.w600 : FontWeight.normal,
                                        color: filter.includeCompatible ? kCrimson : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _FilterDropdown(
                                label: Strings.district,
                                allLabel: Strings.allDistricts,
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
                                label: Strings.area,
                                allLabel: Strings.allAreas,
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
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setEligibleOnly(!filter.eligibleOnly);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: filter.eligibleOnly
                                  ? kEligibleGreen.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: filter.eligibleOnly
                                    ? kEligibleGreen.withValues(alpha: 0.4)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  filter.eligibleOnly ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                  size: 16,
                                  color: filter.eligibleOnly ? kEligibleGreen : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    Strings.eligibleOnly,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: filter.eligibleOnly ? FontWeight.w600 : FontWeight.normal,
                                      color: filter.eligibleOnly ? kEligibleGreen : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                                  filter.query.isNotEmpty) ...[
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
                      // নিচের কার্ড ঢাকা পড়া ঠেকাতে অতিরিক্ত ফাঁকা জায়গা
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 80),
                      ),
                    ],
            ),
          ],
        ),
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
    required this.label,
    required this.allLabel,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String allLabel;
  final String? value;
  final List<String> options;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: options.contains(value) ? value : null,
          onChanged: onChanged,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            for (final option in options) DropdownMenuItem<String?>(value: option, child: Text(option)),
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
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? kCrimson
                : (isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isSelected
                  ? kCrimson
                  : theme.colorScheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.55),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kCrimson.withValues(alpha: 0.3),
                      blurRadius: 6,
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
                  icon: const Icon(Icons.emergency_share, color: kCrimson, size: 18),
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


