import 'package:json_annotation/json_annotation.dart';
import 'event_model.dart';
part 'booking_model.g.dart';

@JsonSerializable(explicitToJson: true)
class BookingModel {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'event_id')
  final String eventId;
  @JsonKey(name: 'ticket_uuid')
  final String ticketUuid;
  @JsonKey(name: 'qr_data')
  final String qrData;
  @JsonKey(name: 'booking_date')
  final DateTime bookingDate;
  final String status; // confirmed | cancelled | pending
  final EventModel? event;
  @JsonKey(name: 'user_name')
  final String? userName;
  @JsonKey(name: 'user_email')
  final String? userEmail;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.ticketUuid,
    required this.qrData,
    required this.bookingDate,
    required this.status,
    this.event,
    this.userName,
    this.userEmail,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isCancelled => status == 'cancelled';

  factory BookingModel.fromJson(Map<String, dynamic> json) =>
      _$BookingModelFromJson(json);
  Map<String, dynamic> toJson() => _$BookingModelToJson(this);
}
