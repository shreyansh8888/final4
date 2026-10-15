import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../events/providers/events_provider.dart';

// ─── My Bookings Provider ────────────────────────────────────────────────────
final myBookingsProvider =
    AsyncNotifierProvider<MyBookingsNotifier, List<BookingModel>>(
  MyBookingsNotifier.new,
);

class MyBookingsNotifier extends AsyncNotifier<List<BookingModel>> {
  @override
  Future<List<BookingModel>> build() => _fetch();

  Future<List<BookingModel>> _fetch() async {
    final user = ref.watch(currentUserProvider);
    final uid = user?.id ?? FirebaseService.instance.currentFirebaseUid;
    if (uid == null || uid.isEmpty) {
      return const [];
    }
    return await FirebaseService.instance.getUserBookings(uid);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Book a ticket for the given event, updating Firestore and seat counts
  Future<BookingModel> bookTicket(String eventId) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      throw Exception('Please sign in to complete your booking.');
    }

    final booking = await FirebaseService.instance.bookTicket(
      eventId: eventId,
      user: user,
    );

    // Optimistically prepend to user bookings
    state = state.whenData((list) => [booking, ...list]);

    // Refresh events so seat count updates across the app
    ref.read(eventsProvider.notifier).refresh();

    return booking;
  }

  /// Cancel booking in Firestore and release seat
  Future<void> cancelBooking(String bookingId) async {
    await FirebaseService.instance.cancelBooking(bookingId);

    state = state.whenData((list) => list
        .map((b) => b.id == bookingId
            ? BookingModel(
                id: b.id,
                userId: b.userId,
                eventId: b.eventId,
                ticketUuid: b.ticketUuid,
                qrData: b.qrData,
                bookingDate: b.bookingDate,
                status: 'cancelled',
                event: b.event,
                userName: b.userName,
                userEmail: b.userEmail,
              )
            : b)
        .toList());

    ref.invalidate(bookingDetailProvider(bookingId));

    // Refresh events so released seat shows up
    ref.read(eventsProvider.notifier).refresh();
  }
}

// ─── Single booking detail provider ──────────────────────────────────────────
final bookingDetailProvider =
    FutureProvider.autoDispose.family<BookingModel, String>((ref, id) async {
  return await FirebaseService.instance.getBookingById(id);
});

// ─── Admin: All bookings across all users ───────────────────────────────────
final allBookingsProvider =
    FutureProvider.autoDispose<List<BookingModel>>((ref) async {
  return await FirebaseService.instance.getAllBookings();
});
