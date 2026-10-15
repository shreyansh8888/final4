import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/stats_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';

/// Bump this after a practice session is saved so every screen refreshes.
final practiceVersionProvider = StateProvider<int>((ref) => 0);

/// Real stats for the signed-in user (events booked, sessions, accuracy,
/// streak...) calculated from Firestore data.
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  ref.watch(practiceVersionProvider);
  final bookings = ref.watch(myBookingsProvider).valueOrNull ?? const [];
  if (user == null) return UserStats.empty();

  final records = await FirebaseService.instance.getPracticeRecords(user.id);
  final confirmed = bookings.where((b) => b.isConfirmed).length;
  return UserStats.fromRecords(records, confirmed);
});

final leaderboardProvider =
    FutureProvider.autoDispose<List<LeaderboardEntry>>((ref) async {
  ref.watch(practiceVersionProvider);
  ref.watch(currentUserProvider);
  return FirebaseService.instance.getLeaderboard();
});
