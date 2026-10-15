// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'performance_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PerformanceReport _$PerformanceReportFromJson(Map<String, dynamic> json) =>
    PerformanceReport(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      accuracy: (json['accuracy'] as num).toDouble(),
      score: (json['score'] as num).toDouble(),
      grade: json['grade'] as String,
      mistakes:
          (json['mistakes'] as List<dynamic>).map((e) => e as String).toList(),
      suggestions: (json['suggestions'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      stepName: json['step_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$PerformanceReportToJson(PerformanceReport instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'accuracy': instance.accuracy,
      'score': instance.score,
      'grade': instance.grade,
      'mistakes': instance.mistakes,
      'suggestions': instance.suggestions,
      'step_name': instance.stepName,
      'created_at': instance.createdAt.toIso8601String(),
    };
