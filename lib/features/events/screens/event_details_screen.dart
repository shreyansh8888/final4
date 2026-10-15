import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/events_provider.dart';

class EventDetailsScreen extends ConsumerWidget {
  final String eventId;
  const EventDetailsScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailProvider(eventId));
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: eventAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (event) => CustomScrollView(
          slivers: [
            // Hero image app bar
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(event.title,
                    style: const TextStyle(
                        shadows: [Shadow(blurRadius: 4)])),
                background: event.image != null
                    ? CachedNetworkImage(
                        imageUrl: event.image!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.festiveGradient,
                        ),
                        child: const Center(
                          child: Icon(Icons.music_note_rounded,
                              size: 80, color: Colors.white38),
                        ),
                      ),
              ),
              actions: [
                if (user?.isAdmin == true)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    tooltip: context.tr('Edit Event'),
                    onPressed: () =>
                        context.push('/admin/events/edit?id=$eventId'),
                  ),
                IconButton(
                  icon: const Icon(Icons.share, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price & seats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('₹${event.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                            Text(context.tr('per ticket'),
                                style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${event.availableSeats} / ${event.capacity}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(context.tr('seats available'),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Capacity bar
                    LinearPercentIndicator(
                      percent: event.fillPercent.clamp(0.0, 1.0),
                      lineHeight: 8,
                      backgroundColor: Colors.grey.shade200,
                      progressColor: event.isSoldOut
                          ? AppColors.error
                          : AppColors.primary,
                      barRadius: const Radius.circular(4),
                    ),
                    const SizedBox(height: 24),

                    // Info cards
                    _InfoRow(
                        icon: Icons.location_on,
                        label: 'Venue',
                        value: event.venue),
                    _InfoRow(
                        icon: Icons.calendar_today,
                        label: 'Date',
                        value:
                            '${event.date.day}/${event.date.month}/${event.date.year}'),
                    _InfoRow(
                        icon: Icons.access_time,
                        label: 'Time',
                        value: event.time),
                    const SizedBox(height: 24),

                    Text(context.tr('About This Event'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(event.description,
                        style: const TextStyle(
                            color: Colors.grey, height: 1.7)),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: eventAsync.whenData((event) {
        if (event.isSoldOut) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.error.withValues(alpha: 0.1),
            child: ElevatedButton(
              onPressed: null,
              child: Text(context.tr('Sold Out')),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: ElevatedButton.icon(
            onPressed: () => context.push('/events/$eventId/book'),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(context.tr('Book Ticket')),
          ),
        );
      }).valueOrNull ??
          const SizedBox.shrink(),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr(label),
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 12)),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}