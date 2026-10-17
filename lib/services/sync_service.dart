import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../data/donor_repository.dart';

enum SyncStatus { idle, syncing, success, failed, noUrl }

class SyncResult {
  const SyncResult({
    required this.status,
    this.donorCount = 0,
    this.logCount = 0,
    this.errorMessage,
  });

  final SyncStatus status;
  final int donorCount;
  final int logCount;
  final String? errorMessage;

  bool get isSuccess => status == SyncStatus.success;

  const SyncResult.idle() : this(status: SyncStatus.idle);
  const SyncResult.noUrl() : this(status: SyncStatus.noUrl);
}

class SyncService {
  SyncService(this._repo);

  final DonorRepository _repo;

  /// একক বাই-ডাইরেকশনাল সিঙ্ক অপারেশন।
  /// Worker URL না থাকলে বা নেটওয়ার্ক ব্যর্থ হলে নিরাপদে ব্যর্থ হয়।
  Future<SyncResult> sync() async {
    final url = await _repo.getSetting(AppConstants.settingCloudUrl);
    if (url == null || url.trim().isEmpty) {
      return const SyncResult.noUrl();
    }

    final syncKey = await _repo.getSetting(AppConstants.settingSyncKey);
    final lastSyncedAt = await _repo.getSetting(AppConstants.settingLastSynced);

    try {
      // 1. সংগ্রহ করি স্থানীয় পরিবর্তন
      final localDonors = await _repo.getDonorsForSync(since: lastSyncedAt);
      final localLogs = await _repo.getLogsForSync(since: lastSyncedAt);
      final deletedPhones = await _repo.getDeletedPhonesForSync();

      // 2. পে-লোড তৈরি করুন
      final payload = <String, dynamic>{
        'last_synced_at': lastSyncedAt,
        'donors': localDonors,
        'logs': localLogs,
        'deleted_phones': deletedPhones,
      };

      // 3. Worker-এ পাঠান
      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (syncKey != null && syncKey.trim().isNotEmpty)
          'X-Sync-Key': syncKey.trim(),
      };

      final uri = Uri.parse('${url.trimRight().endsWith('/') ? url.substring(0, url.length - 1) : url}/api/sync');

      final response = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        return const SyncResult(
          status: SyncStatus.failed,
          errorMessage: 'Unauthorized (401): Sync Key সঠিক কিনা যাচাই করুন',
        );
      }

      if (response.statusCode != 200) {
        return SyncResult(
          status: SyncStatus.failed,
          errorMessage: 'Server error ${response.statusCode}',
        );
      }

      // 4. রিমোট থেকে পাওয়া পরিবর্তন প্রয়োগ করুন
      final Map<String, dynamic> body;
      try {
        body = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return const SyncResult(
          status: SyncStatus.failed,
          errorMessage: 'সার্ভার থেকে অবৈধ JSON পেয়েছি',
        );
      }

      final syncedAt = body['synced_at'] as String? ?? DateTime.now().toIso8601String();

      final remoteDonors = (body['donors'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final remoteLogs = (body['logs'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final remoteDeleted = (body['deleted_phones'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList();

      await _repo.applyRemoteSync(
        donors: remoteDonors,
        logs: remoteLogs,
        deletedPhones: remoteDeleted,
        syncedAt: syncedAt,
      );

      return SyncResult(
        status: SyncStatus.success,
        donorCount: remoteDonors.length,
        logCount: remoteLogs.length,
      );
    } on SocketException {
      return const SyncResult(
        status: SyncStatus.failed,
        errorMessage: 'ইন্টারনেট সংযোগ নেই বা সার্ভার পাওয়া যাচ্ছে না',
      );
    } on HttpException catch (e) {
      return SyncResult(
        status: SyncStatus.failed,
        errorMessage: 'HTTP ত্রুটি: ${e.message}',
      );
    } catch (e) {
      return SyncResult(
        status: SyncStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Health-check – Worker URL বৈধ কিনা যাচাই করে।
  Future<bool> testConnection(String url, {String? syncKey}) async {
    try {
      final uri = Uri.parse('${url.trimRight().endsWith('/') ? url.substring(0, url.length - 1) : url}/health');
      final headers = <String, String>{
        if (syncKey != null && syncKey.trim().isNotEmpty)
          'X-Sync-Key': syncKey.trim(),
      };
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSettings({required String url, String? syncKey}) async {
    await _repo.setSetting(AppConstants.settingCloudUrl, url.trim());
    if (syncKey != null && syncKey.trim().isNotEmpty) {
      await _repo.setSetting(AppConstants.settingSyncKey, syncKey.trim());
    } else {
      await _repo.deleteSetting(AppConstants.settingSyncKey);
    }
  }

  Future<void> clearSettings() async {
    await _repo.deleteSetting(AppConstants.settingCloudUrl);
    await _repo.deleteSetting(AppConstants.settingSyncKey);
    await _repo.deleteSetting(AppConstants.settingLastSynced);
  }

  Future<({String? url, String? syncKey, String? lastSynced})> loadSettings() async {
    final url = await _repo.getSetting(AppConstants.settingCloudUrl);
    final syncKey = await _repo.getSetting(AppConstants.settingSyncKey);
    final lastSynced = await _repo.getSetting(AppConstants.settingLastSynced);
    return (url: url, syncKey: syncKey, lastSynced: lastSynced);
  }
}
