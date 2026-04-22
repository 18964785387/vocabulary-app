import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发音类型枚举
enum TtsAccentType {
  american, // 美式发音
  british,  // 英式发音
}

/// TTS 发音服务类
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  
  // 默认设置
  static const double _defaultRate = 0.5; // 默认语速 0.0-1.0
  static const String _rateKey = 'tts_rate';
  static const String _accentKey = 'tts_accent';
  
  double _currentRate = _defaultRate;
  TtsAccentType _currentAccent = TtsAccentType.american;
  
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// 初始化 TTS 服务
  Future<void> init() async {
    if (_isInitialized) return;
    
    // 设置语言和语速
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.awaitSpeakCompletion(true);
    
    // 加载保存的设置
    await _loadSettings();
    await _applySettings();
    
    // 监听状态变化
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
    
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });
    
    _isInitialized = true;
  }

  /// 加载保存的设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentRate = prefs.getDouble(_rateKey) ?? _defaultRate;
      final accentIndex = prefs.getInt(_accentKey) ?? 0;
      _currentAccent = TtsAccentType.values[accentIndex];
    } catch (e) {
      // 使用默认值
    }
  }

  /// 应用当前设置到 TTS 引擎
  Future<void> _applySettings() async {
    await _flutterTts.setSpeechRate(_currentRate);
    
    if (_currentAccent == TtsAccentType.american) {
      await _flutterTts.setLanguage('en-US');
    } else {
      await _flutterTts.setLanguage('en-GB');
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_rateKey, _currentRate);
      await prefs.setInt(_accentKey, _currentAccent.index);
    } catch (e) {
      // 保存失败，忽略
    }
  }

  /// 朗读单词
  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    
    // 如果正在朗读，先停止
    if (_isSpeaking) {
      await stop();
    }
    
    await _flutterTts.speak(text);
  }

  /// 停止朗读
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  /// 获取当前语速 (0.0 - 1.0)
  double get currentRate => _currentRate;

  /// 设置语速
  Future<void> setRate(double rate) async {
    // 限制在 0.0-1.0 范围内
    _currentRate = rate.clamp(0.0, 1.0);
    await _flutterTts.setSpeechRate(_currentRate);
    await _saveSettings();
  }

  /// 获取当前发音类型
  TtsAccentType get currentAccent => _currentAccent;

  /// 设置发音类型
  Future<void> setAccent(TtsAccentType accent) async {
    _currentAccent = accent;
    await _applySettings();
    await _saveSettings();
  }

  /// 获取语速描述
  String getRateLabel() {
    if (_currentRate <= 0.25) return '很慢';
    if (_currentRate <= 0.5) return '正常';
    if (_currentRate <= 0.75) return '较快';
    return '很快';
  }

  /// 获取发音类型描述
  String getAccentLabel() {
    return _currentAccent == TtsAccentType.american ? '美式发音' : '英式发音';
  }

  /// 是否正在朗读
  bool get isSpeaking => _isSpeaking;

  /// 释放资源
  void dispose() {
    _flutterTts.stop();
    _isInitialized = false;
  }
}
