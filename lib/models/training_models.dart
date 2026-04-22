/// 训练相关的数据模型

/// 训练模式枚举
enum TrainingMode {
  choice,    // 选择题模式
  spelling,  // 拼写题模式
}

/// 训练范围枚举
enum TrainingScope {
  todayNew,    // 今日新词
  wordBook,   // 生词本
  all,        // 全部
}

/// 训练题目模型
class TrainingQuestion {
  final int wordId;
  final String word;
  final String phonetic;
  final String meaning;
  final String? example;
  final QuestionType type;
  final List<String> options;  // 选择题选项（包含正确答案）
  
  TrainingQuestion({
    required this.wordId,
    required this.word,
    required this.phonetic,
    required this.meaning,
    this.example,
    required this.type,
    required this.options,
  });
  
  factory TrainingQuestion.fromJson(Map<String, dynamic> json) {
    return TrainingQuestion(
      wordId: json['word_id'],
      word: json['word'],
      phonetic: json['phonetic'] ?? '',
      meaning: json['meaning'],
      example: json['example'],
      type: QuestionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => QuestionType.wordToMeaning,
      ),
      options: (json['options'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// 题目类型枚举
enum QuestionType {
  wordToMeaning,  // 给出单词选择释义
  meaningToWord, // 给出释义选择单词
  spelling,       // 拼写题（给出释义拼写单词）
}

/// 单个题目答案结果
class QuestionResult {
  final TrainingQuestion question;
  final String userAnswer;
  final bool isCorrect;
  final int duration;  // 回答用时（毫秒）
  
  QuestionResult({
    required this.question,
    required this.userAnswer,
    required this.isCorrect,
    required this.duration,
  });
}

/// 训练会话配置
class TrainingConfig {
  final TrainingMode mode;
  final TrainingScope scope;
  final int questionCount;
  
  TrainingConfig({
    required this.mode,
    required this.scope,
    required this.questionCount,
  });
  
  String get modeName => mode == TrainingMode.choice ? '选择题' : '拼写题';
  
  String get scopeName {
    switch (scope) {
      case TrainingScope.todayNew:
        return '今日新词';
      case TrainingScope.wordBook:
        return '生词本';
      case TrainingScope.all:
        return '全部词汇';
    }
  }
}

/// 训练结果模型
class TrainingResult {
  final int totalQuestions;
  final int correctCount;
  final int wrongCount;
  final int totalDuration;  // 总用时（毫秒）
  final List<QuestionResult> results;
  final List<int> addedToWordBookIds;  // 错题加入生词本的单词ID
  
  TrainingResult({
    required this.totalQuestions,
    required this.correctCount,
    required this.wrongCount,
    required this.totalDuration,
    required this.results,
    required this.addedToWordBookIds,
  });
  
  double get accuracy => totalQuestions > 0 ? correctCount / totalQuestions * 100 : 0;
  
  String get durationFormatted {
    final seconds = totalDuration ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '${minutes}分${remainingSeconds}秒';
    }
    return '${remainingSeconds}秒';
  }
}
