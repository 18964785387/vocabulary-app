import 'package:flutter/material.dart';
import '../models/training_models.dart';
import 'choice_training_screen.dart';
import 'spelling_training_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  TrainingMode _selectedMode = TrainingMode.choice;
  TrainingScope _selectedScope = TrainingScope.todayNew;
  int _questionCount = 10;
  
  final Map<TrainingScope, String> _scopeLabels = {
    TrainingScope.todayNew: '今日新词',
    TrainingScope.wordBook: '生词本',
    TrainingScope.all: '全部词汇',
  };
  
  final Map<TrainingScope, String> _scopeApiValues = {
    TrainingScope.todayNew: 'todayNew',
    TrainingScope.wordBook: 'wordBook',
    TrainingScope.all: 'all',
  };
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('巩固训练'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 训练模式选择
            _buildSectionTitle('选择训练模式'),
            const SizedBox(height: 12),
            _buildModeSelector(),
            const SizedBox(height: 28),
            
            // 训练范围选择
            _buildSectionTitle('选择训练范围'),
            const SizedBox(height: 12),
            _buildScopeSelector(),
            const SizedBox(height: 28),
            
            // 题目数量选择
            _buildSectionTitle('题目数量'),
            const SizedBox(height: 12),
            _buildCountSelector(),
            const SizedBox(height: 40),
            
            // 开始训练按钮
            _buildStartButton(),
            const SizedBox(height: 20),
            
            // 训练说明
            _buildInstructions(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  Widget _buildModeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildModeCard(
            mode: TrainingMode.choice,
            icon: Icons.check_circle_outline,
            title: '选择题',
            subtitle: '选择正确释义',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildModeCard(
            mode: TrainingMode.spelling,
            icon: Icons.edit_outlined,
            title: '拼写题',
            subtitle: '拼写单词',
          ),
        ),
      ],
    );
  }
  
  Widget _buildModeCard({
    required TrainingMode mode,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 40,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? colorScheme.primary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildScopeSelector() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: TrainingScope.values.map((scope) {
        final isSelected = _selectedScope == scope;
        final colorScheme = Theme.of(context).colorScheme;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedScope = scope),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
            ),
            child: Text(
              _scopeLabels[scope] ?? '',
              style: TextStyle(
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildCountSelector() {
    final counts = [10, 20, 30];
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: counts.map((count) {
        final isSelected = _questionCount == count;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: count == 10 ? 0 : 8,
              right: count == 30 ? 0 : 8,
            ),
            child: GestureDetector(
              onTap: () => setState(() => _questionCount = count),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      '题',
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? colorScheme.onPrimary.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildStartButton() {
    return FilledButton.icon(
      onPressed: _startTraining,
      icon: const Icon(Icons.play_arrow_rounded),
      label: const Text(
        '开始训练',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
  
  Widget _buildInstructions() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                '训练说明',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionItem('1. 选择题模式：给出单词选择正确释义，或给出释义选择正确单词'),
          const SizedBox(height: 6),
          _buildInstructionItem('2. 拼写题模式：给出释义，输入正确的单词拼写'),
          const SizedBox(height: 6),
          _buildInstructionItem('3. 拼写题支持大小写不敏感'),
          const SizedBox(height: 6),
          _buildInstructionItem('4. 答错的题目会自动加入生词本'),
        ],
      ),
    );
  }
  
  Widget _buildInstructionItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
  
  void _startTraining() {
    final config = TrainingConfig(
      mode: _selectedMode,
      scope: _selectedScope,
      questionCount: _questionCount,
    );
    
    Widget screen;
    if (_selectedMode == TrainingMode.choice) {
      screen = ChoiceTrainingScreen(config: config);
    } else {
      screen = SpellingTrainingScreen(config: config);
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}
