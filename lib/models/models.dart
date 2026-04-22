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
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      phone: json['phone'] as String?,
      grade: json['grade'] as int? ?? 1,
      bindCode: json['bind_code'] as String?,
      createdAt: json['created_at'] as String?,
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
  final String? rootAnalysis; // 词根词缀分析
  final String? syllables; // 音节拆分
  
  Word({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.meaning,
    this.example,
    required this.levelId,
    required this.levelName,
    this.rootAnalysis,
    this.syllables,
  });
  
  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as int? ?? 0,
      word: json['word'] as String? ?? '',
      phonetic: json['phonetic'] as String? ?? '',
      meaning: json['meaning'] as String? ?? json['definition'] as String? ?? '',
      example: json['example'] as String?,
      levelId: json['level_id'] as int? ?? json['grade_level'] as int? ?? 0,
      levelName: json['level_name'] as String? ?? '',
      rootAnalysis: json['root_analysis'] as String?,
      syllables: json['syllables'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'word': word,
    'phonetic': phonetic,
    'meaning': meaning,
    'example': example,
    'level_id': levelId,
    'level_name': levelName,
    'root_analysis': rootAnalysis,
    'syllables': syllables,
  };
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
      id: json['id'] as int? ?? json['grade_level'] as int? ?? 0,
      name: json['name'] as String? ?? json['grade_name'] as String? ?? '',
      wordCount: json['word_count'] as int? ?? 0,
      description: json['description'] as String? ?? '',
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
      id: json['id'] as int? ?? 0,
      wordId: json['word_id'] as int? ?? 0,
      word: json['word'] as String? ?? '',
      isCorrect: json['is_correct'] as bool? ?? false,
      duration: json['duration'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// 学习统计模型
class LearningStats {
  final int totalWords;
  final int todayWords;
  final int todayCorrect;
  final int streak;
  final double accuracy;
  
  LearningStats({
    required this.totalWords,
    required this.todayWords,
    required this.todayCorrect,
    required this.streak,
    required this.accuracy,
  });
  
  factory LearningStats.fromJson(Map<String, dynamic> json) {
    return LearningStats(
      totalWords: json['total_words'] as int? ?? json['total_questions'] as int? ?? 0,
      todayWords: json['today_words'] as int? ?? 0,
      todayCorrect: json['today_correct'] as int? ?? 0,
      streak: json['streak'] as int? ?? 0,
      accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// 下载的词库等级模型
class DownloadedLevel {
  final int levelId;
  final String levelName;
  final int wordCount;
  
  DownloadedLevel({
    required this.levelId,
    required this.levelName,
    required this.wordCount,
  });
  
  factory DownloadedLevel.fromJson(Map<String, dynamic> json) {
    return DownloadedLevel(
      levelId: json['level_id'] as int? ?? 0,
      levelName: json['level_name'] as String? ?? '',
      wordCount: json['word_count'] as int? ?? 0,
    );
  }
}

/// 词根词缀模型
class WordRoot {
  final String root; // 词根
  final String meaning; // 含义
  final List<String> examples; // 示例单词
  
  WordRoot({
    required this.root,
    required this.meaning,
    required this.examples,
  });
  
  factory WordRoot.fromJson(Map<String, dynamic> json) {
    return WordRoot(
      root: json['root'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      examples: (json['examples'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 音节拆分模型
class Syllable {
  final String syllable; // 音节
  final String sound; // 发音
  final bool isStressed; // 是否重读
  
  Syllable({
    required this.syllable,
    required this.sound,
    this.isStressed = false,
  });
  
  factory Syllable.fromJson(Map<String, dynamic> json) {
    return Syllable(
      syllable: json['syllable'] as String? ?? '',
      sound: json['sound'] as String? ?? '',
      isStressed: json['is_stressed'] as bool? ?? false,
    );
  }
}
