import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import '../services/backup_service.dart';

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(Strings.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// সতর্কবার্তা দেখিয়ে ব্যাকআপ ফাইল শেয়ার করে।
Future<void> shareBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);
  final ok = await _confirm(
    context,
    title: Strings.backup,
    body: Strings.backupWarning,
    action: Strings.continueLabel,
  );
  if (!ok) return;
  try {
    await service.shareBackup();
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
  }
}

/// ফাইল বেছে যাচাই করে, নিশ্চিত করিয়ে সব তথ্য প্রতিস্থাপন করে।
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(backupServiceProvider);

  try {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty) return;
    final path = picked.first.path;
    if (path == null) return;

    final text = await File(path).readAsString();
    final data = service.parseBackup(text);

    if (!context.mounted) return;
    final ok = await _confirm(
      context,
      title: Strings.restoreTitle,
      body: Strings.restoreBody(
        toBanglaDigits(data.donors.length),
        toBanglaDigits(data.logs.length),
      ),
      action: Strings.restore,
    );
    if (!ok) return;

    await service.restore(data);
    ref.invalidate(donorListProvider);
    ref.invalidate(donorStatsProvider);
    messenger.showSnackBar(const SnackBar(content: Text(Strings.restoreDone)));
  } on BackupException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text(Strings.genericError)));
  }
}
