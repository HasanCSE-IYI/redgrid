import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/areas.dart';
import '../core/constants.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import 'data_tools.dart';
import 'donor_card.dart';
import 'donor_form_screen.dart';

enum _MenuAction { backup, restore, about }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(filterProvider.notifier).setQuery(value);
    });
  }

  void _onMenu(_MenuAction action) {
    switch (action) {
      case _MenuAction.backup:
        shareBackup(context, ref);
      case _MenuAction.restore:
        restoreBackup(context, ref);
      case _MenuAction.about:
        showAboutDialog(
          context: context,
          applicationName: Strings.appTitle,
          children: const [Text(Strings.aboutBody)],
        );
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
        title: const Text(Strings.appTitle),
        actions: [
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
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      onChanged: _onQueryChanged,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: Strings.searchHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text(Strings.allGroups),
                              selected: filter.bloodGroup == null,
                              onSelected: (_) => notifier.setBloodGroup(null),
                            ),
                          ),
                          for (final group in AppConstants.bloodGroups)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(group),
                                selected: filter.bloodGroup == group,
                                onSelected: (selected) => notifier.setBloodGroup(selected ? group : null),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _FilterDropdown(
                            label: Strings.district,
                            allLabel: Strings.allDistricts,
                            value: filter.district,
                            options: kAreasByDistrict.keys.toList(),
                            onChanged: notifier.setDistrict,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _FilterDropdown(
                            label: Strings.area,
                            allLabel: Strings.allAreas,
                            value: filter.area,
                            options: areaOptions,
                            onChanged: filter.district == null ? null : notifier.setArea,
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(Strings.eligibleOnly),
                      value: filter.eligibleOnly,
                      onChanged: notifier.setEligibleOnly,
                    ),
                  ],
                ),
              ),
            ),
            ...donors.when<List<Widget>>(
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
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _MessageState(
                          icon: Icons.bloodtype_outlined,
                          title: Strings.emptyList,
                          hint: Strings.emptyHint,
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
