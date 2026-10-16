import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'data/donor.dart';
import 'data/donor_repository.dart';
import 'services/backup_service.dart';

/// main() এ খোলা ডেটাবেস দিয়ে override করা হয়।
final databaseProvider = Provider<Database>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final donorRepositoryProvider =
    Provider<DonorRepository>((ref) => DonorRepository(ref.watch(databaseProvider)));

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(databaseProvider)));

class FilterNotifier extends Notifier<DonorFilter> {
  @override
  DonorFilter build() => const DonorFilter();

  void setBloodGroup(String? value) => state = state.copyWith(
        bloodGroup: value,
        includeCompatible: value == null ? false : state.includeCompatible,
      );
  void setIncludeCompatible(bool value) => state = state.copyWith(includeCompatible: value);
  void setDistrict(String? value) => state = state.copyWith(district: value, area: null);
  void setArea(String? value) => state = state.copyWith(area: value);
  void setQuery(String value) => state = state.copyWith(query: value);
  void setEligibleOnly(bool value) => state = state.copyWith(eligibleOnly: value);
  void reset() => state = const DonorFilter();
}

final filterProvider = NotifierProvider<FilterNotifier, DonorFilter>(FilterNotifier.new);

class DonorListNotifier extends AsyncNotifier<List<Donor>> {
  DonorRepository get _repo => ref.read(donorRepositoryProvider);

  @override
  Future<List<Donor>> build() {
    final filter = ref.watch(filterProvider);
    return ref.watch(donorRepositoryProvider).search(filter);
  }

  Future<void> add(Donor donor) async {
    await _repo.insert(donor);
    ref.invalidateSelf();
  }

  Future<void> edit(Donor donor) async {
    await _repo.update(donor);
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await _repo.delete(id);
    ref.invalidateSelf();
  }

  Future<MarkDonatedResult> markDonated(int donorId, String date) async {
    final result = await _repo.markDonated(donorId, date);
    ref.invalidateSelf();
    return result;
  }

  Future<void> undo(int donorId, String date, String? previousLastDate) async {
    await _repo.undoDonation(donorId, date, previousLastDate);
    ref.invalidateSelf();
  }

  Future<void> deleteDonationDate(int donorId, String date) async {
    await _repo.deleteDonationDate(donorId, date);
    ref.invalidateSelf();
  }
}

final donorListProvider =
    AsyncNotifierProvider<DonorListNotifier, List<Donor>>(DonorListNotifier.new);

final donorStatsProvider = FutureProvider.autoDispose<DonorStats>((ref) async {
  ref.watch(donorListProvider);
  return ref.watch(donorRepositoryProvider).getStats();
});

final donationDatesProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, donorId) async {
  ref.watch(donorListProvider);
  return ref.watch(donorRepositoryProvider).getDonationDates(donorId);
});

