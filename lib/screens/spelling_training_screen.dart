import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/training_models.dart';
import '../models/models.dart' show Word;
import '../services/api_service.dart';
import '../services/training_api.dart';
import 'training_result_screen.dart';

class SpellingTrainingScreen extends StatefulWidget {
  final TrainingConfig config;
  
  const SpellingTrainingScreen({super.key, required this.config});

  @override
  State<SpellingTrainingScreen> createState() => _SpellingTrainingScreenState();
}

class _SpellingTrainingScreenState extends State<SpellingTrainingScreen> {
  final TextEditingController _answerController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<TrainingQuestion> _questions = [];
  int _currentIndex = 0;
  bool _hasAnswered = false;
  bool _isCorrect = false;
  bool _isLoading = true;
  String? _error;
  String _userAnswer = '';
  
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
  
  @override
  void dispose() {
    _answerController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
  
  Future<void> _loadQuestions() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      // 根据范围获取词汇
      List<Word> words = await _getWordsByScope();
      
      if (words.isEmpty) {
        throw Exception('词汇数量不足');
      }
      
      // 生成拼写题
      final questions = _generateQuestions(words, widget.config.questionCount);
      
      setState(() {
        _questions = questions;
        _isLoading = false;
        _currentIndex = 0;
        _questionStartTime = DateTime.now();
      });
      
      // 自动弹出键盘
      Future.delayed(const Duration(milliseconds: 300), () {
        _focusNode.requestFocus();
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
        final newWords = await ApiService.getNewWords(count: 30);
        final reviewWords = await ApiService.getReviewWords();
        data = [...newWords, ...reviewWords];
        break;
    }
    
    return data.map((json) => Word.fromJson(json)).toList();
  }
  
  List<TrainingQuestion> _generateQuestions(List<Word> words, int count) {
    final random = DateTime.now().millisecondsSinceEpoch;
    final usedWords = <int>{};
    final questions = <TrainingQuestion>[];
    
    for (int i = 0; i < count && i < words.length; i++) {
      Word word = words[i];
      while (usedWords.contains(word.id) && usedWords.length < words.length) {
        word = words[(i * 7 + random) % words.length];
      }
      usedWords.add(word.id);
      
      questions.add(TrainingQuestion(
        wordId: word.id,
        word: word.word,
        phonetic: word.phonetic,
        meaning: word.meaning,
        example: word.example,
        type: QuestionType.spelling,
        options: [],
      ));
    }
    
    return questions;
  }
  
  void _submitAnswer() {
    if (_hasAnswered || _userAnswer.isEmpty) return;
    
    final question = _questions[_currentIndex];
    // 大小写不敏感比较
    final isCorrect = _userAnswer.trim().toLowerCase() == question.word.toLowerCase();
    
    final duration = DateTime.now().difference(_questionStartTime!).inMilliseconds;
    
    setState(() {
      _hasAnswered = true;
      _isCorrect = isCorrect;
    });
    
    // 记录结果
    _results.add(QuestionResult(
      question: question,
      userAnswer: _userAnswer,
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
      userAnswer: _userAnswer,
      isCorrect: isCorrect,
      duration: duration,
    );
    
    // 延迟后自动进入下一题
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }
  
  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _hasAnswered = false;
        _isCorrect = false;
        _userAnswer = '';
        _questionStartTime = DateTime.now();
      });
      
      _answerController.clear();
      
      Future.delayed(const Duration(milliseconds: 300), () {
        _focusNode.requestFocus();
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
        mode: 'spelling',
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
        title: const Text('拼写训练'),
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
        
        // 输入区域
        _buildInputArea(),
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
        // 提示图标
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.translate,
            size: 30,
            color: colorScheme.primary,
          ),
        ),
        
        const SizedBox(height: 20),
        
        // 释义
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                '请拼写这个单词',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                question.meaning,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        // 例句
        if (question.example != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    question.example!,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        
        // 音标提示
        if (question.phonetic.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '[ ${question.phonetic} ]',
            style: TextStyle(
              fontSize: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        
        // 反馈区域
        if (_hasAnswered) ...[
          const SizedBox(height: 20),
          _buildFeedback(),
        ],
      ],
    );
  }
  
  Widget _buildFeedback() {
    final colorScheme = Theme.of(context).colorScheme;
    final question = _questions[_currentIndex];
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isCorrect 
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isCorrect ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isCorrect ? Icons.check_circle : Icons.cancel,
                color: _isCorrect ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _isCorrect ? '回答正确！' : '回答错误',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _isCorrect ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          if (!_isCorrect) ...[
            const SizedBox(height: 12),
            Text(
              '正确答案: ${question.word}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            if (_userAnswer.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '你的答案: $_userAnswer',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red.shade700,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  Widget _buildInputArea() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
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
            // 输入框
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: _hasAnswered
                    ? Border.all(
                        color: _isCorrect ? Colors.green : Colors.red,
                        width: 2,
                      )
                    : null,
              ),
              child: TextField(
                controller: _answerController,
                focusNode: _focusNode,
                enabled: !_hasAnswered,
                autofocus: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
                decoration: InputDecoration(
                  hintText: '请输入单词',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                ],
                onChanged: (value) {
                  setState(() => _userAnswer = value);
                },
                onSubmitted: (_) => _submitAnswer(),
                textInputAction: TextInputAction.done,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // 提交按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hasAnswered || _userAnswer.isEmpty
                    ? null
                    : _submitAnswer,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '确认提交',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
