import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/models/stats_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../stats/providers/stats_provider.dart';

/// Real performance reports built from the practice sessions saved in
/// Firestore by the AI Trainer.
class PerformanceReportsScreen extends ConsumerWidget {
  const PerformanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Performance Reports'))),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.invalidate(userStatsProvider),
                  child: Text(context.tr('Retry')),
                ),
              ],
            ),
          ),
        ),
        data: (stats) {
          if (stats.records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_outlined,
                        size: 80,
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('No practice sessions yet'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.tr('Your reports appear here after you practise with the AI Trainer.'),
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
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userStatsProvider),
            child: _Body(stats: stats),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final UserStats stats;
  const _Body({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Oldest -> newest for the chart (max 20 points).
    final chrono = stats.records.reversed.toList();
    final chartData =
        chrono.length > 20 ? chrono.sublist(chrono.length - 20) : chrono;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.festiveGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(context.tr('Overall Performance'),
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text('${stats.avgAccuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold)),
              Text('${context.tr('Grade')}: ${stats.overallGrade}',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _Mini(context.tr('Sessions'), '${stats.sessions}'),
                  _Mini(context.tr('Best'),
                      '${stats.bestAccuracy.toStringAsFixed(0)}%'),
                  _Mini(context.tr('Streak'), '${stats.streakDays}🔥'),
                  _Mini(context.tr('Points'),
                      stats.totalScore.toStringAsFixed(0)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (chartData.length >= 2) ...[
          Text(context.tr('Accuracy Trend'),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < chartData.length; i++)
                        FlSpot(i.toDouble(), chartData[i].accuracy),
                    ],
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withValues(alpha: 0.15)),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(context.tr('Performance by Step'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...AppConstants.garbaSteps.map((step) {
          final count = stats.countByStep[step] ?? 0;
          final avg = stats.avgByStep[step] ?? 0;
          final best = stats.bestByStep[step] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(context.tr(step),
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(
                      count == 0
                          ? context.tr('Not practised yet')
                          : '${avg.toStringAsFixed(0)}%  •  ${context.tr('Best')} ${best.toStringAsFixed(0)}%  •  ${count}x',
                      style: TextStyle(
                          color: count == 0 ? Colors.grey : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: (avg / 100).clamp(0.0, 1.0),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    avg >= 90
                        ? AppColors.success
                        : avg >= 75
                            ? AppColors.warning
                            : AppColors.error,
                  ),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Text(context.tr('Session History'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...stats.records.take(30).map((r) => _RecordTile(record: r)),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  final String label;
  final String value;
  const _Mini(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      );
}

class _RecordTile extends StatelessWidget {
  final PracticeRecord record;
  const _RecordTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final color = r.accuracy >= 90
        ? AppColors.success
        : r.accuracy >= 75
            ? AppColors.warning
            : AppColors.error;
    final d = r.createdAt;
    final date =
        '${d.day}/${d.month}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showDetails(context),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(r.grade,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        title: Text(context.tr(r.stepName),
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$date  •  ${r.durationSec}s',
            style: const TextStyle(fontSize: 12)),
        trailing: Text('${r.accuracy.toStringAsFixed(0)}%',
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    final r = record;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(r.stepName),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                '${context.tr('Accuracy')}: ${r.accuracy.toStringAsFixed(0)}%  •  ${context.tr('Grade')}: ${r.grade}  •  ${context.tr('Points')}: ${r.score.toStringAsFixed(0)}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text(context.tr('Corrections Needed'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.error)),
              const SizedBox(height: 6),
              if (r.mistakes.isEmpty)
                Text(context.tr('No major mistakes. Great job!'))
              else
                ...r.mistakes.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${context.tr(m)}'),
                    )),
              if (r.suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(context.tr('Tips'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success)),
                const SizedBox(height: 6),
                ...r.suggestions.map((m) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• ${context.tr(m)}'),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
