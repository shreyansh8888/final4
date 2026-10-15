// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingModel _$BookingModelFromJson(Map<String, dynamic> json) => BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      eventId: json['event_id'] as String,
      ticketUuid: json['ticket_uuid'] as String,
      qrData: json['qr_data'] as String,
      bookingDate: DateTime.parse(json['booking_date'] as String),
      status: json['status'] as String,
      event: json['event'] == null
          ? null
          : EventModel.fromJson(json['event'] as Map<String, dynamic>),
      userName: json['user_name'] as String?,
      userEmail: json['user_email'] as String?,
    );

Map<String, dynamic> _$BookingModelToJson(BookingModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'event_id': instance.eventId,
      'ticket_uuid': instance.ticketUuid,
      'qr_data': instance.qrData,
      'booking_date': instance.bookingDate.toIso8601String(),
      'status': instance.status,
      'event': instance.event?.toJson(),
      'user_name': instance.userName,
      'user_email': instance.userEmail,
    };
