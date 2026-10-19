import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/strings_bn.dart';
import 'package:redgrid/services/contact_service.dart';

void main() {
  group('About & Developer Constants', () {
    test('contains correct developer attribution', () {
      expect(Strings.developedBy, 'Developed by Bhuiyan Ghazi');
    });

    test('contains correct phone number and initiative support', () {
      expect(Strings.devPhone, '01727328200');
      expect(Strings.sadaqahSupportTitle, 'জীবনরক্ষাকারী উদ্যোগে সহায়তা ও অনুদান');
      expect(Strings.sadaqahSupportDesc, contains('সহায়তা'));
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
