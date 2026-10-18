import 'digits.dart';

/// সব UI টেক্সট এক জায়গায় (বাংলা)।
class Strings {
  Strings._();

  static const appTitle = 'RedGrid';
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
  static const donorDeleted = 'ডোনার মুছে ফেলা হয়েছে';
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

  // সামঞ্জস্যপূর্ণ রক্তের গ্রুপ (Compatibility)
  static const includeCompatible = 'সামঞ্জস্যপূর্ণ গ্রুপ সহ';
  static const compatibleBadge = 'সামঞ্জস্যপূর্ণ';
  static String compatibleInfo(String recipient, List<String> groups) =>
      '$recipient গ্রুপের জন্য গ্রহণযোগ্য: ${groups.join(', ')}';

  // সরাসরি যোগাযোগ (WhatsApp & SMS)
  static const whatsapp = 'হোয়াটসঅ্যাপ';
  static const sms = 'মেসেজ';
  static const whatsappFailed = 'হোয়াটসঅ্যাপ চালু করা যায়নি। বার্তাটি কপি করা হয়েছে।';
  static const smsFailed = 'মেসেজ অ্যাপ চালু করা যায়নি। বার্তাটি কপি করা হয়েছে।';
  static const messageCopied = 'বার্তা ক্লিপবোর্ডে কপি করা হয়েছে';

  // জরুরি রক্তের আবেদন (Emergency Request & Social Broadcast)
  static const emergencyRequest = 'জরুরি রক্তের আবেদন';
  static const emergencyTitle = 'জরুরি রক্তের আবেদন তৈরি করুন';
  static const patientHospital = 'হাসপাতাল / স্থান';
  static const hospitalHint = 'যেমন: ঢাকা মেডিকেল কলেজ হাসপাতাল';
  static const unitsNeeded = 'রক্তের পরিমাণ';
  static const unitsHint = 'যেমন: ১ ব্যাগ';
  static const whenNeeded = 'কখন প্রয়োজন';
  static const whenHint = 'যেমন: আজ সন্ধ্যা ৬টায় / জরুরি';
  static const reason = 'রোগীর সমস্যা / কারণ (ঐচ্ছিক)';
  static const reasonHint = 'যেমন: সিজারিয়ান / দুর্ঘটনা / থ্যালাসেমিয়া';
  static const contactPhone = 'যোগাযোগের ফোন নম্বর';
  static const sharePost = 'পোস্ট শেয়ার';
  static const copyPost = 'পোস্ট কপি';
  static const findEligibleDonors = 'ডোনার খুঁজুন';
  static const postCopied = 'আবেদনের লেখা কপি করা হয়েছে';
  static const broadcastHeader = '🚨 #জরুরি_রক্তের_প্রয়োজন 🚨';
  static const broadcastFooter = '(RedGrid - লাইফসেভার অফলাইন ডিরেক্টরি)';
  static const emergencyBannerTitle = 'জরুরি রক্তের প্রয়োজন?';
  static const emergencyBannerSub = 'সোশ্যাল মিডিয়ার জন্য দ্রুত পোস্ট তৈরি ও শেয়ার করুন';
  static const createPostAction = 'পোস্ট তৈরি';
  static const callWaiting = 'কল (অপেক্ষমান)';
  static const offlineReady = '১০০% অফলাইন';
  static const livesSavedEstimate = 'জীবন রক্ষায় ভূমিকা';
  static const livesImpactText = 'জন মানুষের জীবন বাঁচাতে সহায়তা করেছেন';
  static const clearFilter = 'ফিল্টার মুছুন';
  static const viewDetailed = 'বিস্তারিত ভিউ';
  static const viewCompact = 'কমপ্যাক্ট ভিউ';
  static String donorsFound(Object count) => '$count জন ডোনার পাওয়া গেছে';

  // হোম ড্যাশবোর্ড পরিসংখ্যান (Summary Stats)
  static const totalDonors = 'মোট ডোনার';
  static const readyDonors = 'প্রস্তুত আজ';
  static const totalDonations = 'মোট রক্তদান';
  static const countUnit = 'জন';
  static const timesUnit = 'বার';

  // ডোনার প্রোফাইল ও ইতিহাস (Profile & Timeline)
  static const donorDetails = 'ডোনারের ইতিহাস';
  static const donationHistory = 'রক্তদানের ইতিহাস';
  static const noHistory = 'এখনো কোনো রক্তদানের তারিখ রেকর্ড নেই';
  static const addDonationDate = 'নতুন রক্তদানের তারিখ যোগ';
  static const deleteLogConfirmTitle = 'এই তারিখের রেকর্ড মুছবেন?';
  static const deleteLogConfirmBody =
      'এই রক্তদানের লগটি মুছে ফেলা হবে এবং ডোনারের মোট দানের হিসাব হালনাগাদ হবে।';
  static const logDeleted = 'রক্তদানের রেকর্ড মুছে ফেলা হয়েছে';

  static const emptyList = 'কোনো ডোনার পাওয়া যায়নি';
  static const emptyHint = 'নিচের বোতাম চেপে প্রথম ডোনার যোগ করুন, অথবা ফিল্টার বদলান।';
  static const findCompatibleAction = 'সামঞ্জস্যপূর্ণ ডোনার খুঁজুন';
  static const createEmergencyPost = 'জরুরি রক্তের আবেদন তৈরি করুন';
  static const resetFilters = 'ফিল্টার রিসেট করুন';
  static const callNow = 'কল করুন';
  static const readyToDonate = 'রক্তদানে প্রস্তুত';
  static const errorLoad = 'তালিকা লোড করা যায়নি';
  static const retry = 'আবার চেষ্টা করুন';

  static const backup = 'ব্যাকআপ';
  static const restore = 'রিস্টোর';
  static const about = 'সম্পর্কে';
  static const developedBy = 'Developed by Bhuiyan Ghazi';
  static const devPhone = '+8801727328200';
  static const devWhatsappMessage =
      'আসসালামু আলাইকুম, RedGrid প্রজেক্টে সাদাকায়ে জারিয়া সহায়তা প্রসঙ্গে যোগাযোগ করছি।';
  static const sadaqahSupportTitle = 'সাদাকায়ে জারিয়া হিসেবে সাপোর্ট';
  static const sadaqahSupportDesc =
      'জরুরি মুহূর্তে রক্ত সন্ধান সহজ করে মানুষের জীবন বাঁচাতে এই প্রজেক্টটি বিনামূল্যে উন্মুক্ত রাখা হয়েছে। এর উন্নয়ন ও ধারাবাহিক সার্বিক সহায়তায় আপনিও সাদাকায়ে জারিয়া হিসেবে পাশে থাকতে পারেন।';
  static const supportedChannels = 'WhatsApp • বিকাশ • নগদ • সেলফিন';
  static const copyNumber = 'নম্বর কপি';
  static const numberCopied = 'নম্বর কপি করা হয়েছে: +8801727328200';
  static const backupWarning =
      'ব্যাকআপ ফাইল এনক্রিপ্টেড নয় এবং এতে সবার ফোন নম্বর আছে। ফাইলটি নিরাপদ রাখুন।';
  static const backupShareText = 'RedGrid ব্যাকআপ (এনক্রিপ্টেড নয়, নিরাপদ রাখুন)';
  static const continueLabel = 'এগিয়ে যান';
  static const restoreTitle = 'রিস্টোর নিশ্চিত করুন';
  static String restoreBody(String donors, String logs) =>
      'ফাইলে $donors জন ডোনার ও $logs টি রক্তদানের লগ আছে। বর্তমান সব তথ্য এগুলো দিয়ে প্রতিস্থাপিত হবে। '
      'আগে স্বয়ংক্রিয়ভাবে বর্তমান তথ্যের একটি কপি রাখা হবে।';
  static const restoreDone = 'রিস্টোর সম্পন্ন হয়েছে';
  static const restoreBadFile = 'ফাইলটি সঠিক RedGrid ব্যাকআপ নয়';
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

  // ক্লাউড সিঙ্ক (Cloud Sync)
  static const cloudSync = 'ক্লাউড সিঙ্ক';
  static const cloudSyncTitle = 'ক্লাউড সিঙ্ক সেটিংস';
  static const cloudSyncUrl = 'Worker URL';
  static const cloudSyncUrlHint = 'https://your-worker.workers.dev';
  static const cloudSyncKey = 'Sync Key (ঐচ্ছিক)';
  static const cloudSyncKeyHint = 'গোপন পাসওয়ার্ড (না থাকলে ফাঁকা রাখুন)';
  static const cloudSyncSave = 'সংরক্ষণ ও সিঙ্ক করুন';
  static const cloudSyncTest = 'পরীক্ষা করুন';
  static const cloudSyncClear = 'সিঙ্ক সংযোগ বাতিল';
  static const cloudSyncing = 'সিঙ্ক হচ্ছে…';
  static const cloudSyncDone = 'সিঙ্ক সম্পন্ন হয়েছে';
  static const cloudSyncFailed = 'সিঙ্ক ব্যর্থ হয়েছে';
  static const cloudSyncNoUrl = 'Worker URL সেট করা নেই। সিঙ্ক বাটনে ট্যাপ করে সেট করুন।';
  static const cloudSyncOffline = 'ইন্টারনেট সংযোগ নেই';
  static String cloudSyncSuccess(int donors, int logs) =>
      'সিঙ্ক সম্পন্ন: $donors জন ডোনার, $logs টি লগ আপডেট হয়েছে';
  static String cloudSyncError(String msg) => 'সিঙ্ক ত্রুটি: $msg';
  static const cloudSyncLastSynced = 'শেষ সিঙ্ক';
  static const cloudSyncNeverSynced = 'এখনো সিঙ্ক হয়নি';
  static const cloudSyncConnected = 'ক্লাউড সংযুক্ত';
  static const cloudSyncUrlRequired = 'Worker URL আবশ্যক';
  static const cloudSyncBuiltIn = 'বিল্ট-ইন ক্লাউড ব্যাকএন্ড (সক্রিয়)';
  static const cloudSyncCustom = 'কাস্টম সার্ভার ব্যবহার হচ্ছে';
  static const cloudSyncSyncNow = 'এখনই সিঙ্ক করুন';
  static const cloudSyncResetDefault = 'ডিফল্ট সার্ভারে ফেরত যান';
  static const cloudSyncResetDone = 'ডিফল্ট সার্ভার পুনঃস্থাপিত হয়েছে';
  static const cloudSyncAdvancedSettings = 'উন্নত সার্ভার সেটিংস (ঐচ্ছিক)';
  static const cloudSyncBuiltInDesc = 'RedGrid এর সুরক্ষিত বিল্ট-ইন সার্ভারের মাধ্যমে ডেটা অটোমেটিক সিঙ্ক হচ্ছে।';

  // নোটিফিকেশন ও অ্যালার্ট (Notifications & Alerts)
  static const notifications = 'বিজ্ঞপ্তি ও অ্যালার্ট';
  static const noNotifications = 'কোনো নতুন বিজ্ঞপ্তি নেই';
  static const noNotificationsDesc =
      'রক্তদানে প্রস্তুত হওয়া ডোনার এবং ক্লাউড সিঙ্কের স্বয়ংক্রিয় অ্যালার্ট এখানে প্রদর্শিত হবে।';
  static const markAllAsRead = 'সব পঠিত';
  static const clearAll = 'সব মুছুন';
  static const filterAll = 'সব';
  static const filterReady = 'রক্তদানে প্রস্তুত';
  static const filterSync = 'সিঙ্ক ও সিস্টেম';
  static const readyToDonateTitle = 'রক্তদানে প্রস্তুত ডোনার';
  static const callAction = 'কল';
  static const whatsappAction = 'WhatsApp';
  static const profileAction = 'প্রোফাইল';
  static const viewDetails = 'বিস্তারিত দেখুন';
  static const newNotificationToast = 'নতুন বিজ্ঞপ্তি';
}
