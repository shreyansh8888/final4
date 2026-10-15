import 'package:json_annotation/json_annotation.dart';
part 'performance_model.g.dart';

@JsonSerializable()
class PerformanceReport {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  final double accuracy;
  final double score;
  final String grade;
  final List<String> mistakes;
  final List<String> suggestions;
  @JsonKey(name: 'step_name')
  final String stepName;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const PerformanceReport({
    required this.id,
    required this.userId,
    required this.accuracy,
    required this.score,
    required this.grade,
    required this.mistakes,
    required this.suggestions,
    required this.stepName,
    required this.createdAt,
  });

  factory PerformanceReport.fromJson(Map<String, dynamic> json) =>
      _$PerformanceReportFromJson(json);
  Map<String, dynamic> toJson() => _$PerformanceReportToJson(this);
}

/// Live analysis result returned frame-by-frame
class LiveAnalysisResult {
  final double accuracy;
  final double score;
  final List<String> mistakes;
  final List<String> suggestions;
  final String? grade;

  const LiveAnalysisResult({
    required this.accuracy,
    required this.score,
    required this.mistakes,
    required this.suggestions,
    this.grade,
  });

  factory LiveAnalysisResult.fromJson(Map<String, dynamic> json) =>
      LiveAnalysisResult(
        accuracy: (json['accuracy'] as num).toDouble(),
        score: (json['score'] as num).toDouble(),
        mistakes: List<String>.from(json['mistakes'] ?? []),
        suggestions: List<String>.from(json['suggestions'] ?? []),
        grade: json['grade'],
      );

  factory LiveAnalysisResult.empty() => const LiveAnalysisResult(
        accuracy: 0,
        score: 0,
        mistakes: [],
        suggestions: [],
      );
}
