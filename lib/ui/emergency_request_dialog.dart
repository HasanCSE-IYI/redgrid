import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../app.dart';
import '../core/constants.dart';
import '../core/phone_normalizer.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import '../services/contact_service.dart';
import 'blood_widgets.dart';
import 'brand_icons.dart';

/// জরুরি রক্তের আবেদনের জন্য পোস্ট প্রস্তুতকরণ ও সামঞ্জস্যপূর্ণ ডোনার খোঁজার ডায়ালগ।
class EmergencyRequestDialog extends ConsumerStatefulWidget {
  const EmergencyRequestDialog({super.key, this.initialBloodGroup});

  final String? initialBloodGroup;

  static Future<void> show(BuildContext context, {String? bloodGroup}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => EmergencyRequestDialog(initialBloodGroup: bloodGroup),
    );
  }

  @override
  ConsumerState<EmergencyRequestDialog> createState() => _EmergencyRequestDialogState();
}

class _EmergencyRequestDialogState extends ConsumerState<EmergencyRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedGroup;
  String _units = '১ ব্যাগ';
  String _when = 'জরুরি / আজ';

  final _hospitalController = TextEditingController();
  final _reasonController = TextEditingController();
  final _phoneController = TextEditingController();

  static const _unitOptions = [
    '১ ব্যাগ',
    '২ ব্যাগ',
    '৩ ব্যাগ',
    '৪ ব্যাগ',
    '৫ ব্যাগ',
    '৬ ব্যাগ',
  ];

  static const _whenOptions = [
    'জরুরি / আজ',
    'আজ সন্ধ্যা',
    'আজ রাত',
    'আগামীকাল',
    'যত দ্রুত সম্ভব',
    '২ দিন পর',
  ];

  static const _reasonPresets = [
    'সিজারিয়ান',
    'জরুরি অপারেশন',
    'থ্যালাসেমিয়া',
    'দুর্ঘটনা',
  ];

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.initialBloodGroup ?? 'A+';
    _hospitalController.addListener(_onTextChanged);
    _reasonController.addListener(_onTextChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final text = _phoneController.text;
    if (text.startsWith('+880')) {
      _phoneController.value = TextEditingValue(
        text: text.substring(3),
        selection: TextSelection.collapsed(offset: text.length - 3),
      );
    } else if (text.startsWith('+88')) {
      _phoneController.value = TextEditingValue(
        text: text.substring(3),
        selection: TextSelection.collapsed(offset: text.length - 3),
      );
    } else if (text.startsWith('8801')) {
      _phoneController.value = TextEditingValue(
        text: text.substring(2),
        selection: TextSelection.collapsed(offset: text.length - 2),
      );
    }
    _onTextChanged();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _hospitalController.removeListener(_onTextChanged);
    _reasonController.removeListener(_onTextChanged);
    _phoneController.removeListener(_onPhoneChanged);
    _hospitalController.dispose();
    _reasonController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _buildBroadcastText() {
    return ContactService.composeBroadcastPost(
      bloodGroup: _selectedGroup,
      units: _units,
      hospital: _hospitalController.text,
      when: _when,
      reason: _reasonController.text,
      contactPhone: _phoneController.text.trim().isEmpty
          ? '(মোবাইল নম্বর দিন)'
          : _phoneController.text.trim(),
    );
  }

  bool _validateInputs() {
    if (_hospitalController.text.trim().isEmpty) {
      AppNotificationToast.show(
        context,
        message: 'দয়া করে রক্তদানের স্থান বা হাসপাতাল উল্লেখ করুন',
        icon: Icons.local_hospital_outlined,
        color: kCrimson,
      );
      return false;
    }
    final norm = PhoneNormalizer.normalize(_phoneController.text.trim());
    if (norm == null) {
      AppNotificationToast.show(
        context,
        message: 'যোগাযোগের জন্য সঠিক ১১ সংখ্যার মোবাইল নম্বর দিন',
        icon: Icons.phone_android_rounded,
        color: kCrimson,
      );
      return false;
    }
    return true;
  }

  Future<void> _shareWhatsApp() async {
    HapticFeedback.lightImpact();
    if (!_validateInputs()) return;
    final text = _buildBroadcastText();
    final ok = await ContactService.shareToWhatsApp(text);
    if (!ok && mounted) {
      AppNotificationToast.show(
        context,
        message: 'WhatsApp চালু করা যায়নি, পোস্টটি কপি করা হয়েছে।',
        icon: Icons.copy_rounded,
      );
    }
  }

  Future<void> _share() async {
    HapticFeedback.lightImpact();
    if (!_validateInputs()) return;
    final text = _buildBroadcastText();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: '${Strings.emergencyRequest} - $_selectedGroup',
      ),
    );
  }

  Future<void> _copy() async {
    HapticFeedback.lightImpact();
    if (!_validateInputs()) return;
    final text = _buildBroadcastText();
    await ContactService.copyToClipboard(text);
    if (mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.postCopied,
        icon: Icons.copy_rounded,
      );
    }
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
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.emergency_rounded, color: kCrimson, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        Strings.emergencyTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.5,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: Strings.cancel,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  Strings.bloodGroup,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),

                // রক্তের গ্রুপ নির্বাচক (২টি সুষম রো: পজিটিভ ও নেগেটিভ+বোম্বে)
                Column(
                  children: [
                    Row(
                      children: [
                        for (int i = 0; i < AppConstants.positiveBloodGroups.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _BloodGroupChip(
                              group: AppConstants.positiveBloodGroups[i],
                              isSelected: _selectedGroup == AppConstants.positiveBloodGroups[i],
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedGroup = AppConstants.positiveBloodGroups[i]);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (int i = 0; i < AppConstants.negativeBloodGroups.length; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: _BloodGroupChip(
                              group: AppConstants.negativeBloodGroups[i],
                              isSelected: _selectedGroup == AppConstants.negativeBloodGroups[i],
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedGroup = AppConstants.negativeBloodGroups[i]);
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // হাসপাতাল / স্থান (পূর্ণাঙ্গ প্রস্থ)
                TextField(
                  controller: _hospitalController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: Strings.patientHospital,
                    hintText: 'হাসপাতালের নাম ও এলাকা লিখুন',
                    prefixIcon: const Icon(Icons.local_hospital_outlined),
                    suffixIcon: _hospitalController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _hospitalController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final h in const [
                      'ঢাকা মেডিকেল',
                      'বিএসএমএমইউ (পিজি)',
                      'কুর্মিটোলা হাসপাতাল',
                      'চট্টগ্রাম মেডিকেল',
                      'সদর হাসপাতাল',
                    ])
                      ActionChip(
                        label: Text(h, style: const TextStyle(fontSize: 10.5)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _hospitalController.text.contains(h)
                            ? kCrimson.withValues(alpha: 0.12)
                            : null,
                        side: _hospitalController.text.contains(h)
                            ? BorderSide(color: kCrimson.withValues(alpha: 0.4))
                            : null,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (_hospitalController.text == h) {
                            _hospitalController.clear();
                          } else {
                            _hospitalController.text = h;
                          }
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // রক্তের পরিমাণ ও কখন প্রয়োজন (একটি সুষম রো)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _units,
                        decoration: const InputDecoration(
                          labelText: Strings.unitsNeeded,
                          prefixIcon: Icon(Icons.water_drop_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          for (final u in _unitOptions)
                            DropdownMenuItem(
                              value: u,
                              child: Text(u, style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            HapticFeedback.selectionClick();
                            setState(() => _units = val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _when,
                        decoration: const InputDecoration(
                          labelText: Strings.whenNeeded,
                          prefixIcon: Icon(Icons.schedule_outlined),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          for (final w in _whenOptions)
                            DropdownMenuItem(
                              value: w,
                              child: Text(w, style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            HapticFeedback.selectionClick();
                            setState(() => _when = val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // যোগাযোগের ফোন নম্বর (পূর্ণাঙ্গ প্রস্থ, ট্রাঙ্কেশন রোধে)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: Strings.contactPhone,
                    hintText: 'যেমন: ০১৭১XXXXXXXX',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    suffixIcon: _phoneController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            tooltip: Strings.clear,
                            onPressed: () {
                              _phoneController.clear();
                              setState(() {});
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.content_paste_rounded, size: 18),
                            tooltip: 'পেস্ট করুন',
                            onPressed: () async {
                              final data = await Clipboard.getData(Clipboard.kTextPlain);
                              if (data?.text != null && data!.text!.trim().isNotEmpty) {
                                HapticFeedback.lightImpact();
                                _phoneController.text = data.text!.trim();
                                setState(() {});
                              }
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // রোগীর সমস্যা / কারণ (ঐচ্ছিক)
                TextField(
                  controller: _reasonController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: Strings.reason,
                    hintText: Strings.reasonHint,
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final r in _reasonPresets)
                      ActionChip(
                        label: Text(r, style: const TextStyle(fontSize: 11)),
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: _reasonController.text == r
                            ? kCrimson.withValues(alpha: 0.15)
                            : null,
                        side: _reasonController.text == r
                            ? BorderSide(color: kCrimson.withValues(alpha: 0.5))
                            : null,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (_reasonController.text == r) {
                            _reasonController.clear();
                          } else {
                            _reasonController.text = r;
                          }
                          setState(() {});
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                // লাইভ সোশ্যাল পোস্ট প্রিভিউ বক্স
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B2028) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2C3545) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview_rounded, size: 16, color: kCrimson),
                          const SizedBox(width: 6),
                          const Text(
                            Strings.socialPreviewTitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: kCrimson,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BrandIcon.facebook(size: 13),
                                const SizedBox(width: 4),
                                const Text(
                                  'Facebook',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                BrandIcon.whatsapp(size: 13),
                                const SizedBox(width: 4),
                                const Text(
                                  'WhatsApp',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SelectableText(
                        _buildBroadcastText(),
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // একশন বাটনসমূহ (WhatsApp, সিস্টেম শেয়ার, কপি)
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: FilledButton.icon(
                        onPressed: _shareWhatsApp,
                        style: FilledButton.styleFrom(
                          backgroundColor: BrandIcon.whatsappGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                        ),
                        icon: BrandIcon.whatsapp(size: 17),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: _share,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'শেয়ার',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: FilledButton.tonalIcon(
                        onPressed: _copy,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        ),
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'কপি',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // RedGrid-এ ডোনার খোঁজার মূল বাটন
                FilledButton.icon(
                  onPressed: _findMatchingDonors,
                  icon: const Icon(Icons.person_search_rounded, size: 20),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'RedGrid-এ $_selectedGroup এর প্রস্তুত ডোনার খুঁজুন',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kCrimson,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
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

class _BloodGroupChip extends StatelessWidget {
  const _BloodGroupChip({
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
