/// 训练相关的API服务
import 'api_service.dart';
import '../models/training_models.dart';

class TrainingApi {
  /// 获取训练题目
  /// [scope] 训练范围：todayNew-今日新词, wordBook-生词本, all-全部
  /// [mode] 训练模式：choice-选择题, spelling-拼写题
  /// [count] 题目数量
  static Future<List<TrainingQuestion>> getTrainingQuestions({
    required String scope,
    required String mode,
    int count = 10,
  }) async {
    final response = await ApiService.get('/training/questions?scope=$scope&mode=$mode&count=$count');
    final data = response['data'] as List?;
    if (data == null) return [];
    
    return data.map((json) => TrainingQuestion.fromJson(json)).toList();
  }
  
  /// 提交答案
  static Future<Map<String, dynamic>> submitAnswer({
    required int wordId,
    required String userAnswer,
    required bool isCorrect,
    required int duration,
  }) async {
    return await ApiService.post('/training/submit', body: {
      'word_id': wordId,
      'user_answer': userAnswer,
      'is_correct': isCorrect,
      'duration': duration,
    });
  }
  
  /// 提交训练结果
  static Future<Map<String, dynamic>> submitTrainingResult({
    required int totalQuestions,
    required int correctCount,
    required int duration,
    required String mode,
    required String scope,
  }) async {
    return await ApiService.post('/training/result', body: {
      'total_questions': totalQuestions,
      'correct_count': correctCount,
      'duration': duration,
      'mode': mode,
      'scope': scope,
    });
  }
  
  /// 获取训练历史记录
  static Future<List<Map<String, dynamic>>> getTrainingHistory({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await ApiService.get('/training/history?page=$page&page_size=$pageSize');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 添加错题到生词本
  static Future<Map<String, dynamic>> addWrongWordToBook(int wordId) async {
    return await ApiService.post('/words/book/add', body: {'word_id': wordId});
  }
  
  /// 批量添加错题到生词本
  static Future<Map<String, dynamic>> addWrongWordsToBook(List<int> wordIds) async {
    return await ApiService.post('/words/book/add-batch', body: {'word_ids': wordIds});
  }
}
