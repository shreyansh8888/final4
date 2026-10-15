import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/stats_model.dart';

/// One badge. All text is an English key translated at display time.
class Achievement {
  final String id;
  final IconData icon;
  final String title;
  final String description;
  final double current;
  final double target;

  const Achievement({
    required this.id,
    required this.icon,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
  });

  bool get unlocked => current >= target;
  double get progress => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0);
}

/// Badges are calculated from the user's real stats, nothing is hard-coded.
List<Achievement> evaluateAchievements(UserStats s) {
  final practicedSteps =
      AppConstants.garbaSteps.where((st) => (s.countByStep[st] ?? 0) > 0).length;
  final masteredSteps = AppConstants.garbaSteps
      .where((st) =>
          (s.countByStep[st] ?? 0) >= 3 && (s.avgByStep[st] ?? 0) >= 85)
      .length;

  return [
    Achievement(
      id: 'first_booking',
      icon: Icons.confirmation_number_rounded,
      title: 'First Ticket',
      description: 'Book your first Garba event',
      current: s.eventsBooked.toDouble(),
      target: 1,
    ),
    Achievement(
      id: 'festival_regular',
      icon: Icons.celebration_rounded,
      title: 'Festival Regular',
      description: 'Book 3 events',
      current: s.eventsBooked.toDouble(),
      target: 3,
    ),
    Achievement(
      id: 'first_practice',
      icon: Icons.play_circle_fill_rounded,
      title: 'First Steps',
      description: 'Finish your first AI practice session',
      current: s.sessions.toDouble(),
      target: 1,
    ),
    Achievement(
      id: 'dedicated',
      icon: Icons.fitness_center_rounded,
      title: 'Dedicated Dancer',
      description: 'Finish 10 practice sessions',
      current: s.sessions.toDouble(),
      target: 10,
    ),
    Achievement(
      id: 'veteran',
      icon: Icons.military_tech_rounded,
      title: 'Garba Veteran',
      description: 'Finish 50 practice sessions',
      current: s.sessions.toDouble(),
      target: 50,
    ),
    Achievement(
      id: 'sharp',
      icon: Icons.bolt_rounded,
      title: 'Sharp Moves',
      description: 'Reach 80% accuracy in a session',
      current: s.bestAccuracy,
      target: 80,
    ),
    Achievement(
      id: 'perfectionist',
      icon: Icons.stars_rounded,
      title: 'Perfectionist',
      description: 'Reach 95% accuracy in a session',
      current: s.bestAccuracy,
      target: 95,
    ),
    Achievement(
      id: 'streak3',
      icon: Icons.local_fire_department_rounded,
      title: 'On Fire',
      description: 'Practice 3 days in a row',
      current: s.bestStreak.toDouble(),
      target: 3,
    ),
    Achievement(
      id: 'streak7',
      icon: Icons.whatshot_rounded,
      title: 'Week Warrior',
      description: 'Practice 7 days in a row',
      current: s.bestStreak.toDouble(),
      target: 7,
    ),
    Achievement(
      id: 'allrounder',
      icon: Icons.interests_rounded,
      title: 'All-Rounder',
      description: 'Practice all 6 Garba steps',
      current: practicedSteps.toDouble(),
      target: AppConstants.garbaSteps.length.toDouble(),
    ),
    Achievement(
      id: 'step_master',
      icon: Icons.emoji_events_rounded,
      title: 'Step Master',
      description: 'Average 85% on any step (3+ sessions)',
      current: masteredSteps.toDouble(),
      target: 1,
    ),
  ];
}
