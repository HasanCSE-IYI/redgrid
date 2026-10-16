import 'digits.dart';

/// সব UI টেক্সট এক জায়গায় (বাংলা)।
class Strings {
  Strings._();

  static const appTitle = 'রেডগ্রিড';
  static const disclaimer =
      'এই অ্যাপ রক্তদাতা খুঁজে পেতে সাহায্য করে; চিকিৎসা সংক্রান্ত সিদ্ধান্ত হাসপাতালের।';

  static const searchHint = 'নাম বা ফোন নম্বর দিয়ে খুঁজুন';
  static const allGroups = 'সব';
  static const district = 'জেলা';
  static const area = 'এলাকা';
  static const allDistricts = 'সব জেলা';
  static const allAreas = 'সব এলাকা';
  static const eligibleOnly = 'শুধু রক্ত দিতে যোগ্য ডোনার';

  static const addDonor = 'ডোনার যোগ করুন';
  static const editDonor = 'ডোনারের তথ্য সম্পাদনা';
  static const name = 'নাম';
  static const gender = 'লিঙ্গ';
  static const male = 'পুরুষ';
  static const female = 'মহিলা';
  static const bloodGroup = 'রক্তের গ্রুপ';
  static const phone = 'ফোন নম্বর';
  static const lastDonation = 'সর্বশেষ রক্তদানের তারিখ';
  static const notSet = 'নির্ধারিত নয়';
  static const clear = 'মুছুন';
  static const pickDate = 'তারিখ বাছুন';
  static const notes = 'নোট (ঐচ্ছিক)';
  static const consent = 'ডোনার রক্তের প্রয়োজনে নম্বর শেয়ার করতে সম্মত';
  static const consentRequired = 'সম্মতি ছাড়া সংরক্ষণ করা যাবে না';
  static const required = 'এটি আবশ্যক';
  static const invalidPhone = 'সঠিক ১১ সংখ্যার মোবাইল নম্বর দিন';
  static const duplicatePhone = 'এই নম্বরে আগে থেকেই একজন ডোনার আছেন';
  static const save = 'সংরক্ষণ করুন';
  static const cancel = 'বাতিল';
  static const delete = 'মুছে ফেলুন';
  static const edit = 'সম্পাদনা';
  static const deleteTitle = 'ডোনার মুছে ফেলবেন?';
  static const deleteBody = 'ডোনার ও তার সব রক্তদানের লগ স্থায়ীভাবে মুছে যাবে।';
  static const genericError = 'কিছু একটা ভুল হয়েছে। আবার চেষ্টা করুন।';

  static const eligible = 'রক্ত দিতে যোগ্য';
  static const eligibleNoDate = 'যোগ্য (আগের দানের তারিখ নেই)';
  static String eligibleIn(Object days, String date) =>
      'আর ${toBanglaDigits(days)} দিন পরে যোগ্য ($date থেকে)';
  static String donationCount(String count) => 'মোট দান: $count';
  static const donatedToday = 'আজ রক্ত দিয়েছেন';
  static const alreadyLogged = 'এই তারিখের দান আগেই লগ করা আছে';
  static const donationSaved = 'রক্তদান লগ হয়েছে';
  static const undo = 'ফেরান';
  static const call = 'কল করুন';
  static const callFailed = 'কল করা যায়নি';
  static const copyPhone = 'ফোন নম্বর কপি';
  static const phoneCopied = 'ফোন নম্বর কপি করা হয়েছে';
  static const menu = 'আরও বিকল্প';

  static const emptyList = 'কোনো ডোনার পাওয়া যায়নি';
  static const emptyHint = 'নিচের বোতাম চেপে প্রথম ডোনার যোগ করুন, অথবা ফিল্টার বদলান।';
  static const errorLoad = 'তালিকা লোড করা যায়নি';
  static const retry = 'আবার চেষ্টা করুন';

  static const backup = 'ব্যাকআপ';
  static const restore = 'রিস্টোর';
  static const about = 'সম্পর্কে';
  static const aboutBody =
      'রেডগ্রিড ইন্টারনেট ছাড়াই রক্তদাতার তালিকা রাখে। সব তথ্য শুধু এই ফোনে থাকে।';
  static const backupWarning =
      'ব্যাকআপ ফাইল এনক্রিপ্টেড নয় এবং এতে সবার ফোন নম্বর আছে। ফাইলটি নিরাপদ রাখুন।';
  static const backupShareText = 'রেডগ্রিড ব্যাকআপ (এনক্রিপ্টেড নয়, নিরাপদ রাখুন)';
  static const continueLabel = 'এগিয়ে যান';
  static const restoreTitle = 'রিস্টোর নিশ্চিত করুন';
  static String restoreBody(String donors, String logs) =>
      'ফাইলে $donors জন ডোনার ও $logs টি রক্তদানের লগ আছে। বর্তমান সব তথ্য এগুলো দিয়ে প্রতিস্থাপিত হবে। '
      'আগে স্বয়ংক্রিয়ভাবে বর্তমান তথ্যের একটি কপি রাখা হবে।';
  static const restoreDone = 'রিস্টোর সম্পন্ন হয়েছে';
  static const restoreBadFile = 'ফাইলটি সঠিক রেডগ্রিড ব্যাকআপ নয়';
  static const restoreNewerVersion = 'ফাইলটি অ্যাপের নতুন সংস্করণের; অ্যাপ আপডেট করুন';
  static String restoreBadRow(String detail) => 'ব্যাকআপের তথ্যে ভুল আছে: $detail';

  static const errName = 'নাম আবশ্যক (সর্বোচ্চ ৮০ অক্ষর)';
  static const errBloodGroup = 'রক্তের গ্রুপ সঠিক নয়';
  static const errGender = 'লিঙ্গ সঠিক নয়';
  static const errPhone = 'ফোন নম্বর সঠিক নয়';
  static const errPlace = 'জেলা ও এলাকা আবশ্যক (সর্বোচ্চ ৬০ অক্ষর)';
  static const errConsent = 'সম্মতির মান সঠিক নয়';
  static const errDate = 'তারিখ সঠিক নয় বা ভবিষ্যতের';
  static const errTotal = 'মোট দানের সংখ্যা সঠিক নয়';
  static const errNotes = 'নোট খুব বড় (সর্বোচ্চ ৩০০ অক্ষর)';
}
