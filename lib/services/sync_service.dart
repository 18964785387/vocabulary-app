/// 数据同步服务
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';
import 'api_service.dart';

/// 同步状态枚举
enum SyncState {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// 网络连接状态
enum ConnectionStatus {
  online,
  offline,
}

/// 同步结果回调
typedef SyncCallback = void Function(bool success, String? message);

class SyncService {
  static SyncService? _instance;
  static SyncService get instance => _instance ??= SyncService._();
  SyncService._();

  // 状态
  SyncState _state = SyncState.idle;
  ConnectionStatus _connectionStatus = ConnectionStatus.offline;
  DateTime? _lastSyncTime;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _autoSyncTimer;

  // 回调
  final List<SyncCallback> _callbacks = [];

  /// 获取当前同步状态
  SyncState get state => _state;

  /// 获取网络连接状态
  ConnectionStatus get connectionStatus => _connectionStatus;

  /// 获取上次同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 是否在线
  bool get isOnline => _connectionStatus == ConnectionStatus.online;

  /// 是否正在同步
  bool get isSyncing => _state == SyncState.syncing;

  /// 添加状态变化监听
  void addListener(SyncCallback callback) {
    _callbacks.add(callback);
  }

  /// 移除监听
  void removeListener(SyncCallback callback) {
    _callbacks.remove(callback);
  }

  void _notifyListeners(bool success, String? message) {
    for (final callback in _callbacks) {
      callback(success, message);
    }
  }

  /// 初始化同步服务
  Future<void> initialize() async {
    // 加载上次同步时间
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getString('last_sync_time');
    if (lastSync != null) {
      _lastSyncTime = DateTime.parse(lastSync);
    }

    // 监听网络状态变化
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    // 检查初始网络状态
    await checkConnectivity();

    // 启动自动同步定时器
    _startAutoSync();
  }

  /// 检查网络连接状态
  Future<ConnectionStatus> checkConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    _updateConnectionStatus(results);
    return _connectionStatus;
  }

  /// 处理网络状态变化
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    _updateConnectionStatus(results);
    
    // 网络恢复时自动同步
    if (_connectionStatus == ConnectionStatus.online) {
      _autoSyncIfNeeded();
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);

    final newStatus = hasConnection ? ConnectionStatus.online : ConnectionStatus.offline;
    
    if (_connectionStatus != newStatus) {
      _connectionStatus = newStatus;
      if (newStatus == ConnectionStatus.offline) {
        _state = SyncState.offline;
      } else {
        _state = SyncState.idle;
      }
      _notifyListeners(true, newStatus == ConnectionStatus.online ? '网络已连接' : '网络已断开');
    }
  }

  /// 启动自动同步定时器（每30分钟检查一次）
  void _startAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _autoSyncIfNeeded();
    });
  }

  /// 自动同步（仅WiFi下）
  Future<void> _autoSyncIfNeeded() async {
    if (!isOnline) return;
    
    final results = await Connectivity().checkConnectivity();
    final isWifi = results.contains(ConnectivityResult.wifi);
    
    // 仅在WiFi下自动同步
    if (isWifi) {
      final pendingCount = await DatabaseService.getPendingRecordCount();
      if (pendingCount > 0) {
        await syncLearningRecords();
      }
    }
  }

  /// 下载词库到本地
  Future<bool> downloadWordLevel({
    required int levelId,
    required String levelName,
    SyncCallback? callback,
  }) async {
    if (!isOnline) {
      _state = SyncState.offline;
      _notifyListeners(false, '无网络连接');
      callback?.call(false, '无网络连接');
      return false;
    }

    _state = SyncState.syncing;
    _notifyListeners(true, '正在下载词库...');

    try {
      // 获取该等级的所有单词
      final words = await ApiService.getWordLevels();
      
      // 获取该等级的具体单词（分页获取）
      List<Map<String, dynamic>> allWords = [];
      int page = 1;
      const pageSize = 500;
      bool hasMore = true;

      while (hasMore) {
        final response = await ApiService.get('/words/level/$levelId?page=$page&size=$pageSize');
        final data = (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        
        if (data.isEmpty) {
          hasMore = false;
        } else {
          allWords.addAll(data);
          if (data.length < pageSize) {
            hasMore = false;
          } else {
            page++;
          }
        }
      }

      // 保存到本地数据库
      await DatabaseService.insertWords(allWords);

      // 记录下载状态
      final sizeBytes = _estimateSize(allWords);
      await DatabaseService.recordLevelDownload(
        levelId: levelId,
        levelName: levelName,
        wordCount: allWords.length,
        sizeBytes: sizeBytes,
      );

      // 更新当前等级
      await DatabaseService.setCurrentLevelId(levelId);

      _state = SyncState.success;
      _notifyListeners(true, '词库下载成功，共${allWords.length}个单词');
      callback?.call(true, '词库下载成功，共${allWords.length}个单词');
      return true;
    } catch (e) {
      _state = SyncState.error;
      final message = '词库下载失败: $e';
      _notifyListeners(false, message);
      callback?.call(false, message);
      return false;
    }
  }

  /// 估算数据大小（字节）
  int _estimateSize(List<Map<String, dynamic>> data) {
    // 简单估算：序列化后的大小
    return data.length * 200; // 平均每个单词约200字节
  }

  /// 同步学习记录到服务器
  Future<bool> syncLearningRecords({SyncCallback? callback}) async {
    if (!isOnline) {
      _state = SyncState.offline;
      final pendingCount = await DatabaseService.getPendingRecordCount();
      _notifyListeners(false, '离线模式，待同步记录: $pendingCount');
      callback?.call(false, '离线模式');
      return false;
    }

    _state = SyncState.syncing;
    _notifyListeners(true, '正在同步学习记录...');

    try {
      // 获取未同步的记录
      final unsyncedRecords = await DatabaseService.getUnsyncedRecords();
      
      if (unsyncedRecords.isEmpty) {
        _state = SyncState.success;
        _notifyListeners(true, '暂无需要同步的记录');
        callback?.call(true, '暂无需要同步的记录');
        return true;
      }

      // 批量同步（每次最多50条）
      const batchSize = 50;
      List<int> syncedLocalIds = [];

      for (int i = 0; i < unsyncedRecords.length; i += batchSize) {
        final batch = unsyncedRecords.sublist(
          i,
          i + batchSize > unsyncedRecords.length
              ? unsyncedRecords.length
              : i + batchSize,
        );

        for (final record in batch) {
          try {
            await ApiService.submitLearning(
              wordId: record['word_id'] as int,
              isCorrect: record['is_correct'] == 1,
              duration: record['duration'] as int,
            );
            syncedLocalIds.add(record['local_id'] as int);
          } catch (e) {
            // 单条失败不影响其他记录
            continue;
          }
        }
      }

      // 标记已同步
      if (syncedLocalIds.isNotEmpty) {
        await DatabaseService.markRecordsSynced(syncedLocalIds);
      }

      // 更新同步状态
      await _updateSyncStatus();

      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());

      _state = SyncState.success;
      final message = '同步成功，已同步${syncedLocalIds.length}条记录';
      _notifyListeners(true, message);
      callback?.call(true, message);
      return true;
    } catch (e) {
      _state = SyncState.error;
      final message = '同步失败: $e';
      _notifyListeners(false, message);
      callback?.call(false, message);
      return false;
    }
  }

  /// 同步生词本
  Future<bool> syncWordBook({SyncCallback? callback}) async {
    if (!isOnline) {
      _state = SyncState.offline;
      callback?.call(false, '离线模式');
      return false;
    }

    _state = SyncState.syncing;

    try {
      // 获取本地未同步的生词本
      final unsynced = await DatabaseService.getUnsyncedWordBook();
      
      for (final item in unsynced) {
        try {
          await ApiService.addToWordBook(item['word_id'] as int);
        } catch (e) {
          continue;
        }
      }

      if (unsynced.isNotEmpty) {
        await DatabaseService.markWordBookSynced(
          unsynced.map((e) => e['word_id'] as int).toList(),
        );
      }

      _notifyListeners(true, '生词本同步成功');
      return true;
    } catch (e) {
      _notifyListeners(false, '生词本同步失败');
      return false;
    }
  }

  /// 执行完整同步
  Future<bool> fullSync({SyncCallback? callback}) async {
    if (!isOnline) {
      _state = SyncState.offline;
      _notifyListeners(false, '无网络连接');
      callback?.call(false, '无网络连接');
      return false;
    }

    _state = SyncState.syncing;
    _notifyListeners(true, '开始同步...');

    bool success = true;
    String lastMessage = '';

    // 同步学习记录
    final recordResult = await syncLearningRecords();
    if (!recordResult) success = false;

    // 同步生词本
    final wordBookResult = await syncWordBook();
    if (!wordBookResult) success = false;

    if (success) {
      _lastSyncTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!.toIso8601String());
      
      _state = SyncState.success;
      lastMessage = '同步完成';
    } else {
      _state = SyncState.error;
      lastMessage = '部分同步失败';
    }

    _notifyListeners(success, lastMessage);
    callback?.call(success, lastMessage);
    return success;
  }

  /// 更新同步状态
  Future<void> _updateSyncStatus() async {
    final pendingCount = await DatabaseService.getPendingRecordCount();
    final totalSynced = await getTotalSyncedCount();
    
    await DatabaseService.updateSyncStatus(
      lastSyncTime: DateTime.now().toIso8601String(),
      syncedRecords: totalSynced,
      pendingRecords: pendingCount,
    );
  }

  /// 获取已同步的记录数
  Future<int> getTotalSyncedCount() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_records WHERE synced = 1',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取同步状态信息
  Future<Map<String, dynamic>> getSyncInfo() async {
    final status = await DatabaseService.getSyncStatus();
    final pendingCount = await DatabaseService.getPendingRecordCount();
    final downloadedLevels = await DatabaseService.getDownloadedLevels();
    final totalSize = await DatabaseService.getTotalDownloadSize();

    return {
      'state': _state.name,
      'connectionStatus': _connectionStatus.name,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'pendingCount': pendingCount,
      'downloadedLevels': downloadedLevels,
      'totalDownloadSize': totalSize,
      'isOnline': isOnline,
    };
  }

  /// 销毁服务
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    _callbacks.clear();
  }
}
