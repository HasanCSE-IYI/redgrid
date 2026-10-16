import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/date_format.dart';
import 'package:redgrid/core/digits.dart';
import 'package:redgrid/core/strings_bn.dart';

void main() {
  group('Digits', () {
    test('toAsciiDigits converts বাংলা to ইংরেজি', () {
      expect(toAsciiDigits('০১২৩৪৫৬৭৮৯'), '0123456789');
      expect(toAsciiDigits('নম্বর: ০১৭১২-৩৪৫৬৭৮'), 'নম্বর: 01712-345678');
    });

    test('toBanglaDigits converts ইংরেজি to বাংলা', () {
      expect(toBanglaDigits('0123456789'), '০১২৩৪৫৬৭৮৯');
      expect(toBanglaDigits(42), '৪২');
    });
  });

  group('DateFormat', () {
    test('isoDate formats YYYY-MM-DD with zero-padding', () {
      expect(isoDate(DateTime.utc(2026, 5, 4)), '2026-05-04');
    });

    test('parseIsoDate parses valid dates', () {
      final d = parseIsoDate('2026-10-16');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 10);
      expect(d.day, 16);
    });

    test('parseIsoDate rejects invalid and non-existent dates', () {
      expect(parseIsoDate(null), isNull);
      expect(parseIsoDate(''), isNull);
      expect(parseIsoDate('2026-13-01'), isNull);
      expect(parseIsoDate('2026-02-31'), isNull);
      expect(parseIsoDate('invalid'), isNull);
    });

    test('formatDateBn outputs Bengali digits', () {
      expect(formatDateBn(DateTime.utc(2026, 10, 16)), '১৬/১০/২০২৬');
    });

    test('formatIsoDateBn outputs Bengali digits from ISO string', () {
      expect(formatIsoDateBn('2026-10-16'), '১৬/১০/২০২৬');
      expect(formatIsoDateBn('invalid-date'), 'invalid-date');
    });

    test('Strings.eligibleIn uses Bengali digits', () {
      expect(Strings.eligibleIn(45, '১৬/১০/২০২৬'), 'আর ৪৫ দিন পরে যোগ্য (১৬/১০/২০২৬ থেকে)');
    });
  });
}
