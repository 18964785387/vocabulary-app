import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _bindStatus;
  bool _isLoading = true;
  
  final List<String> _gradeNames = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级', '初一', '初二', '初三', '高一', '高二', '高三'];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      final stats = await ApiService.getLearningStats();
      final bindStatus = await ApiService.getBindStatus();
      setState(() {
        _stats = stats;
        _bindStatus = bindStatus;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _showBindCode() async {
    try {
      final result = await ApiService.getBindCode();
      final bindCode = result['bind_code'];
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('家长绑定码'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('让家长扫描下方二维码或在微信公众号输入绑定码：'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bindCode,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('绑定码30天内有效', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // 复制到剪贴板
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('绑定码已复制')),
                  );
                },
                child: const Text('复制'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取绑定码失败: $e')),
        );
      }
    }
  }
  
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('确定')),
        ],
      ),
    );
    
    if (confirmed == true && mounted) {
      await context.read<UserProvider>().logout();
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 用户信息卡片
                  _buildUserCard(user),
                  const SizedBox(height: 16),
                  
                  // 学习统计
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  
                  // 功能菜单
                  _buildMenuCard(),
                ],
              ),
            ),
    );
  }
  
  Widget _buildUserCard(user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                user?.username.substring(0, 1).toUpperCase() ?? 'U',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.username ?? '未知用户', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    user?.phone ?? '未绑定手机',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      user?.grade != null ? _gradeNames[user!.grade - 1] : '未设置年级',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditProfile(user)),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatsCard() {
    final totalWords = _stats?['total_words'] ?? 0;
    final streak = _stats?['streak'] ?? 0;
    final accuracy = (_stats?['accuracy'] ?? 0).toStringAsFixed(1);
    final totalDuration = _stats?['total_duration'] ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学习统计', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatItem(Icons.menu_book, '已学单词', '$totalWords'),
                _buildStatItem(Icons.local_fire_department, '连续天数', '$streak'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatItem(Icons.check_circle, '正确率', '$accuracy%'),
                _buildStatItem(Icons.access_time, '学习时长', '${(totalDuration / 60).floor()}分'),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(IconData icon, String label, String value) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuCard() {
    final isBound = _bindStatus?['is_bound'] ?? false;
    final parentName = _bindStatus?['parent_name'];
    
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.family_restroom),
            title: const Text('家长绑定'),
            subtitle: Text(isBound ? '已绑定: $parentName' : '未绑定'),
            trailing: isBound ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: isBound ? null : _showBindCode,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('设置功能开发中'))),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
            title: Text('退出登录', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }
  
  void _showEditProfile(user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑资料'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('功能开发中，敬请期待', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定')),
        ],
      ),
    );
  }
}
