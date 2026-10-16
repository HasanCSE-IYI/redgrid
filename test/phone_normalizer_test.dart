import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/phone_normalizer.dart';

void main() {
  group('PhoneNormalizer.normalize', () {
    test('বাংলা অঙ্ক ও ড্যাশ', () {
      expect(PhoneNormalizer.normalize('০১৭১২-৩৪৫৬৭৮'), '01712345678');
    });
    test('+880 ও 880 উপসর্গ', () {
      expect(PhoneNormalizer.normalize('+8801712345678'), '01712345678');
      expect(PhoneNormalizer.normalize('8801712345678'), '01712345678');
    });
    test('স্পেস সহ নম্বর', () {
      expect(PhoneNormalizer.normalize('01712 345 678'), '01712345678');
    });
    test('ভুল নম্বর null', () {
      expect(PhoneNormalizer.normalize('1234'), isNull);
      expect(PhoneNormalizer.normalize('01212345678'), isNull);
      expect(PhoneNormalizer.normalize('017123456789'), isNull);
      expect(PhoneNormalizer.normalize(null), isNull);
    });
  });

  test('searchDigits আংশিক নম্বর', () {
    expect(PhoneNormalizer.searchDigits('০১৭১২'), '01712');
    expect(PhoneNormalizer.searchDigits('+8801712'), '01712');
  });
}
