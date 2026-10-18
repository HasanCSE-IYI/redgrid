import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/strings_bn.dart';
import 'package:redgrid/services/contact_service.dart';

void main() {
  group('About & Developer Constants', () {
    test('contains correct developer attribution', () {
      expect(Strings.developedBy, 'Developed by Bhuiyan Ghazi');
    });

    test('contains correct phone number and Sadaqah Jariyah support', () {
      expect(Strings.devPhone, '+8801727328200');
      expect(Strings.sadaqahSupportTitle, 'সাদাকায়ে জারিয়া হিসেবে সাপোর্ট');
      expect(Strings.sadaqahSupportDesc, contains('সাদাকায়ে জারিয়া'));
    });

    test('dev phone formats correctly for WhatsApp international URL', () {
      final wa = ContactService.formatForWhatsApp(Strings.devPhone);
      expect(wa, '8801727328200');
    });

    test('supported channels include WhatsApp, bKash, Nagad, and CellFin', () {
      expect(Strings.supportedChannels, contains('WhatsApp'));
      expect(Strings.supportedChannels, contains('বিকাশ'));
      expect(Strings.supportedChannels, contains('নগদ'));
      expect(Strings.supportedChannels, contains('সেলফিন'));
    });
  });
}
