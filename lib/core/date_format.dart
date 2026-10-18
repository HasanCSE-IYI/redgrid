import 'digits.dart';

final RegExp _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String isoNow() => DateTime.now().toUtc().toIso8601String();

DateTime dateOnlyUtc(DateTime date) => DateTime.utc(date.year, date.month, date.day);

/// কঠোরভাবে `YYYY-MM-DD` পার্স করে। ভুল তারিখ (যেমন 2026-02-31) হলে null।
DateTime? parseIsoDate(String? value) {
  if (value == null || !_isoDate.hasMatch(value)) return null;
  final year = int.parse(value.substring(0, 4));
  final month = int.parse(value.substring(5, 7));
  final day = int.parse(value.substring(8, 10));
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) return null;
  return parsed;
}

/// বাংলা অঙ্কে `দিন/মাস/বছর`।
String formatDateBn(DateTime date) => toBanglaDigits('${date.day}/${date.month}/${date.year}');

/// ISO স্ট্রিং তারিখ (YYYY-MM-DD) পার্স করে বাংলায় দিন/মাস/বছর দেখায়।
String formatIsoDateBn(String iso) {
  final parsed = parseIsoDate(iso);
  return parsed != null ? formatDateBn(parsed) : toBanglaDigits(iso);
}

/// বাংলা ভাষায় আপেক্ষিক সময় প্রদর্শন (যেমন: এইমাত্র, ৫ মিনিট আগে, ২ ঘণ্টা আগে, ৩ দিন আগে)
String formatRelativeTimeBn(DateTime dateTime, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(dateTime);
  if (diff.isNegative || diff.inSeconds < 60) {
    return 'এইমাত্র';
  } else if (diff.inMinutes < 60) {
    return '${toBanglaDigits(diff.inMinutes)} মিনিট আগে';
  } else if (diff.inHours < 24) {
    return '${toBanglaDigits(diff.inHours)} ঘণ্টা আগে';
  } else if (diff.inDays < 7) {
    return '${toBanglaDigits(diff.inDays)} দিন আগে';
  } else {
    return formatDateBn(dateTime);
  }
}

