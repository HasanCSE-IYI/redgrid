import 'digits.dart';

/// সব জায়গায় একই ফোন নম্বর নরমালাইজার। শুধু `01XXXXXXXXX` ফরম্যাট সংরক্ষণ হয়।
class PhoneNormalizer {
  PhoneNormalizer._();

  static final RegExp _valid = RegExp(r'^01[3-9]\d{8}$');

  /// সঠিক হলে ১১ সংখ্যার নম্বর, নইলে null।
  static String? normalize(String? input) {
    if (input == null) return null;
    var digits = toAsciiDigits(input).replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('880')) {
      digits = digits.substring(2);
    }
    return _valid.hasMatch(digits) ? digits : null;
  }

  /// সার্চের জন্য আংশিক নম্বরকে সংখ্যায় রূপান্তর করে।
  static String searchDigits(String input) {
    var digits = toAsciiDigits(input).replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8801')) digits = digits.substring(2);
    return digits;
  }
}
