import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../models/models.dart';
import 'card_learning_screen.dart';
import 'training_screen.dart';

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
  bool _isOffline = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      // 先检查网络状态
      final isOnline = await SyncService.instance.checkConnectivity() == ConnectionStatus.online;
      
      if (isOnline) {
        // 在线模式：从服务器获取
        final summary = await ApiService.getLearningSummary();
        final levels = await ApiService.getWordLevels();
        
        setState(() {
          _summary = summary;
          _levels = levels.map((e) => WordLevel.fromJson(e)).toList();
          _currentLevelId = summary['current_level_id'] ?? 1;
          _isLoading = false;
          _isOffline = false;
        });
      } else {
        // 离线模式：从本地获取
        await _loadOfflineData();
      }
    } catch (e) {
      // 网络请求失败，尝试离线
      if (ApiService.offlineMode || e.toString().contains('OfflineException')) {
        await _loadOfflineData();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('加载失败: $e')),
          );
        }
      }
    }
  }
  
  /// 加载离线数据
  Future<void> _loadOfflineData() async {
    try {
      // 检查是否有已下载的词库
      final downloadedLevels = await DatabaseService.getDownloadedLevels();
      
      if (downloadedLevels.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无网络且未下载词库，请先下载词库'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() {
          _isLoading = false;
          _isOffline = true;
        });
        return;
      }
      
      // 获取本地统计
      final localStats = await DatabaseService.getLocalStats();
      final currentLevelId = await DatabaseService.getCurrentLevelId();
      
      // 转换已下载的等级为WordLevel对象
      final levels = downloadedLevels.map((e) => WordLevel(
        id: e['level_id'] as int? ?? 0,
        name: e['level_name'] as String? ?? '',
        wordCount: e['word_count'] as int? ?? 0,
        description: '',
      )).toList();
      
      setState(() {
        _summary = {
          'today_words': localStats['today_words'] as int? ?? 0,
          'today_correct': localStats['today_correct'] as int? ?? 0,
          'today_duration': 0,
          'review_count': (localStats['today_words'] as int? ?? 0) > 0 ? localStats['today_words'] as int? ?? 0 : 10,
        };
        _levels = levels;
        _currentLevelId = currentLevelId ?? (levels.isNotEmpty ? levels.first.id : 1);
        _isLoading = false;
        _isOffline = true;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isOffline = true;
      });
    }
  }
  
  Future<void> _switchLevel(int levelId) async {
    if (_isOffline) {
      // 离线模式直接切换
      await DatabaseService.setCurrentLevelId(levelId);
      setState(() => _currentLevelId = levelId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词库切换成功')),
        );
      }
      return;
    }
    
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
        builder: (_) => CardLearningScreenV2(isReview: isReview, isOffline: _isOffline),
      ),
    ).then((_) => _loadData());
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('背单词'),
            if (_isOffline) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: Colors.orange),
                    SizedBox(width: 4),
                    Text(
                      '离线',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _levels.isEmpty && _isOffline
              ? _buildNoDataView()
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
                        if (_levels.isNotEmpty) ...[
                          _buildLevelSelector(),
                          const SizedBox(height: 24),
                        ],
                        
                        // 学习入口
                        _buildLearningButtons(),
                        const SizedBox(height: 24),
                        
                        // 学习建议
                        if (!_isOffline) _buildTips(),
                        
                        // 离线提示
                        if (_isOffline) _buildOfflineTip(),
                      ],
                    ),
                  ),
                ),
    );
  }
  
  /// 无数据视图
  Widget _buildNoDataView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              '暂无离线数据',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              '请在设置页面下载词库后\n即可在无网络时学习',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                // 跳转到设置页面
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              icon: const Icon(Icons.download),
              label: const Text('去下载词库'),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 离线模式提示
  Widget _buildOfflineTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                '离线学习模式',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• 学习记录将在联网后自动同步\n• 请注意及时同步以保存学习进度',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
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
        
        const SizedBox(height: 16),
        
        // 巩固训练入口
        _buildTrainingCard(),
      ],
    );
  }
  
  void _startTraining() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TrainingScreen(),
      ),
    ).then((_) => _loadData());
  }
  
  Widget _buildTrainingCard() {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer.withOpacity(0.3),
      child: InkWell(
        onTap: _startTraining,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  color: Theme.of(context).colorScheme.tertiary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '巩固训练',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '选择题和拼写题强化训练',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLearningCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Card(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? null : Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: enabled ? null : Theme.of(context).colorScheme.outline,
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
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '学习建议',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 建议每天学习20-30个新单词\n• 复习已学单词可加深记忆\n• 选择题训练有助于词汇巩固',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
