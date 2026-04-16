import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;
  
  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  
  /// 设置用户信息
  void setUser(Map<String, dynamic> userData) {
    _user = User.fromJson(userData);
    _error = null;
    notifyListeners();
  }
  
  /// 登录
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      // 先登录获取token
      await ApiService.login(
        username: username,
        password: password,
      );
      // 再获取用户信息
      final userData = await ApiService.getUserInfo();
      _user = User.fromJson(userData);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 注册
  Future<bool> register(String username, String password, {String? phone, int grade = 1}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await ApiService.register(
        username: username,
        password: password,
        phone: phone,
        grade: grade,
      );
      // 注册成功后自动登录
      return await login(username, password);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 退出登录
  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    notifyListeners();
  }
  
  /// 更新用户信息
  Future<bool> updateUserInfo({String? username, String? phone, int? grade}) async {
    try {
      final result = await ApiService.updateUserInfo(
        username: username,
        phone: phone,
        grade: grade,
      );
      setUser(result);
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
  
  /// 刷新用户信息
  Future<void> refreshUser() async {
    try {
      final result = await ApiService.getUserInfo();
      setUser(result);
    } catch (e) {
      // 静默失败
    }
  }
}
