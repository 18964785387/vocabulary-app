import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/training_models.dart';
import '../services/api_service.dart';
import '../services/training_api.dart';
import 'training_result_screen.dart';

class ChoiceTrainingScreen extends StatefulWidget {
  final TrainingConfig config;
  
  const ChoiceTrainingScreen({super.key, required this.config});

  @override
  State<ChoiceTrainingScreen> createState() => _ChoiceTrainingScreenState();
}

class _ChoiceTrainingScreenState extends State<ChoiceTrainingScreen> {
  List<TrainingQuestion> _questions = [];
  int _currentIndex = 0;
  int? _selectedAnswerIndex;
  bool _hasAnswered = false;
  bool _isLoading = true;
  String? _error;
  
  // 答题状态
  final List<QuestionResult> _results = [];
  final List<int> _wrongWordIds = [];
  DateTime? _questionStartTime;
  int _totalDuration = 0;
  
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }
  
  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      // 根据范围获取词汇
      List<Word> words = await _getWordsByScope();
      
      if (words.length < 4) {
        throw Exception('词汇数量不足，至少需要4个词汇');
      }
      
      // 生成选择题
      final questions = _generateQuestions(words, widget.config.questionCount);
      
      setState(() {
        _questions = questions;
        _isLoading = false;
        _currentIndex = 0;
        _questionStartTime = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }
  
  Future<List<Word>> _getWordsByScope() async {
    List<Map<String, dynamic>> data;
    
    switch (widget.config.scope) {
      case TrainingScope.todayNew:
        data = await ApiService.getNewWords(count: 50);
        break;
      case TrainingScope.wordBook:
        data = await ApiService.getWordBook();
        break;
      case TrainingScope.all:
        // 获取新词和复习词合并
        final newWords = await ApiService.getNewWords(count: 30);
        final reviewWords = await ApiService.getReviewWords();
        data = [...newWords, ...reviewWords];
        break;
    }
    
    return data.map((json) => Word.fromJson(json)).toList();
  }
  
  List<TrainingQuestion> _generateQuestions(List<Word> words, int count) {
    final random = Random();
    final questions = <TrainingQuestion>[];
    final usedWords = <int>{};
    
    for (int i = 0; i < count && i < words.length; i++) {
      Word word = words[i];
      while (usedWords.contains(word.id) && usedWords.length < words.length) {
        word = words[random.nextInt(words.length)];
      }
      usedWords.add(word.id);
      
      // 随机选择题目类型
      final isWordToMeaning = random.nextBool();
      
      if (isWordToMeaning) {
        // 给出单词选释义
        final options = _generateMeaningOptions(word, words);
        questions.add(TrainingQuestion(
          wordId: word.id,
          word: word.word,
          phonetic: word.phonetic,
          meaning: word.meaning,
          example: word.example,
          type: QuestionType.wordToMeaning,
          options: options,
        ));
      } else {
        // 给出释义选单词
        final options = _generateWordOptions(word, words);
        questions.add(TrainingQuestion(
          wordId: word.id,
          word: word.word,
          phonetic: word.phonetic,
          meaning: word.meaning,
          example: word.example,
          type: QuestionType.meaningToWord,
          options: options,
        ));
      }
    }
    
    return questions;
  }
  
  List<String> _generateMeaningOptions(Word correctWord, List<Word> allWords) {
    final random = Random();
    final options = <String>[correctWord.meaning];
    
    // 收集其他释义
    final otherMeanings = allWords
        .where((w) => w.id != correctWord.id)
        .map((w) => w.meaning)
        .toList()
      ..shuffle(random);
    
    // 添加干扰选项
    for (int i = 0; i < 3 && i < otherMeanings.length; i++) {
      options.add(otherMeanings[i]);
    }
    
    // 不足4个时补充
    while (options.length < 4) {
      options.add('其他释义选项${options.length}');
    }
    
    options.shuffle(random);
    return options;
  }
  
  List<String> _generateWordOptions(Word correctWord, List<Word> allWords) {
    final random = Random();
    final options = <String>[correctWord.word];
    
    // 收集其他单词
    final otherWords = allWords
        .where((w) => w.id != correctWord.id)
        .map((w) => w.word)
        .toList()
      ..shuffle(random);
    
    // 添加干扰选项
    for (int i = 0; i < 3 && i < otherWords.length; i++) {
      options.add(otherWords[i]);
    }
    
    // 不足4个时补充
    while (options.length < 4) {
      options.add('word${options.length}');
    }
    
    options.shuffle(random);
    return options;
  }
  
  void _selectAnswer(int index) {
    if (_hasAnswered) return;
    
    final question = _questions[_currentIndex];
    final userAnswer = question.options[index];
    final isCorrect = question.type == QuestionType.wordToMeaning
        ? userAnswer == question.meaning
        : userAnswer.toLowerCase() == question.word.toLowerCase();
    
    final duration = DateTime.now().difference(_questionStartTime!).inMilliseconds;
    
    setState(() {
      _selectedAnswerIndex = index;
      _hasAnswered = true;
    });
    
    // 记录结果
    _results.add(QuestionResult(
      question: question,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      duration: duration,
    ));
    
    _totalDuration += duration;
    
    // 如果答错，记录单词ID
    if (!isCorrect) {
      _wrongWordIds.add(question.wordId);
    }
    
    // 提交答案到后端
    TrainingApi.submitAnswer(
      wordId: question.wordId,
      userAnswer: userAnswer,
      isCorrect: isCorrect,
      duration: duration,
    );
    
    // 延迟后自动进入下一题
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }
  
  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedAnswerIndex = null;
        _hasAnswered = false;
        _questionStartTime = DateTime.now();
      });
    } else {
      // 训练结束
      _finishTraining();
    }
  }
  
  Future<void> _finishTraining() async {
    // 添加错题到生词本
    if (_wrongWordIds.isNotEmpty) {
      try {
        await TrainingApi.addWrongWordsToBook(_wrongWordIds);
      } catch (e) {
        debugPrint('添加错题到生词本失败: $e');
      }
    }
    
    // 提交训练结果
    try {
      await TrainingApi.submitTrainingResult(
        totalQuestions: _questions.length,
        correctCount: _results.where((r) => r.isCorrect).length,
        duration: _totalDuration,
        mode: 'choice',
        scope: widget.config.scope.name,
      );
    } catch (e) {
      debugPrint('提交训练结果失败: $e');
    }
    
    // 跳转到结果页面
    if (mounted) {
      final result = TrainingResult(
        totalQuestions: _questions.length,
        correctCount: _results.where((r) => r.isCorrect).length,
        wrongCount: _results.where((r) => !r.isCorrect).length,
        totalDuration: _totalDuration,
        results: _results,
        addedToWordBookIds: _wrongWordIds,
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TrainingResultScreen(
            result: result,
            config: widget.config,
          ),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择题训练'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitDialog(),
        ),
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载题目...'),
          ],
        ),
      );
    }
    
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loadQuestions,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }
    
    if (_questions.isEmpty) {
      return const Center(
        child: Text('暂无题目'),
      );
    }
    
    return Column(
      children: [
        // 进度条
        _buildProgressBar(),
        
        // 题目内容
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _buildQuestionCard(),
          ),
        ),
        
        // 选项
        _buildOptions(),
      ],
    );
  }
  
  Widget _buildProgressBar() {
    final progress = (_currentIndex + 1) / _questions.length;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '第 ${_currentIndex + 1} / ${_questions.length} 题',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuestionCard() {
    final question = _questions[_currentIndex];
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 单词/释义
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                question.type == QuestionType.wordToMeaning ? question.word : question.meaning,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (question.type == QuestionType.wordToMeaning && question.phonetic.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  question.phonetic,
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (question.type == QuestionType.wordToMeaning && question.example != null) ...[
                const SizedBox(height: 12),
                Text(
                  question.example!,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // 提示文字
        Text(
          question.type == QuestionType.wordToMeaning
              ? '请选择正确的释义'
              : '请选择正确的单词',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  Widget _buildOptions() {
    final question = _questions[_currentIndex];
    final correctAnswer = question.type == QuestionType.wordToMeaning
        ? question.meaning
        : question.word.toLowerCase();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            for (int i = 0; i < question.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildOptionButton(
                  index: i,
                  text: question.options[i],
                  isCorrect: question.options[i].toLowerCase() == correctAnswer.toLowerCase(),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionButton({
    required int index,
    required String text,
    required bool isCorrect,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData? icon;
    
    if (_hasAnswered) {
      if (isCorrect) {
        backgroundColor = Colors.green.withOpacity(0.1);
        borderColor = Colors.green;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
      } else if (_selectedAnswerIndex == index) {
        backgroundColor = Colors.red.withOpacity(0.1);
        borderColor = Colors.red;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
      } else {
        backgroundColor = colorScheme.surfaceContainerHighest;
        borderColor = Colors.transparent;
        textColor = colorScheme.onSurfaceVariant;
      }
    } else {
      backgroundColor = colorScheme.surfaceContainerHighest;
      borderColor = Colors.transparent;
      textColor = colorScheme.onSurface;
    }
    
    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _hasAnswered && isCorrect
                    ? Colors.green
                    : _hasAnswered && _selectedAnswerIndex == index
                        ? Colors.red
                        : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _hasAnswered
                        ? Colors.white
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: textColor,
                ),
              ),
            ),
            if (icon != null)
              Icon(icon, color: isCorrect ? Colors.green : Colors.red, size: 24),
          ],
        ),
      ),
    );
  }
  
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出训练'),
        content: const Text('确定要退出当前训练吗？进度将不会保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
  }
}

