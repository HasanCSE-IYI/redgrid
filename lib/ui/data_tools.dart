import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../core/digits.dart';
import '../core/strings_bn.dart';
import '../providers.dart';
import '../services/backup_service.dart';
import 'blood_widgets.dart';
import 'notification_center_sheet.dart';

/// সতর্কবার্তা দেখিয়ে ব্যাকআপ ফাইল শেয়ার করে।
Future<void> shareBackup(BuildContext context, WidgetRef ref) async {
  final service = ref.read(backupServiceProvider);
  final ok = await showConfirmDialog(
    context,
    title: Strings.backup,
    message: Strings.backupWarning,
    confirmLabel: Strings.continueLabel,
  );
  if (!ok) return;
  try {
    await service.shareBackup();
  } catch (_) {
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.genericError,
        icon: Icons.error_outline_rounded,
        color: kCrimson,
      );
    }
  }
}

/// ফাইল বেছে যাচাই করে, নিশ্চিত করিয়ে সব তথ্য প্রতিস্থাপন করে।
Future<void> restoreBackup(BuildContext context, WidgetRef ref) async {
  final service = ref.read(backupServiceProvider);

  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return;
    final path = file.path;
    if (path == null) return;

    final text = await File(path).readAsString();
    final data = service.parseBackup(text);

    if (!context.mounted) return;
    final ok = await showConfirmDialog(
      context,
      title: Strings.restoreTitle,
      message: Strings.restoreBody(
        toBanglaDigits(data.donors.length),
        toBanglaDigits(data.logs.length),
      ),
      confirmLabel: Strings.restore,
      isDestructive: true,
    );
    if (!ok) return;

    await service.restore(data);
    ref.invalidate(donorListProvider);
    ref.invalidate(donorStatsProvider);
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.restoreDone,
        icon: Icons.check_circle_rounded,
        color: kEligibleGreen,
      );
    }
  } on BackupException catch (e) {
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: e.message,
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade800,
      );
    }
  } catch (_) {
    if (context.mounted) {
      AppNotificationToast.show(
        context,
        message: Strings.genericError,
        icon: Icons.error_outline_rounded,
        color: kCrimson,
      );
    }
  }
}
