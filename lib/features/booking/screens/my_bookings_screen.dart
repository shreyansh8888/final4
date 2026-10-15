import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/booking_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/booking_provider.dart';

class MyBookingsScreen extends ConsumerWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('My Bookings'))),
      body: bookingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(e.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(myBookingsProvider.notifier).refresh(),
                child: Text(context.tr('Retry')),
              ),
            ],
          ),
        ),
        data: (bookings) => bookings.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        size: 80,
                        color: AppColors.primary.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(context.tr('No bookings yet'),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Text(context.tr('Book your first Garba event!'),
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/events'),
                      child: Text(context.tr('Explore Events')),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(myBookingsProvider.notifier).refresh(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: bookings.length,
                  itemBuilder: (_, i) => BookingCard(booking: bookings[i])
                      .animate(delay: (i * 60).ms)
                      .slideX(begin: -0.1)
                      .fade(),
                ),
              ),
      ),
    );
  }
}

class BookingCard extends ConsumerWidget {
  final BookingModel booking;
  const BookingCard({super.key, required this.booking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConfirmed = booking.isConfirmed;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    booking.event?.title ?? context.tr('Event'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusBadge(status: booking.status),
              ],
            ),
            const SizedBox(height: 8),
            if (booking.event != null) ...[
              Row(children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(booking.event!.venue,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${booking.event!.date.day}/${booking.event!.date.month}/${booking.event!.date.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ]),
            ],
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('Ticket ID'),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    Text(
                      booking.ticketUuid.substring(0, 8).toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          letterSpacing: 1),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isConfirmed)
                      TextButton.icon(
                        onPressed: () =>
                            context.push('/ticket/${booking.id}'),
                        icon: const Icon(Icons.qr_code_2),
                        label: Text(context.tr('View QR')),
                      ),
                    if (isConfirmed)
                      TextButton(
                        onPressed: () => _confirmCancel(context, ref),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: Text(context.tr('Cancel')),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.tr('Cancel Booking?')),
        content: Text(context
            .tr('Are you sure you want to cancel this booking? This action cannot be undone.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('No'))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            child: Text(context.tr('Yes, Cancel')),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(myBookingsProvider.notifier)
          .cancelBooking(booking.id);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'confirmed':
        color = AppColors.success;
        break;
      case 'cancelled':
        color = AppColors.error;
        break;
      default:
        color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        context.tr(status[0].toUpperCase() + status.substring(1)),
        style: TextStyle(
            color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
