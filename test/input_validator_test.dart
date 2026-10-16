import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/input_validator.dart';

Map<String, Object?> _valid() => {
      'name': 'রহিম উদ্দিন',
      'blood_group': 'A+',
      'gender': 'MALE',
      'phone': '01712345678',
      'consent_to_share': 1,
      'district': 'ঢাকা',
      'area': 'উত্তরা',
      'last_donation_date': '2026-01-10',
      'total_donations': 2,
      'notes': null,
    };

void main() {
  final now = DateTime.utc(2026, 10, 16);

  test('সঠিক তথ্য পাস করে', () {
    expect(InputValidator.validateDonorMap(_valid(), now: now), isNull);
  });

  test('ভুল গ্রুপ, লিঙ্গ, ফোন', () {
    expect(InputValidator.validateDonorMap({..._valid(), 'blood_group': 'C+'}, now: now), isNotNull);
    expect(InputValidator.validateDonorMap({..._valid(), 'gender': 'X'}, now: now), isNotNull);
    expect(InputValidator.validateDonorMap({..._valid(), 'phone': '123'}, now: now), isNotNull);
  });

  test('ভবিষ্যতের ও অসম্ভব তারিখ বাদ', () {
    expect(InputValidator.validateDonorMap({..._valid(), 'last_donation_date': '2026-12-01'}, now: now),
        isNotNull);
    expect(InputValidator.validateDonorMap({..._valid(), 'last_donation_date': '2026-02-31'}, now: now),
        isNotNull);
  });

  test('সম্মতি ও মোট সংখ্যা', () {
    expect(InputValidator.validateDonorMap({..._valid(), 'consent_to_share': 2}, now: now), isNotNull);
    expect(InputValidator.validateDonorMap({..._valid(), 'total_donations': -1}, now: now), isNotNull);
  });

  test('খালি নাম ও দীর্ঘ নোট', () {
    expect(InputValidator.validateDonorMap({..._valid(), 'name': '  '}, now: now), isNotNull);
    expect(InputValidator.validateDonorMap({..._valid(), 'notes': 'ক' * 301}, now: now), isNotNull);
  });
}
