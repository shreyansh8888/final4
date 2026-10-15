import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/event_model.dart';
import '../../../core/services/firebase_service.dart';

// ─── Events list provider ─────────────────────────────────────────────────────
final eventsProvider =
    AsyncNotifierProvider<EventsNotifier, List<EventModel>>(
  EventsNotifier.new,
);

class EventsNotifier extends AsyncNotifier<List<EventModel>> {
  @override
  Future<List<EventModel>> build() => _fetchEvents();

  Future<List<EventModel>> _fetchEvents({String? search, String? category}) async {
    return await FirebaseService.instance
        .getEvents(search: search, category: category);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchEvents);
  }

  Future<void> search(String query) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchEvents(search: query));
  }

  Future<void> filterByCategory(String category) async {
    state = const AsyncLoading();
    state =
        await AsyncValue.guard(() => _fetchEvents(category: category));
  }

  void toggleFavourite(String eventId) {
    state = state.whenData((events) => events
        .map((e) => e.id == eventId ? e.copyWith(isFavourite: !e.isFavourite) : e)
        .toList());
  }

  /// Admin: Create a new event
  Future<EventModel> addEvent(EventModel event) async {
    final created = await FirebaseService.instance.createEvent(event);
    await refresh();
    return created;
  }

  /// Admin: Update an event
  Future<EventModel> updateEvent(EventModel event) async {
    final updated = await FirebaseService.instance.updateEvent(event);
    await refresh();
    return updated;
  }

  /// Admin: Delete an event
  Future<void> removeEvent(String eventId) async {
    await FirebaseService.instance.deleteEvent(eventId);
    await refresh();
  }
}

// ─── Single event detail provider ─────────────────────────────────────────────
final eventDetailProvider =
    FutureProvider.family<EventModel, String>((ref, id) async {
  return await FirebaseService.instance.getEventById(id);
});
