import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/areas.dart';
import '../core/constants.dart';
import '../core/date_format.dart';
import '../core/phone_normalizer.dart';
import '../core/strings_bn.dart';
import '../data/donor.dart';
import '../data/donor_repository.dart';
import '../providers.dart';
import 'blood_widgets.dart';
import 'suggest_field.dart';

class DonorFormScreen extends ConsumerStatefulWidget {
  const DonorFormScreen({super.key, this.donor});

  final Donor? donor;

  @override
  ConsumerState<DonorFormScreen> createState() => _DonorFormScreenState();
}

class _DonorFormScreenState extends ConsumerState<DonorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _notes;
  late String _gender;
  late String _district;
  late String _area;
  String? _bloodGroup;
  String? _lastDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final donor = widget.donor;
    _name = TextEditingController(text: donor?.name ?? '');
    _phone = TextEditingController(text: donor?.phone ?? '');
    _notes = TextEditingController(text: donor?.notes ?? '');
    _gender = donor?.gender ?? AppConstants.genderMale;
    _district = donor?.district ?? '';
    _area = donor?.area ?? '';
    _bloodGroup = donor?.bloodGroup;
    _lastDate = donor?.lastDonationDate;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _requiredText(String? value, {int? max}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return Strings.required;
    if (max != null && text.length > max) return Strings.required;
    return null;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(1970);
    DateTime initial = parseIsoDate(_lastDate) ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(now)) initial = now;
    final picked = await pickDonationDate(
      context,
      initialDate: initial,
      firstDate: first,
      lastDate: now,
    );
    if (picked != null && mounted) {
      setState(() => _lastDate = isoDate(picked));
    }
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final existing = widget.donor;
    final stamp = isoNow();
    final notes = _notes.text.trim();
    final donor = Donor(
      id: existing?.id,
      name: _name.text.trim(),
      bloodGroup: _bloodGroup!,
      gender: _gender,
      phone: PhoneNormalizer.normalize(_phone.text)!,
      consentToShare: true,
      district: _district.trim(),
      area: _area.trim(),
      lastDonationDate: _lastDate,
      totalDonations: existing?.totalDonations ?? 0,
      notes: notes.isEmpty ? null : notes,
      createdAt: existing?.createdAt ?? stamp,
      updatedAt: stamp,
    );

    final navigator = Navigator.of(context);
    final notifier = ref.read(donorListProvider.notifier);

    setState(() => _saving = true);
    try {
      if (existing == null) {
        await notifier.add(donor);
      } else {
        await notifier.edit(donor);
      }
      navigator.pop();
    } on DuplicatePhoneException {
      if (mounted) {
        AppNotificationToast.show(context, message: Strings.duplicatePhone, color: kCrimson);
      }
    } catch (_) {
      if (mounted) {
        AppNotificationToast.show(context, message: Strings.genericError, color: kCrimson);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.donor != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? Strings.editDonor : Strings.addDonor)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. প্রাথমিক তথ্য কার্ড
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'প্রাথমিক তথ্য',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _name,
                        maxLength: AppConstants.maxNameLength,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: Strings.name,
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => _requiredText(v, max: AppConstants.maxNameLength),
                      ),
                      const SizedBox(height: 10),
                      Text(Strings.gender, style: theme.textTheme.labelMedium),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: AppConstants.genderMale,
                              label: Text(Strings.male),
                              icon: Icon(Icons.male_rounded),
                            ),
                            ButtonSegment(
                              value: AppConstants.genderFemale,
                              label: Text(Strings.female),
                              icon: Icon(Icons.female_rounded),
                            ),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (selection) {
                            HapticFeedback.selectionClick();
                            setState(() => _gender = selection.first);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FormField<String>(
                        initialValue: _bloodGroup,
                        validator: (value) => value == null ? Strings.required : null,
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(Strings.bloodGroup, style: theme.textTheme.labelMedium),
                            const SizedBox(height: 8),
                            Column(
                              children: [
                                Row(
                                  children: [
                                    for (int i = 0; i < AppConstants.positiveBloodGroups.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 8),
                                      Expanded(
                                        child: _BloodGroupFormChip(
                                          group: AppConstants.positiveBloodGroups[i],
                                          isSelected: state.value == AppConstants.positiveBloodGroups[i],
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            final g = AppConstants.positiveBloodGroups[i];
                                            _bloodGroup = g;
                                            state.didChange(g);
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    for (int i = 0; i < AppConstants.negativeBloodGroups.length; i++) ...[
                                      if (i > 0) const SizedBox(width: 6),
                                      Expanded(
                                        child: _BloodGroupFormChip(
                                          group: AppConstants.negativeBloodGroups[i],
                                          isSelected: state.value == AppConstants.negativeBloodGroups[i],
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            final g = AppConstants.negativeBloodGroups[i];
                                            _bloodGroup = g;
                                            state.didChange(g);
                                          },
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (state.hasError)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  state.errorText!,
                                  style: TextStyle(color: theme.colorScheme.error),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. যোগাযোগ ও অবস্থান কার্ড
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.phone_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'যোগাযোগ ও অবস্থান',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: Strings.phone,
                          hintText: '01XXXXXXXXX',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                        ),
                        validator: (v) => PhoneNormalizer.normalize(v) == null ? Strings.invalidPhone : null,
                      ),
                      const SizedBox(height: 12),
                      SuggestField(
                        label: Strings.district,
                        initialValue: _district,
                        maxLength: AppConstants.maxPlaceLength,
                        optionsBuilder: () => kAreasByDistrict.keys.toList(),
                        onChanged: (value) => _district = value,
                        validator: (v) => _requiredText(v, max: AppConstants.maxPlaceLength),
                      ),
                      SuggestField(
                        label: Strings.area,
                        initialValue: _area,
                        maxLength: AppConstants.maxPlaceLength,
                        optionsBuilder: () => kAreasByDistrict[_district.trim()] ?? const [],
                        onChanged: (value) => _area = value,
                        validator: (v) => _requiredText(v, max: AppConstants.maxPlaceLength),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. রক্তদানের তথ্য ও সম্মতি কার্ড
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'রক্তদানের তথ্য ও সম্মতি',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(Strings.lastDonation),
                        subtitle: Builder(
                          builder: (context) {
                            final parsed = parseIsoDate(_lastDate);
                            return Text(
                              parsed == null ? Strings.notSet : formatDateBn(parsed),
                              style: TextStyle(
                                color: parsed != null ? kCrimson : null,
                                fontWeight: parsed != null ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          },
                        ),
                        onTap: _pickDate,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_lastDate != null)
                              IconButton(
                                tooltip: Strings.clear,
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () => setState(() => _lastDate = null),
                              ),
                            IconButton(
                              tooltip: Strings.pickDate,
                              icon: const Icon(Icons.calendar_month_rounded),
                              onPressed: _pickDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _notes,
                        maxLength: AppConstants.maxNotesLength,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: Strings.notes,
                          prefixIcon: Icon(Icons.edit_note_rounded),
                        ),
                      ),
                      const SizedBox(height: 6),
                      FormField<bool>(
                        initialValue: widget.donor?.consentToShare ?? true,
                        validator: (value) => value == true ? null : Strings.consentRequired,
                        builder: (state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: state.value ?? true,
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                state.didChange(value);
                              },
                              title: const Text(
                                Strings.consent,
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            if (state.hasError)
                              Text(state.errorText!, style: TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // সংরক্ষণ বোতাম
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kCrimson,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        Strings.save,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _BloodGroupFormChip extends StatelessWidget {
  const _BloodGroupFormChip({
    required this.group,
    required this.isSelected,
    required this.onTap,
  });

  final String group;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          height: 38,
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
          child: Text(
            group,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
