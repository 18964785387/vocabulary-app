import 'dart:async';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/tts_service.dart';
import '../models/models.dart';

class CardLearningScreenV2 extends StatefulWidget {
  final bool isReview;
  final bool isOffline;
  
  const CardLearningScreenV2({
    super.key, 
    required this.isReview,
    this.isOffline = false,
  });

  @override
  State<CardLearningScreenV2> createState() => _CardLearningScreenV2State();
}

class _CardLearningScreenV2State extends State<CardLearningScreenV2> 
    with SingleTickerProviderStateMixin {
  List<Word> _words = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _showMeaning = false;
  bool _showRootAnalysis = false; // 显示词根词缀
  bool _showSyllables = false; // 显示音节拆分
  int _correctCount = 0;
  int _totalDuration = 0;
  DateTime? _startTime;
  bool _isSubmitting = false;
  
  late ConfettiController _confettiController;
  final TtsService _ttsService = TtsService();
  late AnimationController _cardFlipController;
  late Animation<double> _cardFlipAnimation;
  
  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    _cardFlipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _cardFlipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardFlipController, curve: Curves.easeInOut),
    );
    
    _initTts();
    _loadWords();
  }
  
  Future<void> _initTts() async {
    await _ttsService.init();
    if (mounted) setState(() {});
  }
  
  @override
  void dispose() {
    _confettiController.dispose();
    _cardFlipController.dispose();
    super.dispose();
  }
  
  Future<void> _loadWords() async {
    try {
      final List<dynamic> wordsData;
      
      if (widget.isOffline) {
        if (widget.isReview) {
          final localWords = await DatabaseService.getLocalReviewWords(count: 10);
          wordsData = localWords;
        } else {
          final localWords = await DatabaseService.getLocalNewWords(count: 10);
          wordsData = localWords;
        }
      } else {
        if (widget.isReview) {
          wordsData = await ApiService.getReviewWords();
        } else {
          wordsData = await ApiService.getNewWords(count: 10);
        }
      }
      
      setState(() {
        _words = wordsData.map((e) => Word.fromJson(e)).toList();
        _isLoading = false;
        _startTime = DateTime.now();
      });
      
      if (_words.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isReview ? '暂无复习单词' : '暂无新词可学'),
          ),
        );
        Navigator.pop(context);
      }
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
    if (_words.isEmpty || _currentIndex >= _words.length || _isSubmitting) return;
    
    final word = _words[_currentIndex];
    final duration = DateTime.now().difference(_startTime!).inSeconds;
    
    setState(() => _isSubmitting = true);
    
    try {
      if (widget.isOffline) {
        await DatabaseService.saveLearningRecord(
          wordId: word.id,
          isCorrect: isCorrect,
          duration: duration,
        );
      } else {
        await ApiService.submitLearning(
          wordId: word.id,
          isCorrect: isCorrect,
          duration: duration,
        );
      }
      
      if (mounted) {
        setState(() {
          if (isCorrect) _correctCount++;
          _totalDuration += duration;
          _currentIndex++;
          _showMeaning = false;
          _showRootAnalysis = false;
          _showSyllables = false;
          _cardFlipController.reset();
          _startTime = DateTime.now();
          _isSubmitting = false;
        });
        
        if (_currentIndex >= _words.length) {
          _confettiController.play();
          _showResult();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        await DatabaseService.saveLearningRecord(
          wordId: word.id,
          isCorrect: isCorrect,
          duration: duration,
        );
        setState(() {
          if (isCorrect) _correctCount++;
          _currentIndex++;
          _showMeaning = false;
          _cardFlipController.reset();
          _startTime = DateTime.now();
        });
        
        if (_currentIndex >= _words.length) {
          _showResult();
        }
      }
    }
  }
  
  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 学习完成！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('学习单词: ${_words.length}个'),
            Text('正确: $_correctCount个'),
            Text('正确率: ${(_correctCount / _words.length * 100).toStringAsFixed(1)}%'),
            Text('用时: ${(_totalDuration / 60).floor()}分${_totalDuration % 60}秒'),
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
        ],
      ),
    );
  }
  
  Future<void> _addToWordBook() async {
    if (_words.isEmpty || _currentIndex >= _words.length) return;
    
    final word = _words[_currentIndex];
    
    try {
      await ApiService.addToWordBook(word.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已添加到生词本')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    }
  }
  
  void _flipCard() {
    if (_showMeaning) {
      _cardFlipController.reverse();
    } else {
      _cardFlipController.forward();
    }
    setState(() => _showMeaning = !_showMeaning);
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isReview ? '复习单词' : '学习新词')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_words.isEmpty || _currentIndex >= _words.length) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.isReview ? '复习单词' : '学习新词')),
        body: const Center(child: Text('没有更多单词了')),
      );
    }
    
    final word = _words[_currentIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isReview ? '复习单词' : '学习新词'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _ttsService.speak(word.word),
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add),
            onPressed: _addToWordBook,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 进度条
              LinearProgressIndicator(
                value: (_currentIndex + 1) / _words.length,
                backgroundColor: Colors.grey[200],
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${_currentIndex + 1} / ${_words.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              
              // 单词卡片
              Expanded(
                child: GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _cardFlipAnimation,
                    builder: (context, child) {
                      final angle = _cardFlipAnimation.value * 3.14159;
                      final transform = Matrix4.identity()
                        ..setEntry(0, 2, 0.001)
                        ..rotateY(angle);
                      
                      return Transform(
                        transform: transform,
                        alignment: Alignment.center,
                        child: angle > 1.57 ? Transform(
                          transform: Matrix4.identity()..rotateY(3.14159),
                          alignment: Alignment.center,
                          child: _buildBackCard(word),
                        ) : _buildFrontCard(word),
                      );
                    },
                  ),
                ),
              ),
              
              // 词根词缀分析按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.account_tree),
                        label: const Text('词根词缀'),
                        onPressed: () {
                          setState(() => _showRootAnalysis = !_showRootAnalysis);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('音节拆分'),
                        onPressed: () {
                          setState(() => _showSyllables = !_showSyllables);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // 词根词缀/音节显示
              if (_showRootAnalysis || _showSyllables)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _showRootAnalysis 
                    ? _buildRootAnalysis(word)
                    : _buildSyllables(word),
                ),
              
              // 操作按钮
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[100],
                          foregroundColor: Colors.red,
                        ),
                        onPressed: _isSubmitting ? null : () => _submitAnswer(false),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('不认识'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[100],
                          foregroundColor: Colors.green,
                        ),
                        onPressed: _isSubmitting ? null : () => _submitAnswer(true),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('认识'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 庆祝动画
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.green,
                Colors.blue,
                Colors.pink,
                Colors.orange,
                Colors.purple,
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFrontCard(Word word) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              word.word,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              word.phonetic,
              style: TextStyle(
                fontSize: 24,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              '点击卡片查看释义',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBackCard(Word word) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                word.word,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                word.phonetic,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  word.meaning,
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                ),
              ),
              if (word.example != null && word.example!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    word.example!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[700],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRootAnalysis(Word word) {
    // 如果单词有词根分析数据，显示它
    // 否则显示通用的词根词缀提示
    if (word.rootAnalysis != null && word.rootAnalysis!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '词根词缀分析',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(word.rootAnalysis!),
        ],
      );
    }
    
    // 通用词根词缀提示
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '词根词缀分析',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Text(
          _generateRootAnalysis(word.word),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }
  
  Widget _buildSyllables(Word word) {
    // 如果单词有音节拆分数据，显示它
    if (word.syllables != null && word.syllables!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '音节拆分',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _buildSyllableWidgets(word.syllables!),
          ),
        ],
      );
    }
    
    // 自动生成音节拆分
    final syllables = _generateSyllables(word.word);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '音节拆分',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildSyllableWidgets(syllables),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.volume_up),
            label: const Text('逐音节朗读'),
            onPressed: () => _speakSyllables(syllables),
          ),
        ),
      ],
    );
  }
  
  List<Widget> _buildSyllableWidgets(String syllables) {
    final parts = syllables.split('-');
    return parts.asMap().entries.map((entry) {
      final index = entry.key;
      final syllable = entry.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (index > 0)
            Container(
              width: 1,
              height: 40,
              color: Colors.blue[300],
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              syllable,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
  
  // 简单的音节拆分算法（英语）
  String _generateSyllables(String word) {
    if (word.length <= 3) return word;
    
    final vowels = {'a', 'e', 'i', 'o', 'u', 'y'};
    final syllables = <String>[];
    var currentSyllable = '';
    
    for (var i = 0; i < word.length; i++) {
      final char = word[i].toLowerCase();
      currentSyllable += word[i];
      
      // 如果当前字符是元音，下一个是辅音，再下一个是元音，则在此处拆分
      if (i < word.length - 2 &&
          vowels.contains(char) &&
          !vowels.contains(word[i + 1].toLowerCase()) &&
          vowels.contains(word[i + 2].toLowerCase())) {
        syllables.add(currentSyllable);
        currentSyllable = '';
      }
    }
    
    if (currentSyllable.isNotEmpty) {
      syllables.add(currentSyllable);
    }
    
    return syllables.isEmpty ? word : syllables.join('-');
  }
  
  // 简单的词根词缀分析
  String _generateRootAnalysis(String word) {
    final lowerWord = word.toLowerCase();
    
    // 常见前缀
    final prefixes = {
      'un': '不、非',
      're': '重新',
      'pre': '在...之前',
      'dis': '不、分离',
      'mis': '错误地',
      'over': '过度',
      'out': '超出',
      'sub': '在下面',
      'trans': '跨越、转移',
      'inter': '在...之间',
    };
    
    // 常见后缀
    final suffixes = {
      'tion': '名词后缀，表示行为或结果',
      'sion': '名词后缀，表示行为或结果',
      'ment': '名词后缀，表示行为或结果',
      'ness': '名词后缀，表示状态或性质',
      'able': '形容词后缀，表示可...的',
      'ible': '形容词后缀，表示可...的',
      'ful': '形容词后缀，表示充满...的',
      'less': '形容词后缀，表示无...的',
      'ly': '副词后缀',
      'er': '名词后缀，表示人或物',
      'or': '名词后缀，表示人或物',
      'ing': '现在分词/动名词',
      'ed': '过去式/过去分词',
    };
    
    // 检查前缀
    for (final entry in prefixes.entries) {
      if (lowerWord.startsWith(entry.key) && lowerWord.length > entry.key.length + 2) {
        final root = word.substring(entry.key.length);
        return '前缀 "${entry.key}" (${entry.value}) + 词根 "$root"';
      }
    }
    
    // 检查后缀
    for (final entry in suffixes.entries) {
      if (lowerWord.endsWith(entry.key) && lowerWord.length > entry.key.length + 2) {
        final root = word.substring(0, word.length - entry.key.length);
        return '词根 "$root" + 后缀 "${entry.key}" (${entry.value})';
      }
    }
    
    return '该单词暂无明显的词根词缀结构';
  }
  
  // 逐音节朗读
  Future<void> _speakSyllables(String syllables) async {
    final parts = syllables.split('-');
    for (final part in parts) {
      await _ttsService.speak(part);
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
