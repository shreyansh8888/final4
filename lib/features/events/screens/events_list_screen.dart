import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/models/event_model.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/events_provider.dart';

class EventsListScreen extends ConsumerStatefulWidget {
  const EventsListScreen({super.key});

  @override
  ConsumerState<EventsListScreen> createState() => _EventsListScreenState();
}

class _EventsListScreenState extends ConsumerState<EventsListScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedCategory;

  final _categories = ['All', 'Navratri', 'Dandiya', 'Cultural', 'Workshop'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Events')),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: user?.isAdmin == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/admin/events/edit'),
              icon: const Icon(Icons.add),
              label: Text(context.tr('Add Event')),
              backgroundColor: AppColors.primary,
            )
          : null,
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: context.tr('Search events...'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(eventsProvider.notifier).refresh();
                        },
                      )
                    : null,
              ),
              onSubmitted: (v) =>
                  ref.read(eventsProvider.notifier).search(v),
            ),
          ),
          // Category chips
          SizedBox(
            height: 44,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final selected = _selectedCategory == cat ||
                    (cat == 'All' && _selectedCategory == null);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(context.tr(cat)),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedCategory =
                          cat == 'All' ? null : cat);
                      if (cat != 'All') {
                        ref
                            .read(eventsProvider.notifier)
                            .filterByCategory(cat);
                      } else {
                        ref.read(eventsProvider.notifier).refresh();
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Events list
          Expanded(
            child: eventsAsync.when(
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
                          ref.read(eventsProvider.notifier).refresh(),
                      child: Text(context.tr('Retry')),
                    ),
                  ],
                ),
              ),
              data: (events) => events.isEmpty
                  ? Center(child: Text(context.tr('No events found')))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(eventsProvider.notifier).refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        itemBuilder: (_, i) => EventCard(event: events[i])
                            .animate(delay: (i * 60).ms)
                            .slideY(begin: 0.2, duration: 300.ms)
                            .fade(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('Filter Events'),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text(context.tr('Categories')),
            Wrap(
              spacing: 8,
              children: _categories
                  .map((c) => FilterChip(
                        label: Text(context.tr(c)),
                        selected: _selectedCategory == c,
                        onSelected: (_) {
                          Navigator.pop(context);
                          setState(() =>
                              _selectedCategory = c == 'All' ? null : c);
                        },
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class EventCard extends ConsumerWidget {
  final EventModel event;
  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/events/${event.id}'),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: event.image != null
                  ? CachedNetworkImage(
                      imageUrl: event.image!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _PlaceholderImage(),
                    )
                  : _PlaceholderImage(),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + Favourite
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (event.category != null)
                        Chip(
                          label: Text(context.tr(event.category!),
                              style: const TextStyle(fontSize: 11)),
                          padding: EdgeInsets.zero,
                        ),
                      GestureDetector(
                        onTap: () => ref
                            .read(eventsProvider.notifier)
                            .toggleFavourite(event.id),
                        child: Icon(
                          event.isFavourite
                              ? Icons.favorite_rounded
                              : Icons.favorite_outline,
                          color: event.isFavourite
                              ? AppColors.error
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(event.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(event.venue,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 13))),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${event.date.day}/${event.date.month}/${event.date.year} • ${event.time}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${event.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                      event.isSoldOut
                          ? Chip(
                              label: Text(context.tr('Sold Out'),
                                  style: const TextStyle(color: Colors.white)),
                              backgroundColor: AppColors.error,
                            )
                          : Text(
                              '${event.availableSeats} ${context.tr('seats left')}',
                              style: const TextStyle(
                                  color: AppColors.success, fontSize: 13),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        height: 180,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.festiveGradient,
        ),
        child: const Center(
          child: Icon(Icons.music_note_rounded,
              size: 60, color: Colors.white54),
        ),
      );
}