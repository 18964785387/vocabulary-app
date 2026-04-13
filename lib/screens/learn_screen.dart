import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import 'card_learning_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  Map<String, dynamic>? _summary;
  List<WordLevel> _levels = [];
  int? _currentLevelId;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      final summary = await ApiService.getLearningSummary();
      final levels = await ApiService.getWordLevels();
      
      setState(() {
        _summary = summary;
        _levels = levels.map((e) => WordLevel.fromJson(e)).toList();
        _currentLevelId = summary['current_level_id'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }
  
  Future<void> _switchLevel(int levelId) async {
    try {
      await ApiService.switchLevel(levelId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词库切换成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('切换失败: $e')),
        );
      }
    }
  }
  
  void _startLearning(bool isReview) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CardLearningScreen(isReview: isReview),
      ),
    ).then((_) => _loadData());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('疯狂背单词'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 今日学习统计
                    _buildTodayStats(),
                    const SizedBox(height: 24),
                    
                    // 词库选择
                    _buildLevelSelector(),
                    const SizedBox(height: 24),
                    
                    // 学习入口
                    _buildLearningButtons(),
                    const SizedBox(height: 24),
                    
                    // 学习建议
                    _buildTips(),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildTodayStats() {
    final todayWords = _summary?['today_words'] ?? 0;
    final todayCorrect = _summary?['today_correct'] ?? 0;
    final todayDuration = _summary?['today_duration'] ?? 0;
    final streak = _summary?['streak'] ?? 0;
    final accuracy = todayWords > 0 ? (todayCorrect / todayWords * 100).toStringAsFixed(1) : '0';
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('今日学习', style: Theme.of(context).textTheme.titleMedium),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('$streak天', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem('已学', '$todayWords', '词'),
                _buildStatItem('正确率', '$accuracy', '%'),
                _buildStatItem('时长', '${(todayDuration / 60).floor()}', '分钟'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            '$label ($unit)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
  
  Widget _buildLevelSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('词库选择', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _levels.length,
            itemBuilder: (context, index) {
              final level = _levels[index];
              final isSelected = level.id == _currentLevelId;
              
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => _switchLevel(level.id),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          level.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${level.wordCount}词',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildLearningButtons() {
    final reviewCount = _summary?['review_count'] ?? 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('开始学习', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildLearningCard(
                icon: Icons.add_circle_outline,
                title: '学习新词',
                subtitle: '开始今日新词学习',
                color: Colors.blue,
                onTap: () => _startLearning(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLearningCard(
                icon: Icons.replay,
                title: '复习巩固',
                subtitle: reviewCount > 0 ? '$reviewCount个单词待复习' : '暂无待复习单词',
                color: Colors.orange,
                enabled: reviewCount > 0,
                onTap: reviewCount > 0 ? () => _startLearning(true) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildLearningCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Card(
      color: enabled ? null : Theme.of(context).disabledColor.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(enabled ? 0.1 : 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: enabled ? color : Colors.grey, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? null : Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: enabled ? null : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTips() {
    return Card(
      color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text('学习小贴士', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 每天坚持学习，养成好习惯\n'
              '• 及时复习，加深记忆\n'
              '• 生词本多看多记，攻克难点',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
