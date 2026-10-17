import 'package:flutter_test/flutter_test.dart';
import 'package:redgrid/core/constants.dart';
import 'package:redgrid/services/sync_service.dart';

void main() {
  group('SyncService.normalizeUrl', () {
    test('adds https:// if missing', () {
      expect(
        SyncService.normalizeUrl('redgrid-sync.rauaha.workers.dev'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });

    test('preserves existing https://', () {
      expect(
        SyncService.normalizeUrl('https://redgrid-sync.rauaha.workers.dev'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });

    test('removes trailing slashes', () {
      expect(
        SyncService.normalizeUrl('https://redgrid-sync.rauaha.workers.dev/'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
      expect(
        SyncService.normalizeUrl('https://redgrid-sync.rauaha.workers.dev///'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });

    test('removes accidental /api/sync or /health suffixes', () {
      expect(
        SyncService.normalizeUrl('https://redgrid-sync.rauaha.workers.dev/api/sync'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
      expect(
        SyncService.normalizeUrl('https://redgrid-sync.rauaha.workers.dev/health'),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });

    test('trims whitespace', () {
      expect(
        SyncService.normalizeUrl('  https://redgrid-sync.rauaha.workers.dev/  '),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });

    test('handles empty string safely', () {
      expect(SyncService.normalizeUrl(''), '');
    });

    test('normalizes AppConstants.defaultCloudUrl correctly', () {
      expect(
        SyncService.normalizeUrl(AppConstants.defaultCloudUrl),
        'https://redgrid-sync.rauaha.workers.dev',
      );
    });
  });
}
