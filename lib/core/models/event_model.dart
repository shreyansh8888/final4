import 'package:json_annotation/json_annotation.dart';
part 'event_model.g.dart';

@JsonSerializable()
class EventModel {
  final String id;
  final String title;
  final String description;
  final String venue;
  final DateTime date;
  final String time;
  final double price;
  final String? image;
  final int capacity;
  @JsonKey(name: 'booked_count')
  final int bookedCount;
  final String? category;
  @JsonKey(name: 'is_favourite')
  final bool isFavourite;
  @JsonKey(name: 'created_at')
  final DateTime? createdAt;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.venue,
    required this.date,
    required this.time,
    required this.price,
    this.image,
    required this.capacity,
    this.bookedCount = 0,
    this.category,
    this.isFavourite = false,
    this.createdAt,
  });

  bool get isSoldOut => bookedCount >= capacity;
  int get availableSeats => capacity - bookedCount;
  double get fillPercent => capacity > 0 ? bookedCount / capacity : 0;

  factory EventModel.fromJson(Map<String, dynamic> json) =>
      _$EventModelFromJson(json);
  Map<String, dynamic> toJson() => _$EventModelToJson(this);

  EventModel copyWith({bool? isFavourite}) => EventModel(
        id: id,
        title: title,
        description: description,
        venue: venue,
        date: date,
        time: time,
        price: price,
        image: image,
        capacity: capacity,
        bookedCount: bookedCount,
        category: category,
        isFavourite: isFavourite ?? this.isFavourite,
        createdAt: createdAt,
      );
}
