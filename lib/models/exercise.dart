class Exercise {
  final String id;
  final String name;
  final String description;
  final int duration; // seconds
  final int reps;
  final String image;
  final String category; // 'face' or 'body'
  final String difficulty;
  final String voiceInstruction;
  final List<String> steps;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.duration,
    required this.reps,
    required this.image,
    required this.category,
    required this.difficulty,
    required this.voiceInstruction,
    this.steps = const [],
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      duration: json['duration'] as int,
      reps: json['reps'] as int,
      image: json['image'] as String,
      category: json['category'] as String,
      difficulty: json['difficulty'] as String,
      voiceInstruction: json['voiceInstruction'] as String,
      steps: List<String>.from(json['steps'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'duration': duration,
      'reps': reps,
      'image': image,
      'category': category,
      'difficulty': difficulty,
      'voiceInstruction': voiceInstruction,
      'steps': steps,
    };
  }
}
