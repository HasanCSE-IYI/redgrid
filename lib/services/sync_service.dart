import 'dart:async';
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

  /// URL নরম্যালাইজেশন (https:// নিশ্চিত করে এবং বাড়তি স্ল্যাশ বা পাথ দূর করে)
  static String normalizeUrl(String raw) {
    var url = raw.trim();
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.endsWith('/api/sync')) {
      url = url.substring(0, url.length - '/api/sync'.length);
    } else if (url.endsWith('/health')) {
      url = url.substring(0, url.length - '/health'.length);
    }
    return url;
  }

  /// একক বাই-ডাইরেকশনাল সিঙ্ক অপারেশন।
  /// ডিফল্টরূপে বিল্ট-ইন সার্ভার ব্যবহার করে; কাস্টম URL সেট থাকলে তা অগ্রাধিকার পায়।
  Future<SyncResult> sync() async {
    final customUrl = await _repo.getSetting(AppConstants.settingCloudUrl);
    final effectiveUrl = (customUrl != null && customUrl.trim().isNotEmpty)
        ? customUrl.trim()
        : AppConstants.defaultCloudUrl;

    if (effectiveUrl.isEmpty) {
      return const SyncResult.noUrl();
    }
    final url = normalizeUrl(effectiveUrl);

    final customKey = await _repo.getSetting(AppConstants.settingSyncKey);
    final syncKey = (customKey != null && customKey.trim().isNotEmpty)
        ? customKey.trim()
        : (effectiveUrl == AppConstants.defaultCloudUrl ? AppConstants.defaultSyncKey : null);

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
        'X-RedGrid-App': AppConstants.appAgentHeader,
        if (syncKey != null && syncKey.trim().isNotEmpty)
          'X-Sync-Key': syncKey.trim(),
      };

      final uri = Uri.parse('$url/api/sync');

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
    } on SocketException catch (e) {
      return SyncResult(
        status: SyncStatus.failed,
        errorMessage: 'ইন্টারনেট সংযোগ নেই বা সার্ভার পাওয়া যাচ্ছে না (${e.message})',
      );
    } on TimeoutException {
      return const SyncResult(
        status: SyncStatus.failed,
        errorMessage: 'সার্ভার রেসপন্স করতে অতিরিক্ত সময় নিচ্ছে (Timeout)',
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

  /// Health-check – বিস্তারিত ফলাফলসহ Worker URL পরীক্ষা করে।
  Future<({bool success, String? error})> testConnectionDetails(String rawUrl, {String? syncKey}) async {
    try {
      final effectiveUrl = rawUrl.trim().isEmpty ? AppConstants.defaultCloudUrl : rawUrl;
      final url = normalizeUrl(effectiveUrl);
      if (url.isEmpty) {
        return (success: false, error: 'URL প্রদান করুন');
      }
      final uri = Uri.parse('$url/health');
      final effectiveKey = (syncKey != null && syncKey.trim().isNotEmpty)
          ? syncKey.trim()
          : (effectiveUrl == AppConstants.defaultCloudUrl ? AppConstants.defaultSyncKey : null);
      final headers = <String, String>{
        'X-RedGrid-App': AppConstants.appAgentHeader,
        if (effectiveKey != null && effectiveKey.isNotEmpty)
          'X-Sync-Key': effectiveKey,
      };
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return (success: true, error: null);
      }
      if (response.statusCode == 401) {
        return (success: false, error: 'Unauthorized (401): Sync Key ভুল');
      }
      return (success: false, error: 'সার্ভার রেসপন্স কোড: ${response.statusCode}');
    } on SocketException catch (e) {
      return (success: false, error: 'সার্ভার সংযোগ ব্যর্থ (${e.message})');
    } on TimeoutException {
      return (success: false, error: 'টাইমআউট (১০ সেকেন্ডে রেসপন্স আসেনি)');
    } on HttpException catch (e) {
      return (success: false, error: 'HTTP ত্রুটি: ${e.message}');
    } catch (e) {
      return (success: false, error: e.toString());
    }
  }

  /// Health-check – Worker URL বৈধ কিনা যাচাই করে।
  Future<bool> testConnection(String url, {String? syncKey}) async {
    final result = await testConnectionDetails(url, syncKey: syncKey);
    return result.success;
  }

  Future<void> saveSettings({required String url, String? syncKey}) async {
    final cleanUrl = normalizeUrl(url);
    if (cleanUrl == normalizeUrl(AppConstants.defaultCloudUrl)) {
      // ডিফল্ট সার্ভার ব্যবহার করলে ওভাররাইড মুছে ফেলা হয়
      await _repo.deleteSetting(AppConstants.settingCloudUrl);
    } else {
      await _repo.setSetting(AppConstants.settingCloudUrl, cleanUrl);
    }
    if (syncKey != null && syncKey.trim().isNotEmpty) {
      await _repo.setSetting(AppConstants.settingSyncKey, syncKey.trim());
    } else {
      await _repo.deleteSetting(AppConstants.settingSyncKey);
    }
  }

  Future<void> resetToDefault() async {
    await _repo.deleteSetting(AppConstants.settingCloudUrl);
    await _repo.deleteSetting(AppConstants.settingSyncKey);
  }

  Future<void> clearSettings() async {
    await resetToDefault();
    await _repo.deleteSetting(AppConstants.settingLastSynced);
  }

  Future<({String url, String? syncKey, String? lastSynced, bool isCustom})> loadSettings() async {
    final customUrl = await _repo.getSetting(AppConstants.settingCloudUrl);
    final isCustom = customUrl != null && customUrl.trim().isNotEmpty;
    final url = isCustom ? customUrl : AppConstants.defaultCloudUrl;
    final syncKey = await _repo.getSetting(AppConstants.settingSyncKey);
    final lastSynced = await _repo.getSetting(AppConstants.settingLastSynced);
    return (url: url, syncKey: syncKey, lastSynced: lastSynced, isCustom: isCustom);
  }
}
