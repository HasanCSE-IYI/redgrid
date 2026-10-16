import 'constants.dart';
import 'date_format.dart';
import 'phone_normalizer.dart';
import 'strings_bn.dart';

/// ফর্ম ও ব্যাকআপ রিস্টোর - দুই জায়গার তথ্যই এই একটি ভ্যালিডেটরের মধ্য দিয়ে যায়।
class InputValidator {
  InputValidator._();

  /// ভুল থাকলে বাংলা বার্তা, ঠিক থাকলে null।
  static String? validateDonorMap(Map<String, Object?> map, {DateTime? now}) {
    final name = map['name'];
    if (name is! String || name.trim().isEmpty || name.trim().length > AppConstants.maxNameLength) {
      return Strings.errName;
    }
    if (!AppConstants.bloodGroups.contains(map['blood_group'])) return Strings.errBloodGroup;
    if (!AppConstants.genders.contains(map['gender'])) return Strings.errGender;

    final phone = map['phone'];
    if (phone is! String || PhoneNormalizer.normalize(phone) == null) return Strings.errPhone;

    for (final key in ['district', 'area']) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty || value.trim().length > AppConstants.maxPlaceLength) {
        return Strings.errPlace;
      }
    }

    final consent = map['consent_to_share'];
    if (consent != 0 && consent != 1) return Strings.errConsent;

    final last = map['last_donation_date'];
    if (last != null) {
      final parsed = last is String ? parseIsoDate(last) : null;
      final today = dateOnlyUtc(now ?? DateTime.now());
      if (parsed == null || parsed.isAfter(today)) return Strings.errDate;
    }

    final total = map['total_donations'];
    if (total is! int || total < 0) return Strings.errTotal;

    final notes = map['notes'];
    if (notes != null && (notes is! String || notes.length > AppConstants.maxNotesLength)) {
      return Strings.errNotes;
    }
    return null;
  }
}
