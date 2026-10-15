import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/event_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/providers/events_provider.dart';
import '../../booking/providers/booking_provider.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _bookingSearchCtrl = TextEditingController();
  String _bookingSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bookingSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    // Defense-in-depth UI check: even if navigated directly, reject non-admins
    if (user?.isAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Access Denied')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.gpp_bad_outlined,
                    size: 64, color: AppColors.error),
                const SizedBox(height: 16),
                const Text(
                  'Administrative Privileges Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account does not have permission to access the Garba AI Admin Console.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final eventsAsync = ref.watch(eventsProvider);
    final bookingsAsync = ref.watch(allBookingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.event_note), text: 'Events'),
            Tab(icon: Icon(Icons.receipt_long), text: 'All Bookings'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add New Event',
            onPressed: () => context.push(AppRoutes.adminEditEvent),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Events Manager
          _buildEventsTab(eventsAsync),
          // Tab 2: Bookings Manager
          _buildBookingsTab(bookingsAsync),
        ],
      ),
    );
  }

  Widget _buildEventsTab(AsyncValue<List<EventModel>> eventsAsync) {
    return eventsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(e.toString()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(eventsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (events) {
        final totalCapacity =
            events.fold<int>(0, (sum, ev) => sum + ev.capacity);
        final totalBooked =
            events.fold<int>(0, (sum, ev) => sum + ev.bookedCount);
        final estRevenue = events.fold<double>(
            0.0, (sum, ev) => sum + (ev.price * ev.bookedCount));

        return RefreshIndicator(
          onRefresh: () => ref.read(eventsProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary cards
              Row(
                children: [
                  _MetricCard(
                    title: 'Total Events',
                    value: '${events.length}',
                    color: AppColors.primary,
                    icon: Icons.event,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    title: 'Tickets Sold',
                    value: '$totalBooked / $totalCapacity',
                    color: AppColors.secondary,
                    icon: Icons.confirmation_number,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    title: 'Est. Revenue',
                    value: '₹${(estRevenue / 1000).toStringAsFixed(1)}k',
                    color: AppColors.accentDark,
                    icon: Icons.currency_rupee,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Managed Events',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push(AppRoutes.adminEditEvent),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Event'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (events.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No events created yet.'),
                  ),
                )
              else
                ...events.map((ev) => _buildEventAdminCard(ev)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventAdminCard(EventModel event) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    event.category ?? 'Garba',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${event.venue} • ${event.date.day}/${event.date.month}/${event.date.year}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '₹${event.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                const SizedBox(width: 16),
                Text(
                  '${event.bookedCount} / ${event.capacity} booked',
                  style: TextStyle(
                    fontSize: 13,
                    color: event.isSoldOut ? AppColors.error : AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      context.push('${AppRoutes.adminEditEvent}?id=${event.id}'),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _confirmDeleteEvent(event),
                  icon: const Icon(Icons.delete_outline,
                      size: 16, color: AppColors.error),
                  label: const Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteEvent(EventModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text(
            'Are you sure you want to delete "${event.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(eventsProvider.notifier).removeEvent(event.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Deleted "${event.title}"')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Widget _buildBookingsTab(AsyncValue<List<BookingModel>> bookingsAsync) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _bookingSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search bookings by user, email, or ticket...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _bookingSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _bookingSearchCtrl.clear();
                          _bookingSearchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (v) =>
                setState(() => _bookingSearchQuery = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: bookingsAsync.when(
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
                    onPressed: () => ref.refresh(allBookingsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (allBookings) {
              final filtered = allBookings.where((b) {
                if (_bookingSearchQuery.isEmpty) return true;
                final ticket = b.ticketUuid.toLowerCase();
                final name = (b.userName ?? '').toLowerCase();
                final email = (b.userEmail ?? '').toLowerCase();
                final eventName = (b.event?.title ?? '').toLowerCase();
                return ticket.contains(_bookingSearchQuery) ||
                    name.contains(_bookingSearchQuery) ||
                    email.contains(_bookingSearchQuery) ||
                    eventName.contains(_bookingSearchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text('No bookings match your query.'),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.refresh(allBookingsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final b = filtered[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.confirmation_number,
                              color: AppColors.primary),
                        ),
                        title: Text(
                          b.userName ?? b.userEmail ?? 'Attendee',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.event?.title ?? 'Event ID: ${b.eventId}',
                                style: const TextStyle(fontSize: 12)),
                            Text(
                              'Ticket: ${b.ticketUuid.substring(0, 8).toUpperCase()} • ${b.bookingDate.day}/${b.bookingDate.month}/${b.bookingDate.year}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: b.isConfirmed
                                ? AppColors.success.withValues(alpha: 0.1)
                                : AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: b.isConfirmed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        onTap: () => context.push('/ticket/${b.id}'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
