class Challenge {
  final String id;
  final String title;
  final String description;
  final double progress;
  final double target;

  Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    double? progress,
    double? target,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      progress: progress ?? this.progress,
      target: target ?? this.target,
    );
  }
}
