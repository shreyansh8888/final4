// Practice records, aggregated user stats and leaderboard rows.
// Plain Dart (no code generation needed).

String gradeForAccuracy(double a) {
  if (a >= 95) return 'A+';
  if (a >= 90) return 'A';
  if (a >= 80) return 'B+';
  if (a >= 70) return 'B';
  if (a >= 60) return 'C';
  if (a >= 50) return 'D';
  return 'E';
}

/// One practised step inside one practice session (saved in Firestore
/// collection `practice_sessions`).
class PracticeRecord {
  final String id;
  final String sessionId;
  final String userId;
  final String stepName;
  final double accuracy; // 0-100
  final double score; // 0-100
  final String grade;
  final int durationSec;
  final List<String> mistakes;
  final List<String> suggestions;
  final DateTime createdAt;

  const PracticeRecord({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.stepName,
    required this.accuracy,
    required this.score,
    required this.grade,
    required this.durationSec,
    required this.mistakes,
    required this.suggestions,
    required this.createdAt,
  });

  /// Map for Firestore. `created_at` is added by the service as a Timestamp.
  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'user_id': userId,
        'step_name': stepName,
        'accuracy': accuracy,
        'score': score,
        'grade': grade,
        'duration_sec': durationSec,
        'mistakes': mistakes,
        'suggestions': suggestions,
      };

  factory PracticeRecord.fromMap(String docId, Map<String, dynamic> m) {
    List<String> strList(dynamic v) => v is List
        ? v.map((e) => e.toString()).toList()
        : <String>[];
    return PracticeRecord(
      id: docId,
      sessionId: (m['session_id'] ?? docId).toString(),
      userId: (m['user_id'] ?? '').toString(),
      stepName: (m['step_name'] ?? '').toString(),
      accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0,
      score: (m['score'] as num?)?.toDouble() ?? 0,
      grade: (m['grade'] ?? 'E').toString(),
      durationSec: (m['duration_sec'] as num?)?.toInt() ?? 0,
      mistakes: strList(m['mistakes']),
      suggestions: strList(m['suggestions']),
      createdAt:
          DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

/// Everything shown on the profile, reports, achievements screens.
class UserStats {
  final int eventsBooked;
  final int sessions; // distinct practice sessions
  final double bestAccuracy;
  final double avgAccuracy;
  final double totalScore;
  final int streakDays;
  final int bestStreak;
  final Map<String, double> bestByStep;
  final Map<String, double> avgByStep;
  final Map<String, int> countByStep;
  final List<PracticeRecord> records; // newest first

  const UserStats({
    required this.eventsBooked,
    required this.sessions,
    required this.bestAccuracy,
    required this.avgAccuracy,
    required this.totalScore,
    required this.streakDays,
    required this.bestStreak,
    required this.bestByStep,
    required this.avgByStep,
    required this.countByStep,
    required this.records,
  });

  factory UserStats.empty() => const UserStats(
        eventsBooked: 0,
        sessions: 0,
        bestAccuracy: 0,
        avgAccuracy: 0,
        totalScore: 0,
        streakDays: 0,
        bestStreak: 0,
        bestByStep: {},
        avgByStep: {},
        countByStep: {},
        records: [],
      );

  String get overallGrade => gradeForAccuracy(avgAccuracy);

  factory UserStats.fromRecords(List<PracticeRecord> input, int eventsBooked) {
    final records = List<PracticeRecord>.from(input)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final sessionIds = <String>{};
    final sums = <String, double>{};
    final counts = <String, int>{};
    final best = <String, double>{};
    double bestAcc = 0;
    double total = 0;
    double accSum = 0;
    final days = <DateTime>{};

    for (final r in records) {
      sessionIds.add(r.sessionId);
      sums[r.stepName] = (sums[r.stepName] ?? 0) + r.accuracy;
      counts[r.stepName] = (counts[r.stepName] ?? 0) + 1;
      if (r.accuracy > (best[r.stepName] ?? 0)) best[r.stepName] = r.accuracy;
      if (r.accuracy > bestAcc) bestAcc = r.accuracy;
      total += r.score;
      accSum += r.accuracy;
      days.add(DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day));
    }

    final avgByStep = <String, double>{};
    sums.forEach((k, v) => avgByStep[k] = v / (counts[k] ?? 1));

    // Current streak (consecutive days, ending today or yesterday).
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    var streak = 0;
    DateTime? cursor;
    if (days.contains(today)) {
      cursor = today;
    } else if (days.contains(yesterday)) {
      cursor = yesterday;
    }
    while (cursor != null && days.contains(cursor)) {
      streak++;
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }

    // Best streak ever.
    final sortedDays = days.toList()..sort();
    var bestStreak = 0;
    var run = 0;
    DateTime? prev;
    for (final d in sortedDays) {
      if (prev != null &&
          DateTime(prev.year, prev.month, prev.day + 1) == d) {
        run++;
      } else {
        run = 1;
      }
      if (run > bestStreak) bestStreak = run;
      prev = d;
    }

    return UserStats(
      eventsBooked: eventsBooked,
      sessions: sessionIds.length,
      bestAccuracy: bestAcc,
      avgAccuracy: records.isEmpty ? 0 : accSum / records.length,
      totalScore: total,
      streakDays: streak,
      bestStreak: bestStreak,
      bestByStep: best,
      avgByStep: avgByStep,
      countByStep: counts,
      records: records,
    );
  }
}

class LeaderboardEntry {
  final String userId;
  final String name;
  final double totalScore;
  final double bestAccuracy;
  final double avgAccuracy;
  final int sessions;
  final int streak;

  const LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.totalScore,
    required this.bestAccuracy,
    required this.avgAccuracy,
    required this.sessions,
    required this.streak,
  });

  factory LeaderboardEntry.fromMap(String id, Map<String, dynamic> m) =>
      LeaderboardEntry(
        userId: id,
        name: (m['name'] ?? 'Garba Dancer').toString(),
        totalScore: (m['total_score'] as num?)?.toDouble() ?? 0,
        bestAccuracy: (m['best_accuracy'] as num?)?.toDouble() ?? 0,
        avgAccuracy: (m['avg_accuracy'] as num?)?.toDouble() ?? 0,
        sessions: (m['sessions'] as num?)?.toInt() ?? 0,
        streak: (m['streak'] as num?)?.toInt() ?? 0,
      );
}
