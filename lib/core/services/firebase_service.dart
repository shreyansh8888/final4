// ─────────────────────────────────────────────────────────────────────────────
// firebase_service.dart — Firebase Auth + Cloud Firestore (official SDK)
//
// Everything that must survive logout / reinstall (bookings, practice
// sessions, leaderboard, profile) is stored in Firestore under the user's
// account. Firestore's built-in offline cache is used for speed/offline use,
// but the source of truth is the cloud, so data comes back after re-login.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/event_model.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../models/stats_model.dart';

/// Describes the result of an OTP send request.
enum OtpSendResult {
  success,
  autoVerified,
  invalidPhone,
  tooManyRequests,
  notConfigured,
  network,
  unknown,
}

/// Describes the result of an OTP verify request.
enum OtpVerifyResult { success, wrongCode, expired, unknown }

class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _uuid = Uuid();

  // ── Phone-auth verification state ──────────────────────────────────────────
  String? _pendingVerificationId;
  int? _resendToken;

  /// Last Firebase error code from phone auth (shown to help debugging).
  String? lastOtpErrorCode;

  // ── Mutex for preventing double bookings ───────────────────────────────────
  bool _isBookingInProgress = false;
  bool _seedAttempted = false;

  static Future<void> initialize() async {
    // Firebase.initializeApp is done in main.dart. Firestore keeps its own
    // offline cache on mobile, nothing else to set up here.
  }

  // ─── Phone / OTP Auth ──────────────────────────────────────────────────────
  /// Sends an SMS OTP to [phoneNumber] (E.164, e.g. +919876543210).
  Future<OtpSendResult> sendOtp(
    String phoneNumber, {
    bool resend = false,
  }) async {
    final completer = Completer<OtpSendResult>();
    lastOtpErrorCode = null;

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: resend ? _resendToken : null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Instant verification / SMS auto-retrieval on Android.
          try {
            await _auth.signInWithCredential(credential);
            if (!completer.isCompleted) {
              completer.complete(OtpSendResult.autoVerified);
            }
          } catch (e) {
            debugPrint('[PhoneAuth] auto sign-in error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[PhoneAuth] failed: ${e.code} ${e.message}');
          lastOtpErrorCode = e.code;
          if (completer.isCompleted) return;
          switch (e.code) {
            case 'invalid-phone-number':
              completer.complete(OtpSendResult.invalidPhone);
              break;
            case 'too-many-requests':
            case 'quota-exceeded':
              completer.complete(OtpSendResult.tooManyRequests);
              break;
            case 'network-request-failed':
              completer.complete(OtpSendResult.network);
              break;
            case 'app-not-authorized':
            case 'missing-client-identifier':
            case 'invalid-app-credential':
            case 'missing-app-credential':
            case 'captcha-check-failed':
            case 'missing-recaptcha-token':
            case 'invalid-recaptcha-token':
            case 'operation-not-allowed':
            case 'internal-error':
            case 'web-internal-error':
              completer.complete(OtpSendResult.notConfigured);
              break;
            default:
              completer.complete(OtpSendResult.unknown);
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          _pendingVerificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete(OtpSendResult.success);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _pendingVerificationId = verificationId;
        },
      );

      // Never hang the UI forever if no callback arrives.
      return await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => OtpSendResult.network,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[PhoneAuth] exception: ${e.code}');
      lastOtpErrorCode = e.code;
      if (e.code == 'invalid-phone-number') return OtpSendResult.invalidPhone;
      if (e.code == 'too-many-requests') return OtpSendResult.tooManyRequests;
      if (e.code == 'network-request-failed') return OtpSendResult.network;
      return OtpSendResult.unknown;
    } catch (e) {
      debugPrint('[PhoneAuth] unexpected error: $e');
      return OtpSendResult.unknown;
    }
  }

  /// Verify the 6-digit [otp] typed by the user.
  Future<OtpVerifyResult> verifyOtp(String otp) async {
    if (_pendingVerificationId == null) return OtpVerifyResult.expired;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _pendingVerificationId!,
        smsCode: otp,
      );
      await _auth.signInWithCredential(credential);
      return OtpVerifyResult.success;
    } on FirebaseAuthException catch (e) {
      debugPrint('[PhoneAuth] verifyOtp error: ${e.code}');
      lastOtpErrorCode = e.code;
      if (e.code == 'invalid-verification-code') return OtpVerifyResult.wrongCode;
      if (e.code == 'session-expired' || e.code == 'invalid-verification-id') {
        return OtpVerifyResult.expired;
      }
      return OtpVerifyResult.unknown;
    } catch (e) {
      debugPrint('[PhoneAuth] verifyOtp unexpected error: $e');
      return OtpVerifyResult.unknown;
    }
  }

  // ─── Current user ──────────────────────────────────────────────────────────
  String? get currentFirebaseUid => _auth.currentUser?.uid;
  bool get isSignedIn => _auth.currentUser != null;
  User? get currentFirebaseUser => _auth.currentUser;

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Firestore helpers ─────────────────────────────────────────────────────

  /// Converts Firestore values (Timestamp etc.) into plain JSON values.
  dynamic _normalize(dynamic v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      final out = <String, dynamic>{};
      v.forEach((k, val) => out[k.toString()] = _normalize(val));
      return out;
    }
    if (v is List) return v.map(_normalize).toList();
    return v;
  }

  Map<String, dynamic> _normMap(Map<String, dynamic> m) =>
      _normalize(m) as Map<String, dynamic>;

  bool _isPermissionDenied(Object e) =>
      e is FirebaseException && e.code == 'permission-denied';

  /// Server first (with timeout), cache when offline. Permission errors are
  /// re-thrown so they are not mistaken for "no data".
  Future<QuerySnapshot<Map<String, dynamic>>> _getQuery(
      Query<Map<String, dynamic>> q) async {
    try {
      return await q.get().timeout(const Duration(seconds: 10));
    } catch (e) {
      if (_isPermissionDenied(e)) rethrow;
      debugPrint('[Firestore] query fell back to cache: $e');
      return await q.get(const GetOptions(source: Source.cache));
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getDoc(
      DocumentReference<Map<String, dynamic>> ref) async {
    try {
      return await ref.get().timeout(const Duration(seconds: 8));
    } catch (e) {
      if (_isPermissionDenied(e)) rethrow;
      debugPrint('[Firestore] doc fell back to cache: $e');
      return await ref.get(const GetOptions(source: Source.cache));
    }
  }

  /// Waits for the server to confirm a write, but never blocks the UI forever
  /// when offline (Firestore queues the write and syncs it later).
  Future<void> _write(Future<void> op) async {
    try {
      await op.timeout(const Duration(seconds: 12));
    } on TimeoutException {
      debugPrint('[Firestore] write queued for sync (offline?)');
    }
  }

  String _friendly(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Permission denied by Firestore rules. Publish the updated firestore.rules in Firebase Console.';
      }
      if (e.code == 'unavailable') {
        return 'No connection. Please check your internet and try again.';
      }
      return e.message ?? e.code;
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  // ─── User profile (users/{uid}) ────────────────────────────────────────────
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final snap = await _getDoc(_db.collection('users').doc(uid));
      if (!snap.exists) return null;
      return _normMap(snap.data() ?? {});
    } catch (e) {
      debugPrint('[FirebaseService] getUserProfile: $e');
      return null;
    }
  }

  Future<void> saveUserProfile(
    String uid, {
    String? name,
    String? email,
    String? phone,
    bool create = false,
  }) async {
    final data = <String, dynamic>{
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      'updated_at': Timestamp.now(),
      if (create) 'created_at': Timestamp.now(),
    };
    await _write(
        _db.collection('users').doc(uid).set(data, SetOptions(merge: true)));
  }

  // ─── Events ────────────────────────────────────────────────────────────────
  EventModel _eventFromData(String id, Map<String, dynamic> data) {
    final m = _normMap(data);
    m['id'] = id;
    return EventModel.fromJson(m);
  }

  Map<String, dynamic> _eventToData(EventModel e) {
    final data = e.toJson();
    data['date'] = Timestamp.fromDate(e.date);
    if (e.createdAt != null) {
      data['created_at'] = Timestamp.fromDate(e.createdAt!);
    }
    return data;
  }

  Future<List<EventModel>> getEvents({String? search, String? category}) async {
    var events = <EventModel>[];
    try {
      final snap = await _getQuery(_db.collection('events'));
      for (final d in snap.docs) {
        try {
          events.add(_eventFromData(d.id, d.data()));
        } catch (e) {
          debugPrint('[FirebaseService] bad event doc ${d.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('[FirebaseService] getEvents error: $e');
    }

    if (events.isEmpty) {
      // Nothing in Firestore yet: let an admin push the sample events up,
      // and show the samples meanwhile.
      _seedFirestoreIfAdmin();
      events = _seedEvents();
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return _filterEvents(events, search: search, category: category);
  }

  Future<EventModel> getEventById(String eventId) async {
    try {
      final snap = await _getDoc(_db.collection('events').doc(eventId));
      if (snap.exists && snap.data() != null) {
        return _eventFromData(snap.id, snap.data()!);
      }
    } catch (e) {
      debugPrint('[FirebaseService] getEventById error: $e');
    }
    for (final ev in _seedEvents()) {
      if (ev.id == eventId) return ev;
    }
    throw Exception('Event not found: $eventId');
  }

  Future<EventModel> createEvent(EventModel event) async {
    _assertAdmin();
    final eventId = event.id.isNotEmpty
        ? event.id
        : 'EVT-${DateTime.now().year}-${_uuid.v4().substring(0, 6).toUpperCase()}';

    final full = EventModel(
      id: eventId,
      title: event.title,
      description: event.description,
      venue: event.venue,
      date: event.date,
      time: event.time,
      price: event.price,
      image: event.image,
      capacity: event.capacity,
      bookedCount: event.bookedCount,
      category: event.category,
      isFavourite: event.isFavourite,
      createdAt: event.createdAt ?? DateTime.now(),
    );

    try {
      await _write(_db.collection('events').doc(eventId).set(_eventToData(full)));
    } catch (e) {
      throw Exception(_friendly(e));
    }
    return full;
  }

  Future<EventModel> updateEvent(EventModel event) async {
    _assertAdmin();
    try {
      await _write(_db
          .collection('events')
          .doc(event.id)
          .set(_eventToData(event), SetOptions(merge: true)));
    } catch (e) {
      throw Exception(_friendly(e));
    }
    return event;
  }

  Future<void> deleteEvent(String eventId) async {
    _assertAdmin();
    try {
      await _write(_db.collection('events').doc(eventId).delete());
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }

  // ─── Bookings ──────────────────────────────────────────────────────────────
  BookingModel _bookingFromData(String id, Map<String, dynamic> data) {
    final m = _normMap(data);
    m['id'] = id;
    return BookingModel.fromJson(m);
  }

  /// Books a ticket. The booking (with a full copy of the event details) is
  /// written to Firestore `bookings/{id}` so it can always be shown again.
  Future<BookingModel> bookTicket({
    required String eventId,
    required UserModel user,
  }) async {
    if (_isBookingInProgress) {
      throw Exception('A booking is already in progress. Please wait.');
    }
    if (_auth.currentUser == null) {
      throw Exception('Please sign in to complete your booking.');
    }
    _isBookingInProgress = true;

    try {
      final event = await getEventById(eventId);
      if (event.isSoldOut) {
        throw Exception('Sorry, this event is sold out.');
      }

      final ticketUuid = _uuid.v4();
      final bookingId =
          'BK-${DateTime.now().year}-${_uuid.v4().substring(0, 8).toUpperCase()}';
      final bookingDate = DateTime.now();

      final qrPayload = {
        'ticketId': bookingId,
        'ticketUuid': ticketUuid,
        'eventId': event.id,
        'eventTitle': event.title,
        'userId': user.id,
        'userName': user.name,
        'userEmail': user.email,
        'issuedAt': bookingDate.toIso8601String(),
        'securityHash': _generateSecurityHash(ticketUuid, bookingId, user.id),
      };

      final booking = BookingModel(
        id: bookingId,
        userId: user.id,
        eventId: event.id,
        ticketUuid: ticketUuid,
        qrData: jsonEncode(qrPayload),
        bookingDate: bookingDate,
        status: 'confirmed',
        event: event,
        userName: user.name,
        userEmail: user.email,
      );

      final data = booking.toJson();
      data['booking_date'] = Timestamp.fromDate(bookingDate);

      try {
        await _write(_db.collection('bookings').doc(bookingId).set(data));
      } catch (e) {
        throw Exception(_friendly(e));
      }

      // Seat counter: best effort (events seeded locally may not exist in
      // Firestore yet, and that must not fail the booking itself).
      try {
        await _write(_db
            .collection('events')
            .doc(event.id)
            .update({'booked_count': FieldValue.increment(1)}));
      } catch (e) {
        debugPrint('[FirebaseService] booked_count not updated: $e');
      }

      return BookingModel(
        id: booking.id,
        userId: booking.userId,
        eventId: booking.eventId,
        ticketUuid: booking.ticketUuid,
        qrData: booking.qrData,
        bookingDate: booking.bookingDate,
        status: booking.status,
        event: EventModel(
          id: event.id,
          title: event.title,
          description: event.description,
          venue: event.venue,
          date: event.date,
          time: event.time,
          price: event.price,
          image: event.image,
          capacity: event.capacity,
          bookedCount: event.bookedCount + 1,
          category: event.category,
          isFavourite: event.isFavourite,
          createdAt: event.createdAt,
        ),
        userName: booking.userName,
        userEmail: booking.userEmail,
      );
    } finally {
      _isBookingInProgress = false;
    }
  }

  /// All bookings of [userId] straight from Firestore.
  /// Uses a `where user_id ==` query, which is exactly what the security
  /// rules allow (rules are not filters, so an unfiltered list is rejected).
  Future<List<BookingModel>> getUserBookings(String userId) async {
    final snap = await _getQuery(
        _db.collection('bookings').where('user_id', isEqualTo: userId));
    final list = <BookingModel>[];
    for (final d in snap.docs) {
      try {
        var b = _bookingFromData(d.id, d.data());
        if (b.event == null) {
          try {
            final ev = await getEventById(b.eventId);
            b = _withEvent(b, ev);
          } catch (_) {}
        }
        list.add(b);
      } catch (e) {
        debugPrint('[FirebaseService] bad booking doc ${d.id}: $e');
      }
    }
    list.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    return list;
  }

  BookingModel _withEvent(BookingModel b, EventModel ev) => BookingModel(
        id: b.id,
        userId: b.userId,
        eventId: b.eventId,
        ticketUuid: b.ticketUuid,
        qrData: b.qrData,
        bookingDate: b.bookingDate,
        status: b.status,
        event: ev,
        userName: b.userName,
        userEmail: b.userEmail,
      );

  Future<List<BookingModel>> getAllBookings() async {
    _assertAdmin();
    final snap = await _getQuery(_db.collection('bookings'));
    final list = <BookingModel>[];
    for (final d in snap.docs) {
      try {
        list.add(_bookingFromData(d.id, d.data()));
      } catch (e) {
        debugPrint('[FirebaseService] bad booking doc ${d.id}: $e');
      }
    }
    list.sort((a, b) => b.bookingDate.compareTo(a.bookingDate));
    return list;
  }

  Future<BookingModel> getBookingById(String bookingId) async {
    final snap = await _getDoc(_db.collection('bookings').doc(bookingId));
    if (!snap.exists || snap.data() == null) {
      throw Exception('Booking not found: $bookingId');
    }
    var b = _bookingFromData(snap.id, snap.data()!);
    if (b.event == null) {
      try {
        b = _withEvent(b, await getEventById(b.eventId));
      } catch (_) {}
    }
    return b;
  }

  Future<void> cancelBooking(String bookingId) async {
    final ref = _db.collection('bookings').doc(bookingId);
    final snap = await _getDoc(ref);
    final wasConfirmed = snap.data()?['status'] == 'confirmed';
    final eventId = snap.data()?['event_id']?.toString();

    try {
      await _write(ref.update({'status': 'cancelled'}));
    } catch (e) {
      throw Exception(_friendly(e));
    }

    if (wasConfirmed && eventId != null) {
      try {
        await _write(_db
            .collection('events')
            .doc(eventId)
            .update({'booked_count': FieldValue.increment(-1)}));
      } catch (e) {
        debugPrint('[FirebaseService] seat not released: $e');
      }
    }
  }

  // ─── Practice sessions / stats / leaderboard ───────────────────────────────
  Future<List<PracticeRecord>> getPracticeRecords(String userId) async {
    try {
      final snap = await _getQuery(_db
          .collection('practice_sessions')
          .where('user_id', isEqualTo: userId));
      final list = <PracticeRecord>[];
      for (final d in snap.docs) {
        try {
          list.add(PracticeRecord.fromMap(d.id, _normMap(d.data())));
        } catch (e) {
          debugPrint('[FirebaseService] bad practice doc ${d.id}: $e');
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('[FirebaseService] getPracticeRecords error: $e');
      return const [];
    }
  }

  /// Saves the finished practice session and refreshes the user's
  /// leaderboard entry.
  Future<void> savePracticeSession({
    required UserModel user,
    required List<PracticeRecord> records,
  }) async {
    if (records.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final r in records) {
        final data = r.toMap();
        data['created_at'] = Timestamp.fromDate(r.createdAt);
        batch.set(_db.collection('practice_sessions').doc(r.id), data);
      }
      await _write(batch.commit());
    } catch (e) {
      throw Exception(_friendly(e));
    }

    // Refresh leaderboard entry from all saved records.
    try {
      final all = await getPracticeRecords(user.id);
      final stats = UserStats.fromRecords(all, 0);
      await _write(_db.collection('leaderboard').doc(user.id).set({
        'user_id': user.id,
        'name': _publicName(user.name),
        'total_score': stats.totalScore,
        'best_accuracy': stats.bestAccuracy,
        'avg_accuracy': stats.avgAccuracy,
        'sessions': stats.sessions,
        'streak': stats.streakDays,
        'updated_at': Timestamp.now(),
      }));
    } catch (e) {
      debugPrint('[FirebaseService] leaderboard update failed: $e');
    }
  }

  String _publicName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'Garba Dancer';
    if (parts.first.startsWith('+')) return 'Garba Dancer';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0].toUpperCase()}.';
  }

  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 50}) async {
    final snap = await _getQuery(_db
        .collection('leaderboard')
        .orderBy('total_score', descending: true)
        .limit(limit));
    return snap.docs
        .map((d) => LeaderboardEntry.fromMap(d.id, _normMap(d.data())))
        .toList();
  }

  // ─── Admin Check & Guard ───────────────────────────────────────────────────
  void _assertAdmin() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Authentication required for administrative actions.');
    }
    // Real enforcement happens in firestore.rules.
  }

  bool _currentUserLooksAdmin() {
    final email = _auth.currentUser?.email?.toLowerCase() ?? '';
    return email.contains('admin');
  }

  // ─── Helpers: Filter & Seed Data ───────────────────────────────────────────
  List<EventModel> _filterEvents(
    List<EventModel> events, {
    String? search,
    String? category,
  }) {
    return events.where((e) {
      final matchSearch = search == null ||
          search.isEmpty ||
          e.title.toLowerCase().contains(search.toLowerCase()) ||
          e.venue.toLowerCase().contains(search.toLowerCase());

      final matchCategory = category == null ||
          category.isEmpty ||
          category.toLowerCase() == 'all' ||
          e.category?.toLowerCase() == category.toLowerCase();

      return matchSearch && matchCategory;
    }).toList();
  }

  /// Admin only: upload the sample events to Firestore the first time so that
  /// seat counts become permanent too.
  void _seedFirestoreIfAdmin() {
    if (_seedAttempted || !_currentUserLooksAdmin()) return;
    _seedAttempted = true;
    () async {
      try {
        final batch = _db.batch();
        for (final ev in _seedEvents()) {
          batch.set(_db.collection('events').doc(ev.id), _eventToData(ev));
        }
        await batch.commit().timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint('[FirebaseService] seeding events failed: $e');
      }
    }();
  }

  List<EventModel> _seedEvents() => [
        EventModel(
          id: 'EVT-2026-UW-BARODA',
          title: 'United Way of Baroda Garba 2026',
          description:
              'The largest, most iconic, and authentic Garba festival in Gujarat. Join over 30,000 dancers in traditional Chaniya Choli and Kediyu under majestic lighting, accompanied by traditional live folk orchestras.',
          venue: 'Alembic Ground, Vadodara, Gujarat',
          date: DateTime(2026, 10, 20),
          time: '7:30 PM - 1:00 AM',
          price: 1200.0,
          capacity: 5000,
          bookedCount: 3420,
          category: 'Navratri',
          image:
              'https://images.unsplash.com/photo-1574169208507-84376144848b?w=800',
          isFavourite: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        EventModel(
          id: 'EVT-2026-VG-AHMEDABAD',
          title: 'Vibrant Gujarat Mega Dandiya Raas',
          description:
              'High-voltage Dandiya and Raas festival featuring leading folk artists, prize competitions for best couple, authentic Kathiyawadi food stalls, and world-class sound engineering.',
          venue: 'GMDC Ground, Ahmedabad, Gujarat',
          date: DateTime(2026, 10, 22),
          time: '8:00 PM - 12:30 AM',
          price: 850.0,
          capacity: 3500,
          bookedCount: 2100,
          category: 'Dandiya',
          image:
              'https://images.unsplash.com/photo-1533174072545-7a4b6ad7a6c3?w=800',
          createdAt: DateTime(2026, 1, 5),
        ),
        EventModel(
          id: 'EVT-2026-SURAT-RAAS',
          title: 'Surat Rangilo Raas Mahotsav',
          description:
              'Experience the unmatched hospitality and vibrant energy of Surat. Non-stop Dodhiya, Tran Taali, and traditional Hinch with celebrity Gujarati folk vocalists.',
          venue: 'Indoor Stadium, Athwa Lines, Surat, Gujarat',
          date: DateTime(2026, 10, 24),
          time: '8:30 PM - 1:30 AM',
          price: 650.0,
          capacity: 2500,
          bookedCount: 2450,
          category: 'Cultural',
          image:
              'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800',
          createdAt: DateTime(2026, 1, 10),
        ),
        EventModel(
          id: 'EVT-2026-WORKSHOP-RAJKOT',
          title: 'Masterclass: Traditional Garba Workshop',
          description:
              'Exclusive choreography workshop led by state award-winning folk masters. Learn authentic Sanedo, 3-Clap, Dodhiya variations, and spins with live rhythm practice.',
          venue: 'Rajkot Cultural Hall, Rajkot, Gujarat',
          date: DateTime(2026, 10, 18),
          time: '5:00 PM - 8:00 PM',
          price: 350.0,
          capacity: 200,
          bookedCount: 95,
          category: 'Workshop',
          image:
              'https://images.unsplash.com/photo-1545128485-c400e7702796?w=800',
          createdAt: DateTime(2026, 1, 15),
        ),
      ];

  String _generateSecurityHash(
      String ticketUuid, String bookingId, String userId) {
    final raw = '$ticketUuid:$bookingId:$userId:GARBA_SECURE_2026';
    return base64UrlEncode(utf8.encode(raw));
  }

  // ─── Push Notifications / Storage / Analytics (not wired yet) ─────────────
  Future<String?> getFcmToken() async => null;
  Future<void> subscribeToTopic(String topic) async {}

  Future<String?> uploadFile({
    required List<int> fileBytes,
    required String storagePath,
    String contentType = 'image/jpeg',
  }) async =>
      null;

  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    assert(() {
      debugPrint('[Firebase] logEvent: $name ${params ?? ''}');
      return true;
    }());
  }
}
