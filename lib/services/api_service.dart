/// 后端API服务（支持离线模式）
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'database_service.dart';

class ApiService {
  // API地址配置（支持动态切换）
  static String _baseUrl = 'http://180.154.97.221:18000/api/v1'; // 默认外网地址
  static const String _externalUrl = 'http://180.154.97.221:18000/api/v1'; // 外网地址
  static const String _internalUrl = 'http://192.168.7.108:8000/api/v1'; // 内网地址
  
  static String? _token;
  static bool _offlineMode = false;
  
  /// 获取当前API地址
  static String get baseUrl => _baseUrl;
  
  /// 设置API地址
  static Future<void> setApiUrl(bool useExternal) async {
    _baseUrl = useExternal ? _externalUrl : _internalUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_external_api', useExternal);
  }
  
  /// 加载API地址设置
  static Future<void> loadApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final useExternal = prefs.getBool('use_external_api') ?? true; // 默认使用外网
    _baseUrl = useExternal ? _externalUrl : _internalUrl;
  }
  
  /// 获取token
  static Future<String?> getToken() async {
    if (_token != null) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    return _token;
  }
  
  /// 保存token
  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
  
  /// 清除token
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
  
  /// 设置离线模式
  static void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
  
  /// 获取离线模式状态
  static bool get offlineMode => _offlineMode;
  
  /// 通用请求头
  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// 检查网络连接
  static Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('baidu.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// GET请求（支持离线）
  static Future<Map<String, dynamic>> get(String path, {bool allowOffline = false}) async {
    final hasNetwork = await _checkConnectivity();
    
    if (!hasNetwork && allowOffline) {
      _offlineMode = true;
      throw OfflineException('离线模式');
    }
    
    _offlineMode = false;
    
    final response = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
    
    return _handleResponse(response);
  }
  
  /// POST请求（支持离线）
  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool allowOffline = false}) async {
    final hasNetwork = await _checkConnectivity();
    
    if (!hasNetwork && allowOffline) {
      _offlineMode = true;
      throw OfflineException('离线模式');
    }
    
    _offlineMode = false;
    
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    ).timeout(const Duration(seconds: 10));
    
    return _handleResponse(response);
  }
  
  /// PUT请求
  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    ).timeout(const Duration(seconds: 10));
    
    return _handleResponse(response);
  }
  
  /// DELETE请求
  static Future<Map<String, dynamic>> delete(String path) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
    
    return _handleResponse(response);
  }
  
  /// 处理响应
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw ApiException(
        '请求失败: ${response.statusCode}',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
  }
  
  // ============ 认证相关 ============
  
  /// 用户注册
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? phone,
    int? grade,
  }) async {
    return await post('/auth/register', body: {
      'username': username,
      'password': password,
      if (phone != null) 'phone': phone,
      if (grade != null) 'grade': grade,
    });
  }
  
  /// 用户登录
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final result = await post('/auth/login', body: {
      'username': username,
      'password': password,
    });
    if (result['access_token'] != null) {
      await saveToken(result['access_token']);
    }
    return result;
  }
  
  /// 获取用户信息
  static Future<Map<String, dynamic>> getUserInfo() async {
    return await get('/users/profile');
  }
  
  /// 更新用户信息
  static Future<Map<String, dynamic>> updateUserInfo({
    String? username,
    String? phone,
    int? grade,
  }) async {
    return await put('/users/profile', body: {
      if (username != null) 'username': username,
      if (phone != null) 'phone': phone,
      if (grade != null) 'grade': grade,
    });
  }
  
  // ============ 词库相关 ============
  
  /// 获取词库等级列表
  static Future<List<Map<String, dynamic>>> getWordLevels() async {
    try {
      final response = await get('/words/levels');
      final data = response['data'] as List?;
      return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (e) {
      if (_offlineMode) {
        final localLevels = await DatabaseService.getDownloadedLevels();
        return localLevels;
      }
      rethrow;
    }
  }
  
  /// 切换词库等级
  static Future<Map<String, dynamic>> switchLevel(int levelId) async {
    return await post('/words/switch-level', body: {'level_id': levelId});
  }
  
  /// 获取新词（支持离线）
  static Future<List<Map<String, dynamic>>> getNewWords({int count = 10}) async {
    try {
      final response = await get('/words/new?count=$count');
      final data = response['data'] as List?;
      return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (e) {
      if (_offlineMode) {
        final localWords = await DatabaseService.getLocalNewWords(count: count);
        return localWords.map((w) => {
          'id': w.id,
          'word': w.word,
          'phonetic': w.phonetic,
          'meaning': w.meaning,
          'example': w.example,
          'level_id': w.levelId,
          'level_name': w.levelName,
        }).toList();
      }
      rethrow;
    }
  }
  
  /// 获取复习词（支持离线）
  static Future<List<Map<String, dynamic>>> getReviewWords() async {
    try {
      final response = await get('/words/review');
      final data = response['data'] as List?;
      return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (e) {
      if (_offlineMode) {
        final localWords = await DatabaseService.getLocalReviewWords(count: 10);
        return localWords.map((w) => {
          'id': w.id,
          'word': w.word,
          'phonetic': w.phonetic,
          'meaning': w.meaning,
          'example': w.example,
          'level_id': w.levelId,
          'level_name': w.levelName,
        }).toList();
      }
      rethrow;
    }
  }
  
  /// 搜索单词（支持离线）
  static Future<List<Map<String, dynamic>>> searchWords(String keyword) async {
    try {
      final response = await get('/words/search?keyword=$keyword');
      final data = response['data'] as List?;
      return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (e) {
      if (_offlineMode) {
        final localWords = await DatabaseService.searchLocalWords(keyword);
        return localWords.map((w) => {
          'id': w.id,
          'word': w.word,
          'phonetic': w.phonetic,
          'meaning': w.meaning,
          'example': w.example,
          'level_id': w.levelId,
          'level_name': w.levelName,
        }).toList();
      }
      rethrow;
    }
  }
  
  /// 获取生词本（支持离线）
  static Future<List<Map<String, dynamic>>> getWordBook() async {
    try {
      final response = await get('/words/book');
      final data = response['data'] as List?;
      return data?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    } catch (e) {
      if (_offlineMode) {
        final localWords = await DatabaseService.getLocalWordBook();
        return localWords.map((w) => {
          'id': w.id,
          'word': w.word,
          'phonetic': w.phonetic,
          'meaning': w.meaning,
          'level_name': w.levelName,
        }).toList();
      }
      rethrow;
    }
  }
  
  /// 添加到生词本
  static Future<Map<String, dynamic>> addToWordBook(int wordId) async {
    try {
      return await post('/words/book/add', body: {'word_id': wordId});
    } catch (e) {
      if (!await _checkConnectivity()) {
        _offlineMode = true;
        final localWords = await DatabaseService.searchLocalWords(wordId.toString());
        if (localWords.isNotEmpty) {
          await DatabaseService.addToLocalWordBook(localWords.first);
        }
        return {'status': 'local', 'message': '已保存到本地生词本'};
      }
      rethrow;
    }
  }
  
  /// 从生词本移除
  static Future<Map<String, dynamic>> removeFromWordBook(int wordId) async {
    return await post('/words/book/remove', body: {'word_id': wordId});
  }
  
  /// 批量添加到生词本
  static Future<Map<String, dynamic>> addToWordBookBatch(List<int> wordIds) async {
    return await post('/words/book/add-batch', body: {'word_ids': wordIds});
  }
  
  // ============ 学习记录 ============
  
  /// 提交学习结果（本地优先）
  static Future<Map<String, dynamic>> submitLearning({
    required int wordId,
    required bool isCorrect,
    required int duration,
  }) async {
    await DatabaseService.saveLearningRecord(
      wordId: wordId,
      isCorrect: isCorrect,
      duration: duration,
    );
    
    try {
      final hasNetwork = await _checkConnectivity();
      if (hasNetwork) {
        final result = await post('/training/submit', body: {
          'word_id': wordId,
          'is_correct': isCorrect,
          'duration': duration,
        });
        
        final unsynced = await DatabaseService.getUnsyncedRecords();
        final matchingRecord = unsynced.where((r) => 
          r['word_id'] == wordId && 
          r['is_correct'] == (isCorrect ? 1 : 0) &&
          r['duration'] == duration
        ).toList();
        
        if (matchingRecord.isNotEmpty) {
          await DatabaseService.markRecordsSynced([matchingRecord.first['local_id'] as int]);
        }
        
        return result;
      }
    } catch (e) {
      // 网络请求失败，但本地已保存
    }
    
    return {'status': 'local', 'message': '已保存到本地，联网后自动同步'};
  }
  
  /// 获取学习摘要（支持离线）
  static Future<Map<String, dynamic>> getLearningSummary() async {
    try {
      return await get('/training/summary');
    } catch (e) {
      if (_offlineMode) {
        final localStats = await DatabaseService.getLocalStats();
        return {
          'today_words': localStats['today_words'] ?? 0,
          'today_correct': localStats['today_correct'] ?? 0,
          'total_words': localStats['total_words'] ?? 0,
          'current_level_id': 1,
          'streak': 0,
          'is_offline': true,
        };
      }
      rethrow;
    }
  }
  
  /// 获取学习统计（支持离线）
  static Future<Map<String, dynamic>> getLearningStats() async {
    try {
      return await get('/training/stats');
    } catch (e) {
      if (_offlineMode) {
        final localStats = await DatabaseService.getLocalStats();
        return {
          'total_words': localStats['total_words'] ?? 0,
          'streak': 0,
          'accuracy': 0,
          'total_duration': 0,
          'today_words': localStats['today_words'] ?? 0,
          'today_correct': localStats['today_correct'] ?? 0,
        };
      }
      rethrow;
    }
  }
  
  /// 获取绑定码
  static Future<Map<String, dynamic>> getBindCode() async {
    return await get('/users/bind-code');
  }
  
  /// 获取绑定状态
  static Future<Map<String, dynamic>> getBindStatus() async {
    return await get('/users/bind-status');
  }
  
  /// 同步本地数据到服务器
  static Future<void> syncToServer() async {
    final unsynced = await DatabaseService.getUnsyncedRecords();
    if (unsynced.isEmpty) return;
    
    for (final record in unsynced) {
      try {
        await post('/training/submit', body: {
          'word_id': record['word_id'],
          'is_correct': record['is_correct'] == 1,
          'duration': record['duration'],
        });
        await DatabaseService.markRecordsSynced([record['local_id'] as int]);
      } catch (e) {
        // 同步失败，下次继续
        break;
      }
    }
  }
}

/// 离线异常
class OfflineException implements Exception {
  final String message;
  OfflineException(this.message);
  
  @override
  String toString() => message;
}

/// API异常
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String body;
  
  ApiException(this.message, {required this.statusCode, required this.body});
  
  @override
  String toString() => message;
}
