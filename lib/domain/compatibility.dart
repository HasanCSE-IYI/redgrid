/// চিকিৎসাবিজ্ঞান অনুযায়ী লোহিত রক্তকণিকা (Red Blood Cell) সঞ্চালনের সামঞ্জস্যতা নির্ধারণ।
class BloodCompatibility {
  BloodCompatibility._();

  /// রোগীর রক্তের গ্রুপের সাপেক্ষে সামঞ্জস্যপূর্ণ দাতার গ্রুপসমূহ (রক্ত গ্রহীতা -> রক্তদাতা)।
  static const Map<String, List<String>> _compatibleDonors = {
    'A+': ['A+', 'A-', 'O+', 'O-'],
    'A-': ['A-', 'O-'],
    'B+': ['B+', 'B-', 'O+', 'O-'],
    'B-': ['B-', 'O-'],
    'AB+': ['AB+', 'AB-', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-'],
    'AB-': ['AB-', 'A-', 'B-', 'O-'],
    'O+': ['O+', 'O-'],
    'O-': ['O-'],
    'Oh': ['Oh'], // বোম্বে ব্লাড গ্রুপ
  };

  /// দাতার রক্তের গ্রুপের সাপেক্ষে গ্রহীতার গ্রুপসমূহ (রক্তদাতা -> রক্ত গ্রহীতা)।
  static const Map<String, List<String>> _canDonateTo = {
    'O-': ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
    'O+': ['O+', 'A+', 'B+', 'AB+'],
    'A-': ['A-', 'A+', 'AB-', 'AB+'],
    'A+': ['A+', 'AB+'],
    'B-': ['B-', 'B+', 'AB-', 'AB+'],
    'B+': ['B+', 'AB+'],
    'AB-': ['AB-', 'AB+'],
    'AB+': ['AB+'],
    'Oh': ['Oh', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
  };

  /// [recipientGroup] রক্তের গ্রুপের রোগীর জন্য কোন কোন গ্রুপের রক্তদাতার রক্ত নেওয়া সম্ভব।
  /// তালিকায় মূল রক্তের গ্রুপটি সবার প্রথমে থাকে।
  static List<String> compatibleDonorsFor(String recipientGroup) {
    return _compatibleDonors[recipientGroup] ?? [recipientGroup];
  }

  /// [donorGroup] রক্তদাতা কোন কোন গ্রুপের রোগীকে রক্ত দিতে পারবেন।
  static List<String> canDonateTo(String donorGroup) {
    return _canDonateTo[donorGroup] ?? [donorGroup];
  }

  /// [donorGroup] রক্তদাতা [recipientGroup] রোগীকে রক্ত দিতে পারবে কিনা।
  static bool isCompatible({required String donorGroup, required String recipientGroup}) {
    final compatible = _compatibleDonors[recipientGroup];
    if (compatible == null) return donorGroup == recipientGroup;
    return compatible.contains(donorGroup);
  }
}
