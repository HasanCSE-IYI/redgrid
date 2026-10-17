import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../core/constants.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import '../services/contact_service.dart';

/// জরুরি রক্তের আবেদনের জন্য পোস্ট প্রস্তুতকরণ ও সামঞ্জস্যপূর্ণ ডোনার খোঁজার ডায়ালগ।
class EmergencyRequestDialog extends ConsumerStatefulWidget {
  const EmergencyRequestDialog({super.key, this.initialBloodGroup});

  final String? initialBloodGroup;

  static Future<void> show(BuildContext context, {String? bloodGroup}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EmergencyRequestDialog(initialBloodGroup: bloodGroup),
    );
  }

  @override
  ConsumerState<EmergencyRequestDialog> createState() => _EmergencyRequestDialogState();
}

class _EmergencyRequestDialogState extends ConsumerState<EmergencyRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedGroup;
  final _hospitalController = TextEditingController();
  final _unitsController = TextEditingController(text: '১ ব্যাগ');
  final _whenController = TextEditingController(text: 'জরুরি / আজ');
  final _reasonController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.initialBloodGroup ?? 'A+';
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _unitsController.dispose();
    _whenController.dispose();
    _reasonController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _buildBroadcastText() {
    return ContactService.composeBroadcastPost(
      bloodGroup: _selectedGroup,
      units: _unitsController.text,
      hospital: _hospitalController.text,
      when: _whenController.text,
      reason: _reasonController.text,
      contactPhone: _phoneController.text,
    );
  }

  Future<void> _share() async {
    final text = _buildBroadcastText();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: '${Strings.emergencyRequest} - $_selectedGroup',
      ),
    );
  }

  void _copy() {
    final text = _buildBroadcastText();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(Strings.postCopied), duration: Duration(seconds: 2)),
    );
  }

  void _findMatchingDonors() {
    final notifier = ref.read(filterProvider.notifier);
    notifier.setBloodGroup(_selectedGroup);
    notifier.setIncludeCompatible(true);
    notifier.setEligibleOnly(true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.emergency, color: kCrimson, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Strings.emergencyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(Strings.bloodGroup, style: theme.textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final group in AppConstants.bloodGroups)
                      ChoiceChip(
                        label: Text(group),
                        selected: _selectedGroup == group,
                        selectedColor: kCrimson.withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          fontWeight: _selectedGroup == group ? FontWeight.bold : FontWeight.normal,
                          color: _selectedGroup == group ? kCrimson : null,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedGroup = group);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _hospitalController,
                        decoration: const InputDecoration(
                          labelText: Strings.patientHospital,
                          hintText: Strings.hospitalHint,
                          prefixIcon: Icon(Icons.local_hospital_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _unitsController,
                        decoration: const InputDecoration(
                          labelText: Strings.unitsNeeded,
                          hintText: Strings.unitsHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _whenController,
                        decoration: const InputDecoration(
                          labelText: Strings.whenNeeded,
                          hintText: Strings.whenHint,
                          prefixIcon: Icon(Icons.schedule_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: Strings.contactPhone,
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: Strings.reason,
                    hintText: Strings.reasonHint,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copy,
                        icon: const Icon(Icons.copy_outlined, size: 18),
                        label: const Text(Strings.copyPost),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text(Strings.sharePost),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _findMatchingDonors,
                  icon: const Icon(Icons.search),
                  label: Text('RedGrid-এ $_selectedGroup এর প্রস্তুত ডোনার খুঁজুন'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCrimson,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
