import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _bindStatus;
  bool _isLoading = true;
  
  // 离线相关状态
  bool _isOnline = true;
  SyncState _syncState = SyncState.idle;
  List<Map<String, dynamic>> _downloadedLevels = [];
  int _pendingCount = 0;
  int _totalSize = 0;
  String? _syncMessage;
  
  final List<String> _gradeNames = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级', '初一', '初二', '初三', '高一', '高二', '高三'];
  
  @override
  void initState() {
    super.initState();
    _loadData();
    _initSyncService();
  }
  
  Future<void> _initSyncService() async {
    // 初始化同步服务
    await SyncService.instance.initialize();
    
    // 添加监听
    SyncService.instance.addListener(_onSyncStateChanged);
    
    // 加载同步状态
    await _loadSyncStatus();
  }
  
  void _onSyncStateChanged(bool success, String? message) {
    if (mounted) {
      setState(() {
        _syncMessage = message;
        _syncState = SyncService.instance.state;
        _isOnline = SyncService.instance.isOnline;
      });
      
      // 显示同步消息
      if (message != null && message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      // 同步完成后刷新数据
      if (SyncService.instance.state == SyncState.success) {
        _loadSyncStatus();
      }
    }
  }
  
  Future<void> _loadSyncStatus() async {
    try {
      final info = await SyncService.instance.getSyncInfo();
      if (mounted) {
        setState(() {
          _isOnline = info['isOnline'] as bool;
          _downloadedLevels = (info['downloadedLevels'] as List).cast<Map<String, dynamic>>();
          _pendingCount = info['pendingCount'] as int;
          _totalSize = info['totalDownloadSize'] as int;
        });
      }
    } catch (e) {
      // 忽略错误
    }
  }
  
  @override
  void dispose() {
    SyncService.instance.removeListener(_onSyncStateChanged);
    super.dispose();
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
      // 如果离线，使用本地数据
      if (ApiService.offlineMode) {
        try {
          final localStats = await DatabaseService.getLocalStats();
          setState(() {
            _stats = {
              'total_words': localStats['total_words'],
              'today_words': localStats['today_words'],
              'accuracy': localStats['total_records'] > 0 
                  ? (localStats['total_correct'] / localStats['total_records'] * 100).toStringAsFixed(1)
                  : '0',
            };
            _isLoading = false;
          });
        } catch (e2) {
          setState(() => _isLoading = false);
        }
      } else {
        setState(() => _isLoading = false);
      }
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
  
  /// 显示下载词库对话框
  void _showDownloadDialog() {
    showDialog(
      context: context,
      builder: (context) => _DownloadWordLevelDialog(
        onLevelSelected: _downloadWordLevel,
      ),
    );
  }
  
  /// 下载词库
  Future<void> _downloadWordLevel(int levelId, String levelName) async {
    Navigator.pop(context); // 关闭选择对话框
    
    // 显示下载进度
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('下载词库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('正在下载 $levelName...'),
          ],
        ),
      ),
    );
    
    final success = await SyncService.instance.downloadWordLevel(
      levelId: levelId,
      levelName: levelName,
    );
    
    if (mounted) {
      Navigator.pop(context); // 关闭进度对话框
      
      if (success) {
        await _loadSyncStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词库下载成功！')),
        );
      }
    }
  }
  
  /// 手动同步
  Future<void> _syncNow() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无网络连接，无法同步')),
      );
      return;
    }
    
    await SyncService.instance.fullSync();
    await _loadSyncStatus();
  }
  
  /// 显示同步详情
  void _showSyncDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('离线设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网络状态
            _buildDetailRow(
              '网络状态',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 18,
                    color: _isOnline ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(_isOnline ? '在线' : '离线'),
                ],
              ),
            ),
            const Divider(),
            
            // 已下载词库
            if (_downloadedLevels.isNotEmpty) ...[
              const Text('已下载词库:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._downloadedLevels.map((level) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(level['level_name'] as String),
                    Text(
                      '${level['word_count']}词',
                      style: TextStyle(color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              )),
              const Divider(),
            ],
            
            // 存储信息
            _buildDetailRow('本地单词数', '${await DatabaseService.getTotalWordCount()}'),
            _buildDetailRow('下载大小', _formatSize(_totalSize)),
            _buildDetailRow('待同步记录', '$_pendingCount'),
            
            if (_downloadedLevels.isEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        '点击"下载词库"下载离线数据',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (_isOnline && _pendingCount > 0)
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _syncNow();
              },
              child: const Text('立即同步'),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          if (value is Widget) value else Text(value.toString()),
        ],
      ),
    );
  }
  
  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final isOfflineData = _stats?['is_offline'] == true;
    
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
                  _buildStatsCard(isOfflineData),
                  const SizedBox(height: 16),
                  
                  // 离线设置
                  _buildOfflineCard(),
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
  
  Widget _buildStatsCard(bool isOffline) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('学习统计', style: Theme.of(context).textTheme.titleMedium),
                if (isOffline)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 14,
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '离线数据',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
  
  /// 构建离线设置卡片
  Widget _buildOfflineCard() {
    final isSyncing = _syncState == SyncState.syncing;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('离线设置', style: Theme.of(context).textTheme.titleMedium),
                // 网络状态指示
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOnline 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isOnline ? Icons.wifi : Icons.wifi_off,
                        size: 16,
                        color: _isOnline ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isOnline ? '在线' : '离线',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isOnline ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 同步状态
            if (_pendingCount > 0 || _syncMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    if (isSyncing)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        Icons.sync,
                        size: 18,
                        color: _pendingCount > 0 ? Colors.orange : Colors.green,
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_pendingCount > 0)
                            Text(
                              '待同步 $_pendingCount 条学习记录',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          if (_syncMessage != null && !isSyncing)
                            Text(
                              _syncMessage!,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (_isOnline && _pendingCount > 0 && !isSyncing)
                      TextButton(
                        onPressed: _syncNow,
                        child: const Text('同步'),
                      ),
                  ],
                ),
              ),
            
            // 下载词库按钮
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('下载词库'),
              subtitle: _downloadedLevels.isEmpty
                  ? const Text('下载后可离线学习')
                  : Text('已下载 ${_downloadedLevels.length} 个词库'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_totalSize > 0)
                    Text(
                      _formatSize(_totalSize),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: _showDownloadDialog,
              contentPadding: EdgeInsets.zero,
            ),
            
            const Divider(),
            
            // 查看同步详情
            ListTile(
              leading: const Icon(Icons.sync_alt),
              title: const Text('同步状态'),
              subtitle: Text(
                _downloadedLevels.isEmpty
                    ? '暂无已下载数据'
                    : '本地单词: ${_downloadedLevels.fold(0, (sum, l) => sum + (l['word_count'] as int))}个',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showSyncDetails,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
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
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('深色模式'),
            subtitle: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) {
                return Text(themeProvider.getThemeModeName(themeProvider.themeMode));
              },
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showThemeSelector,
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

  void _showThemeSelector() {
    final themeProvider = context.read<ThemeProvider>();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ThemeModeOption.values.map((mode) {
            return RadioListTile<ThemeModeOption>(
              title: Text(themeProvider.getThemeModeName(mode)),
              value: mode,
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
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

/// 下载词库对话框
class _DownloadWordLevelDialog extends StatefulWidget {
  final Function(int levelId, String levelName) onLevelSelected;
  
  const _DownloadWordLevelDialog({required this.onLevelSelected});

  @override
  State<_DownloadWordLevelDialog> createState() => _DownloadWordLevelDialogState();
}

class _DownloadWordLevelDialogState extends State<_DownloadWordLevelDialog> {
  List<Map<String, dynamic>> _levels = [];
  Set<int> _downloadedIds = {};
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    try {
      // 获取词库等级列表
      final levels = await ApiService.getWordLevels();
      
      // 获取已下载的等级
      final downloaded = await DatabaseService.getDownloadedLevels();
      final downloadedIds = downloaded.map((d) => d['level_id'] as int).toSet();
      
      if (mounted) {
        setState(() {
          _levels = levels;
          _downloadedIds = downloadedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载词库'),
      content: SizedBox(
        width: double.maxFinite,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _levels.isEmpty
                ? const Center(child: Text('暂无可下载的词库'))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '下载词库后在无网络时也能学习',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _levels.length,
                          itemBuilder: (context, index) {
                            final level = _levels[index];
                            final levelId = level['id'] as int;
                            final levelName = level['name'] as String;
                            final wordCount = level['word_count'] as int? ?? 0;
                            final isDownloaded = _downloadedIds.contains(levelId);
                            
                            return ListTile(
                              leading: Icon(
                                isDownloaded ? Icons.check_circle : Icons.book_outlined,
                                color: isDownloaded ? Colors.green : null,
                              ),
                              title: Text(levelName),
                              subtitle: Text('$wordCount 个单词'),
                              trailing: isDownloaded
                                  ? const Text(
                                      '已下载',
                                      style: TextStyle(color: Colors.green),
                                    )
                                  : _isDownloading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(
                                          Icons.download,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                              onTap: isDownloaded || _isDownloading
                                  ? null
                                  : () {
                                      setState(() => _isDownloading = true);
                                      widget.onLevelSelected(levelId, levelName);
                                    },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
