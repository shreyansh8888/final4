// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventModel _$EventModelFromJson(Map<String, dynamic> json) => EventModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      venue: json['venue'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      price: (json['price'] as num).toDouble(),
      image: json['image'] as String?,
      capacity: (json['capacity'] as num).toInt(),
      bookedCount: (json['booked_count'] as num?)?.toInt() ?? 0,
      category: json['category'] as String?,
      isFavourite: json['is_favourite'] as bool? ?? false,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$EventModelToJson(EventModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'description': instance.description,
      'venue': instance.venue,
      'date': instance.date.toIso8601String(),
      'time': instance.time,
      'price': instance.price,
      'image': instance.image,
      'capacity': instance.capacity,
      'booked_count': instance.bookedCount,
      'category': instance.category,
      'is_favourite': instance.isFavourite,
      'created_at': instance.createdAt?.toIso8601String(),
    };
