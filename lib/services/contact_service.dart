import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/strings_bn.dart';

/// হোয়াটসঅ্যাপ, এসএমএস ও সোশ্যাল মিডিয়া পোস্ট সংক্রান্ত সাহায্যকারী সেবা।
class ContactService {
  ContactService._();

  /// বাংলাদেশের মোবাইল নম্বরকে WhatsApp আন্তর্জাতিক ফরম্যাটে (8801...) রূপান্তর করে।
  static String formatForWhatsApp(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) return digits;
    if (digits.startsWith('01')) return '88$digits';
    return digits;
  }

  /// ডোনারকে পাঠানোর জন্য মার্জিত বাংলা বার্তা।
  static String composeDonorMessage({
    required String donorName,
    required String bloodGroup,
    String? patientHospital,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('আসসালামু আলাইকুম/নমস্কার $donorName,');
    buffer.writeln('RedGrid থেকে জরুরি রক্তের প্রয়োজনে যোগাযোগ করছি। আপনার রক্তের গ্রুপ $bloodGroup।');
    if (patientHospital != null && patientHospital.trim().isNotEmpty) {
      buffer.writeln('হাসপাতাল / স্থান: ${patientHospital.trim()}');
    }
    buffer.writeln('আপনার কি বর্তমানে রক্ত দেওয়া সম্ভব হবে? দয়া করে জানালে উপকৃত হতাম। ধন্যবাদ!');
    return buffer.toString().trim();
  }

  /// সামাজিক যোগাযোগমাধ্যমে শেয়ার বা কপি করার মতো জরুরি রক্তের আবেদন ফরম্যাট।
  static String composeBroadcastPost({
    required String bloodGroup,
    required String units,
    required String hospital,
    required String when,
    String? reason,
    required String contactPhone,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(Strings.broadcastHeader);
    buffer.writeln('🩸 রক্তের গ্রুপ: $bloodGroup');
    if (units.trim().isNotEmpty) {
      buffer.writeln('💉 পরিমাণ: ${units.trim()}');
    }
    if (hospital.trim().isNotEmpty) {
      buffer.writeln('🏥 হাসপাতাল / স্থান: ${hospital.trim()}');
    }
    if (when.trim().isNotEmpty) {
      buffer.writeln('⏰ কখন প্রয়োজন: ${when.trim()}');
    }
    if (reason != null && reason.trim().isNotEmpty) {
      buffer.writeln('📋 কারণ: ${reason.trim()}');
    }
    buffer.writeln('📞 যোগাযোগের নম্বর: ${contactPhone.trim()}');
    buffer.writeln('');
    buffer.writeln(Strings.broadcastFooter);
    return buffer.toString().trim();
  }

  /// সরাসরি WhatsApp চ্যাট চালু করা। ব্যর্থ হলে মেসেজ ক্লিপবোর্ডে কপি করে false রিটার্ন করে।
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
  }) async {
    final waPhone = formatForWhatsApp(phone);
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$waPhone?text=$encoded');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: message));
        return false;
      }
      return true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      return false;
    }
  }

  /// সরাসরি মেসেজ (SMS) অ্যাপ চালু করা। ব্যর্থ হলে মেসেজ ক্লিপবোর্ডে কপি করে false রিটার্ন করে।
  static Future<bool> openSms({
    required String phone,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    try {
      final launched = await launchUrl(uri);
      if (!launched) {
        await Clipboard.setData(ClipboardData(text: message));
        return false;
      }
      return true;
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: message));
      return false;
    }
  }
}
