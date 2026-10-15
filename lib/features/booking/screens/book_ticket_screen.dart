import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/booking_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../events/providers/events_provider.dart';
import '../providers/booking_provider.dart';

class BookTicketScreen extends ConsumerStatefulWidget {
  final String eventId;
  const BookTicketScreen({super.key, required this.eventId});

  @override
  ConsumerState<BookTicketScreen> createState() => _BookTicketScreenState();
}

class _BookTicketScreenState extends ConsumerState<BookTicketScreen> {
  bool _loading = false;
  bool _agreed = false;

  Future<void> _confirmBooking() async {
    if (_loading) return; // Guard against rapid duplicate clicks
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Please agree to the terms'))));
      return;
    }
    setState(() => _loading = true);
    try {
      final booking = await ref
          .read(myBookingsProvider.notifier)
          .bookTicket(widget.eventId);
      if (!mounted) return;
      _showSuccessDialog(booking);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(BookingModel booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 80),
            const SizedBox(height: 16),
            Text(context.tr('Booking Confirmed!'),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${context.tr('Ticket ID')}: ${booking.ticketUuid.substring(0, 8).toUpperCase()}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.go('/ticket/${booking.id}');
              },
              child: Text(context.tr('View QR Ticket')),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.myBookings);
              },
              child: Text(context.tr('My Bookings')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Book Ticket'))),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (event) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event summary card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(event.venue,
                                style: const TextStyle(color: Colors.grey))),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                            '${event.date.day}/${event.date.month}/${event.date.year} • ${event.time}',
                            style: const TextStyle(color: Colors.grey)),
                      ]),
                    ],
                  ),
                ),
              ).animate().fade().slideY(begin: 0.1),
              const SizedBox(height: 24),
              // Price breakdown
              Text(context.tr('Price Breakdown'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _PriceRow(label: context.tr('Ticket Price'), value: event.price),
              _PriceRow(label: context.tr('Convenience Fee'), value: event.price * 0.02),
              const Divider(),
              _PriceRow(
                  label: context.tr('Total'),
                  value: event.price + event.price * 0.02,
                  bold: true),
              const SizedBox(height: 24),
              // Seats available
              Row(
                children: [
                  const Icon(Icons.event_seat,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('${event.availableSeats} ${context.tr('seats available')}'),
                ],
              ),
              const SizedBox(height: 24),
              // Terms
              Row(
                children: [
                  Checkbox(
                    value: _agreed,
                    onChanged: (v) => setState(() => _agreed = v!),
                    activeColor: AppColors.primary,
                  ),
                  Expanded(
                    child: Text(
                      context.tr('I agree to the terms & conditions and the refund policy.'),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Payment note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.info, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('Payment gateway coming soon — booking is free during beta.'),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loading ? null : _confirmBooking,
                icon: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.confirmation_number_outlined),
                label: Text(_loading ? context.tr('Booking...') : context.tr('Confirm Booking')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _PriceRow(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  : null),
          Text('₹${value.toStringAsFixed(2)}',
              style: bold
                  ? const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary)
                  : null),
        ],
      ),
    );
  }
}
