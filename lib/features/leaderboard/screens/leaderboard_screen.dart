import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../stats/providers/stats_provider.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaderboardProvider);
    final me = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Leaderboard'))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(leaderboardProvider),
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.leaderboard_outlined,
                        size: 80,
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('No one is on the leaderboard yet'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Finish an AI practice session to be the first!'),
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push(AppRoutes.aiTrainer),
                      child: Text(context.tr('Start practising')),
                    ),
                  ],
                ),
              ),
            );
          }

          final myIndex = entries.indexWhere((e) => e.userId == me?.id);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(leaderboardProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.festiveGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          myIndex >= 0
                              ? '${context.tr('Your rank')}: #${myIndex + 1}'
                              : context.tr('Practice with the AI Trainer to get ranked'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(entries.length, (i) {
                  return _Row(
                    rank: i + 1,
                    entry: entries[i],
                    isMe: entries[i].userId == me?.id,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;
  const _Row({required this.rank, required this.entry, required this.isMe});

  @override
  Widget build(BuildContext context) {
    Color? medal;
    if (rank == 1) medal = const Color(0xFFFFC107);
    if (rank == 2) medal = const Color(0xFFB0BEC5);
    if (rank == 3) medal = const Color(0xFFCD7F32);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isMe ? AppColors.primary.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isMe
            ? const BorderSide(color: AppColors.primary, width: 1.2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (medal ?? AppColors.primary).withValues(alpha: 0.18),
          child: medal != null
              ? Icon(Icons.emoji_events, color: medal)
              : Text('$rank',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        title: Text(
          isMe ? '${entry.name} (${context.tr('You')})' : entry.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${entry.sessions} ${context.tr('sessions')} • ${entry.avgAccuracy.toStringAsFixed(0)}% ${context.tr('avg accuracy')}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              entry.totalScore.toStringAsFixed(0),
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primary),
            ),
            Text(context.tr('points'),
                style: const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
