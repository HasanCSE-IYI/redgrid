import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import 'notification_center_sheet.dart';

/// ক্লাউড সিঙ্ক কনফিগারেশন এবং অন-ডিমান্ড সিঙ্ক ডায়ালগ
class SyncSettingsDialog extends ConsumerStatefulWidget {
  const SyncSettingsDialog({super.key, required this.onSaved});

  final VoidCallback onSaved;

  static Future<void> show(BuildContext context, {required VoidCallback onSaved}) {
    return showDialog<void>(
      context: context,
      builder: (_) => SyncSettingsDialog(onSaved: onSaved),
    );
  }

  @override
  ConsumerState<SyncSettingsDialog> createState() => _SyncSettingsDialogState();
}

class _SyncSettingsDialogState extends ConsumerState<SyncSettingsDialog> {
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

    AppNotificationToast.show(
      context,
      message: res.success ? 'সংযোগ সফল হয়েছে!' : (res.error ?? 'সংযোগ ব্যর্থ'),
      icon: res.success ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
      color: res.success ? Colors.green.shade700 : Colors.red.shade700,
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
    AppNotificationToast.show(
      context,
      message: Strings.cloudSyncResetDone,
      icon: Icons.check_circle_rounded,
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
                        ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.4)
                        : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCustom
                          ? theme.colorScheme.secondary.withValues(alpha: 0.3)
                          : Colors.green.withValues(alpha: 0.4),
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
