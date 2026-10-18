import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/areas.dart';
import '../core/constants.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../domain/compatibility.dart';
import '../providers.dart';
import '../services/sync_service.dart';
import 'about_dialog.dart';
import 'data_tools.dart';
import 'donor_card.dart';
import 'donor_form_screen.dart';
import 'emergency_request_dialog.dart';

enum _MenuAction { backup, restore, about }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounce;
  late final TextEditingController _searchController;
  bool _hasSyncUrl = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(() => setState(() {}));
    _checkSyncUrl();
  }

  Future<void> _checkSyncUrl() async {
    final repo = ref.read(donorRepositoryProvider);
    final url = await repo.getSetting(AppConstants.settingCloudUrl);
    final effective = (url != null && url.trim().isNotEmpty)
        ? url
        : AppConstants.defaultCloudUrl;
    if (mounted) {
      setState(() => _hasSyncUrl = effective.trim().isNotEmpty);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }

  void _onMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.backup:
        shareBackup(context, ref);
      case _MenuAction.restore:
        restoreBackup(context, ref);
      case _MenuAction.about:
        AboutAppDialog.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(filterProvider);
    final notifier = ref.read(filterProvider.notifier);
    final donors = ref.watch(donorListProvider);
    final statsAsync = ref.watch(donorStatsProvider);
    final syncStatus = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);
    final isSyncing = syncStatus.status == SyncStatus.syncing;

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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFFFF5252)
                    : kCrimson,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
        actions: [
          // Cloud Sync Icon
          isSyncing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  tooltip: Strings.cloudSync,
                  icon: Icon(
                    _hasSyncUrl ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: _hasSyncUrl ? Colors.green.shade600 : theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () => _showSyncDialog(context),
                ),
          IconButton(
            tooltip: Strings.emergencyRequest,
            icon: const Icon(Icons.emergency_share, color: kCrimson),
            onPressed: () => EmergencyRequestDialog.show(
              context,
              bloodGroup: filter.bloodGroup,
            ),
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: Strings.menu,
            onSelected: _onMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: _MenuAction.backup, child: Text(Strings.backup)),
              PopupMenuItem(value: _MenuAction.restore, child: Text(Strings.restore)),
              PopupMenuItem(value: _MenuAction.about, child: Text(Strings.about)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const DonorFormScreen()),
        ),
        icon: const Icon(Icons.person_add),
        label: const Text(Strings.addDonor),
      ),
      body: SafeArea(
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
                    // সারাংশ পরিসংখ্যান ব্যানার
                    statsAsync.when(
                      skipLoadingOnReload: true,
                      data: (stats) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                label: Strings.totalDonors,
                                value: '${toBanglaDigits(stats.totalDonors)} ${Strings.countUnit}',
                                icon: Icons.people_outline,
                                color: theme.colorScheme.primary,
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                              ),
                              InkWell(
                                onTap: () => notifier.setEligibleOnly(!filter.eligibleOnly),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  child: _StatItem(
                                    label: Strings.readyDonors,
                                    value: '${toBanglaDigits(stats.eligibleToday)} ${Strings.countUnit}',
                                    icon: Icons.check_circle_outline,
                                    color: kEligibleGreen,
                                    isHighlighted: filter.eligibleOnly,
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
                              ),
                              _StatItem(
                                label: Strings.totalDonations,
                                value: '${toBanglaDigits(stats.totalDonations)} ${Strings.timesUnit}',
                                icon: Icons.bloodtype_outlined,
                                color: kCrimson,
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    // জরুরি আবেদন দ্রুত তৈরি বোতাম
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton.icon(
                        onPressed: () => EmergencyRequestDialog.show(
                          context,
                          bloodGroup: filter.bloodGroup,
                        ),
                        icon: const Icon(Icons.emergency, color: kCrimson, size: 20),
                        label: const Text(
                          'জরুরি রক্তের আবেদন তৈরি ও শেয়ার',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: kCrimson, width: 1.2),
                          foregroundColor: kCrimson,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(Strings.disclaimer, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: Strings.searchHint,
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'মুছুন',
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _searchController.clear();
                                  ref.read(filterProvider.notifier).setQuery('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _BloodGroupMatrix(
                      selectedGroup: filter.bloodGroup,
                      onGroupSelected: (group) {
                        HapticFeedback.selectionClick();
                        notifier.setBloodGroup(group);
                      },
                    ),
                    if (filter.bloodGroup != null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          notifier.setIncludeCompatible(!filter.includeCompatible);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: filter.includeCompatible
                                ? kCrimson.withValues(alpha: 0.1)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: filter.includeCompatible
                                  ? kCrimson.withValues(alpha: 0.5)
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                filter.includeCompatible ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
                                size: 18,
                                color: filter.includeCompatible ? kCrimson : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${filter.bloodGroup} এর সামঞ্জস্যপূর্ণ ডোনার সহ (${BloodCompatibility.compatibleDonorsFor(filter.bloodGroup!).join(', ')})',
                                  style: TextStyle(
                                    fontSize: 12,
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
                    const SizedBox(height: 8),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(Strings.eligibleOnly),
                      value: filter.eligibleOnly,
                      onChanged: (val) {
                        HapticFeedback.selectionClick();
                        notifier.setEligibleOnly(val);
                      },
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
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, index) => DonorCard(
                          key: ValueKey(list[index].id),
                          donor: list[index],
                        ),
                      ),
                      // নিচের বোতামের নিচে কার্ড ঢাকা পড়া ঠেকাতে ফাঁকা জায়গা।
                      const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _showSyncDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _SyncSettingsDialog(
        onSaved: () {
          _checkSyncUrl();
          _doSync();
        },
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isHighlighted = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isHighlighted ? color : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isHighlighted ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
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
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? hint;
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
          if (hint != null) ...[
            const SizedBox(height: 8),
            Text(hint!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _BloodGroupMatrix extends StatelessWidget {
  const _BloodGroupMatrix({
    required this.selectedGroup,
    required this.onGroupSelected,
  });

  final String? selectedGroup;
  final ValueChanged<String?> onGroupSelected;

  static const _row1 = <String?>[null, 'A+', 'B+', 'O+', 'AB+'];
  static const _row2 = <String?>['Oh', 'A-', 'B-', 'O-', 'AB-'];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context, _row1),
        const SizedBox(height: 6),
        _buildRow(context, _row2),
      ],
    );
  }

  Widget _buildRow(BuildContext context, List<String?> groups) {
    return Row(
      children: [
        for (int i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _BloodGroupButton(
              group: groups[i],
              isSelected: selectedGroup == groups[i],
              onTap: () {
                if (groups[i] == null) {
                  onGroupSelected(null);
                } else if (selectedGroup == groups[i]) {
                  onGroupSelected(null);
                } else {
                  onGroupSelected(groups[i]);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _BloodGroupButton extends StatelessWidget {
  const _BloodGroupButton({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? kCrimson
                : (isDark
                    ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? kCrimson
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: kCrimson.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    ),
                  ]
                : null,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                  letterSpacing: group == null ? 0 : 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartEmptyState extends StatelessWidget {
  const _SmartEmptyState({
    required this.filter,
    required this.onFindCompatible,
    required this.onResetEligible,
    required this.onResetFilters,
    required this.onCreateEmergency,
  });

  final DonorFilter filter;
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
              if (filter.eligibleOnly) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onResetEligible();
                  },
                  icon: const Icon(Icons.history_rounded),
                  label: const Text('অপেক্ষমান ডোনার সহ সকল তালিকা দেখুন'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onCreateEmergency();
                },
                icon: const Icon(Icons.emergency_share, color: kCrimson),
                label: const Text(
                  Strings.createEmergencyPost,
                  style: TextStyle(color: kCrimson, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kCrimson, width: 1.2),
                ),
              ),
              if (hasActiveFilter) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onResetFilters();
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text(Strings.resetFilters),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Sync Settings Dialog
// ==========================================

class _SyncSettingsDialog extends ConsumerStatefulWidget {
  const _SyncSettingsDialog({required this.onSaved});

  final VoidCallback onSaved;

  @override
  ConsumerState<_SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends ConsumerState<_SyncSettingsDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _keyController;
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _testing = false;
  bool _isCustom = false;
  bool _showAdvanced = false;
  String? _lastSynced;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _keyController = TextEditingController();
    _loadSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final svc = ref.read(syncServiceProvider);
    final settings = await svc.loadSettings();
    if (!mounted) return;
    setState(() {
      _urlController.text = settings.url;
      _keyController.text = settings.syncKey ?? '';
      _lastSynced = settings.lastSynced;
      _isCustom = settings.isCustom;
      _showAdvanced = settings.isCustom;
      _loading = false;
    });
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    final svc = ref.read(syncServiceProvider);
    final testUrl = _urlController.text.trim().isEmpty
        ? AppConstants.defaultCloudUrl
        : _urlController.text.trim();
    final res = await svc.testConnectionDetails(
      testUrl,
      syncKey: _keyController.text.trim().isEmpty ? null : _keyController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.success ? '✅ সংযোগ সফল!' : '❌ ${res.error ?? "সংযোগ ব্যর্থ"}'),
        backgroundColor: res.success ? Colors.green.shade700 : Colors.red.shade700,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final svc = ref.read(syncServiceProvider);
    await svc.saveSettings(
      url: _urlController.text.trim(),
      syncKey: _keyController.text.trim().isEmpty ? null : _keyController.text.trim(),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved();
  }

  Future<void> _resetToDefault() async {
    final svc = ref.read(syncServiceProvider);
    await svc.resetToDefault();
    if (!mounted) return;
    setState(() {
      _urlController.text = AppConstants.defaultCloudUrl;
      _keyController.text = '';
      _isCustom = false;
      _showAdvanced = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.cloudSyncResetDone)),
    );
    widget.onSaved();
  }

  Future<void> _syncNow() async {
    Navigator.of(context).pop();
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const AlertDialog(
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.cloud_sync, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text(Strings.cloudSyncTitle),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isCustom
                        ? theme.colorScheme.secondaryContainer.withOpacity(0.4)
                        : Colors.green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCustom
                          ? theme.colorScheme.secondary.withOpacity(0.3)
                          : Colors.green.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isCustom ? Icons.tune : Icons.check_circle_outline,
                        color: _isCustom ? theme.colorScheme.secondary : Colors.green.shade700,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isCustom ? Strings.cloudSyncCustom : Strings.cloudSyncBuiltIn,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _isCustom ? theme.colorScheme.secondary : Colors.green.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isCustom
                                  ? _urlController.text
                                  : Strings.cloudSyncBuiltInDesc,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Last synced info
                Row(
                  children: [
                    const Icon(Icons.history, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _lastSynced != null
                            ? '${Strings.cloudSyncLastSynced}: ${_lastSynced!.substring(0, 19).replaceAll('T', ' ')}'
                            : Strings.cloudSyncNeverSynced,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Sync Now Primary Action
                FilledButton.icon(
                  onPressed: _syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text(Strings.cloudSyncSyncNow),
                ),
                const SizedBox(height: 8),

                // Advanced Settings Toggle
                TextButton.icon(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more, size: 18),
                  label: const Text(Strings.cloudSyncAdvancedSettings),
                ),

                if (_showAdvanced) ...[
                  const Divider(),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: Strings.cloudSyncUrl,
                      hintText: Strings.cloudSyncUrlHint,
                      prefixIcon: Icon(Icons.cloud_outlined),
                    ),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return Strings.cloudSyncUrlRequired;
                      }
                      final uri = Uri.tryParse(v.trim());
                      if (uri == null || !uri.hasScheme) {
                        return 'সঠিক URL দিন (https:// দিয়ে শুরু করুন)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _keyController,
                    decoration: const InputDecoration(
                      labelText: Strings.cloudSyncKey,
                      hintText: Strings.cloudSyncKeyHint,
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                    obscureText: true,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testing ? null : _test,
                          icon: _testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering, size: 16),
                          label: const Text(Strings.cloudSyncTest),
                        ),
                      ),
                      if (_isCustom) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _resetToDefault,
                          child: const Text(Strings.cloudSyncResetDefault),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Strings.cancel),
        ),
        if (_showAdvanced)
          FilledButton(
            onPressed: _save,
            child: const Text(Strings.cloudSyncSave),
          ),
      ],
    );
  }
}
