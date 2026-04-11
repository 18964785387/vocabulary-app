/// 用户模型
class User {
  final int id;
  final String username;
  final String? phone;
  final int grade;
  final String? bindCode;
  final String? createdAt;
  
  User({
    required this.id,
    required this.username,
    this.phone,
    required this.grade,
    this.bindCode,
    this.createdAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      phone: json['phone'],
      grade: json['grade'] ?? 1,
      bindCode: json['bind_code'],
      createdAt: json['created_at'],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'phone': phone,
    'grade': grade,
    'bind_code': bindCode,
    'created_at': createdAt,
  };
}

/// 单词模型
class Word {
  final int id;
  final String word;
  final String phonetic;
  final String meaning;
  final String? example;
  final int levelId;
  final String levelName;
  
  Word({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.meaning,
    this.example,
    required this.levelId,
    required this.levelName,
  });
  
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'],
      word: json['word'],
      phonetic: json['phonetic'] ?? '',
      meaning: json['meaning'],
      example: json['example'],
      levelId: json['level_id'],
      levelName: json['level_name'] ?? '',
    );
  }
}

/// 词库等级模型
class WordLevel {
  final int id;
  final String name;
  final int wordCount;
  final String description;
  
  WordLevel({
    required this.id,
    required this.name,
    required this.wordCount,
    required this.description,
  });
  
  factory WordLevel.fromJson(Map<String, dynamic> json) {
    return WordLevel(
      id: json['id'],
      name: json['name'],
      wordCount: json['word_count'],
      description: json['description'] ?? '',
    );
  }
}

/// 学习记录模型
class LearningRecord {
  final int id;
  final int wordId;
  final String word;
  final bool isCorrect;
  final int duration;
  final DateTime createdAt;
  
  LearningRecord({
    required this.id,
    required this.wordId,
    required this.word,
    required this.isCorrect,
    required this.duration,
    required this.createdAt,
  });
  
  factory LearningRecord.fromJson(Map<String, dynamic> json) {
    return LearningRecord(
      id: json['id'],
      wordId: json['word_id'],
      word: json['word'],
      isCorrect: json['is_correct'],
      duration: json['duration'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// 学习统计模型
class LearningStats {
  final int totalWords;
  final int todayWords;
  final int todayCorrect;
  final int todayDuration;
  final double accuracy;
  final int streak;
  
  LearningStats({
    required this.totalWords,
    required this.todayWords,
    required this.todayCorrect,
    required this.todayDuration,
    required this.accuracy,
    required this.streak,
  });
  
  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      totalWords: json['total_words'] ?? 0,
      todayWords: json['today_words'] ?? 0,
      todayCorrect: json['today_correct'] ?? 0,
      todayDuration: json['today_duration'] ?? 0,
      accuracy: (json['accuracy'] ?? 0).toDouble(),
      streak: json['streak'] ?? 0,
    );
  }
}
