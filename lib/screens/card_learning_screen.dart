import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class CardLearningScreen extends StatefulWidget {
  final bool isReview;
  
  const CardLearningScreen({super.key, required this.isReview});

  @override
  State<CardLearningScreen> createState() => _CardLearningScreenState();
}

class _CardLearningScreenState extends State<CardLearningScreen> {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showMeaning = false;
  int _correctCount = 0;
  int _totalDuration = 0;
  DateTime? _startTime;
  
  late ConfettiController _confettiController;
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _loadWords();
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
  
  Future<void> _loadWords() async {
    try {
      final List<dynamic> wordsData;
      if (widget.isReview) {
        wordsData = await ApiService.getReviewWords();
      } else {
        wordsData = await ApiService.getNewWords(count: 10);
      }
      
      setState(() {
        _words = wordsData.map((e) => Word.fromJson(e)).toList();
        _isLoading = false;
        _startTime = DateTime.now();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
        Navigator.pop(context);
      }
    }
  }
  
  Future<void> _submitAnswer(bool isCorrect) async {
    if (_words.isEmpty || _currentIndex >= _words.length) return;
    
    final word = _words[_currentIndex];
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    
    try {
      await ApiService.submitLearning(
        wordId: word.id,
        isCorrect: isCorrect,
        duration: duration,
      );
      
      setState(() {
        if (isCorrect) _correctCount++;
        _totalDuration += duration;
        _currentIndex++;
        _showMeaning = false;
        _startTime = DateTime.now();
      });
      
      if (_currentIndex >= _words.length) {
        _confettiController.play();
        _showResult();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提交失败: $e')),
        );
      }
    }
  }
  
  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 学习完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('本次学习 ${_words.length} 个单词'),
            const SizedBox(height: 8),
            Text('正确 ${_correctCount} 个'),
            Text('正确率 ${(_correctCount / _words.length * 100).toStringAsFixed(1)}%'),
            Text('用时 ${(_totalDuration / 60).floor()}分${_totalDuration % 60}秒'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('返回'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _correctCount = 0;
                _totalDuration = 0;
                _showMeaning = false;
              });
              _loadWords();
            },
            child: const Text('继续学习'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReview ? '复习巩固' : '学习新词'),
        actions: [
          if (_words.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${_currentIndex + 1}/${_words.length}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
              ? _buildEmptyState()
              : _buildLearningCard(),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(widget.isReview ? '暂无待复习单词' : '暂无新词可学', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('返回')),
        ],
      ),
    );
  }
  
  Widget _buildLearningCard() {
    final word = _words[_currentIndex];
    
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: [Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              LinearProgressIndicator(value: (_currentIndex + 1) / _words.length),
              const SizedBox(height: 24),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showMeaning = !_showMeaning),
                  child: Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(word.word, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
                          if (word.phonetic.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('/${word.phonetic}/', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                          ],
                          const SizedBox(height: 24),
                          AnimatedCrossFade(
                            firstChild: Text('点击卡片查看释义', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                            secondChild: Column(
                              children: [
                                Text(word.meaning, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
                                if (word.example != null && word.example!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                                    child: Text(word.example!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                                  ),
                                ],
                              ],
                            ),
                            crossFadeState: _showMeaning ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 300),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => _submitAnswer(false),
                        style: FilledButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1), foregroundColor: Colors.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('不认识'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(onPressed: () => _submitAnswer(true), padding: const EdgeInsets.symmetric(vertical: 16), child: const Text('认识')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
