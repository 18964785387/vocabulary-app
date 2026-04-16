/// 后端API服务
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 后端API地址（外网访问）
  static const String baseUrl = 'http://180.154.97.221:18000/api/v1';
  
  static String? _token;
  
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
  
  /// 通用请求头
  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  /// GET请求
  static Future<Map<String, dynamic>> get(String path) async {
    final response = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
    return _handleResponse(response);
  }
  
  /// POST请求
  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body}) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _handleResponse(response);
  }
  
  /// PUT请求
  static Future<Map<String, dynamic>> put(String path, {Map<String, dynamic>? body}) async {
    final response = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body ?? {}),
    );
    return _handleResponse(response);
  }
  
  /// 处理响应
  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? '请求失败');
    }
  }
  
  // ============ 用户认证 ============
  
  /// 用户注册
  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? phone,
    int grade = 1,
  }) async {
    return await post('/auth/register', body: {
      'username': username,
      'password': password,
      'phone': phone,
      'grade': grade,
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
    final response = await get('/words/levels');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 切换词库等级
  static Future<Map<String, dynamic>> switchLevel(int levelId) async {
    return await post('/words/switch-level', body: {'level_id': levelId});
  }
  
  /// 获取新词（学习用）
  static Future<List<Map<String, dynamic>>> getNewWords({int count = 10}) async {
    final response = await get('/words/new?count=$count');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 获取复习词
  static Future<List<Map<String, dynamic>>> getReviewWords() async {
    final response = await get('/words/review');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 搜索单词
  static Future<List<Map<String, dynamic>>> searchWords(String keyword) async {
    final response = await get('/words/search?keyword=$keyword');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 获取生词本
  static Future<List<Map<String, dynamic>>> getWordBook() async {
    final response = await get('/words/book');
    return (response['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }
  
  /// 添加到生词本
  static Future<Map<String, dynamic>> addToWordBook(int wordId) async {
    return await post('/words/book/add', body: {'word_id': wordId});
  }
  
  /// 从生词本移除
  static Future<Map<String, dynamic>> removeFromWordBook(int wordId) async {
    return await post('/words/book/remove', body: {'word_id': wordId});
  }
  
  // ============ 学习记录 ============
  
  /// 提交学习结果
  static Future<Map<String, dynamic>> submitLearning({
    required int wordId,
    required bool isCorrect,
    required int duration,
  }) async {
    return await post('/training/submit', body: {
      'word_id': wordId,
      'is_correct': isCorrect,
      'duration': duration,
    });
  }
  
  /// 获取学习摘要
  static Future<Map<String, dynamic>> getLearningSummary() async {
    return await get('/training/summary');
  }
  
  /// 获取学习统计
  static Future<Map<String, dynamic>> getLearningStats() async {
    return await get('/training/stats');
  }
  
  // ============ 家长绑定 ============
  
  /// 获取绑定码
  static Future<Map<String, dynamic>> getBindCode() async {
    return await get('/parent/bind-code');
  }
  
  /// 获取绑定状态
  static Future<Map<String, dynamic>> getBindStatus() async {
    return await get('/parent/status');
  }
}
