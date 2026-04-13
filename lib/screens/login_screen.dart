import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLogin = true;
  int _selectedGrade = 1;
  bool _obscurePassword = true;
  
  final List<String> _gradeNames = ['一年级', '二年级', '三年级', '四年级', '五年级', '六年级', '初一', '初二', '初三', '高一', '高二', '高三'];
  
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
  
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final userProvider = context.read<UserProvider>();
    
    bool success;
    if (_isLogin) {
      success = await userProvider.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
    } else {
      success = await userProvider.register(
        _usernameController.text.trim(),
        _passwordController.text,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        grade: _selectedGrade,
      );
    }
    
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_rounded,
                            size: 60,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '背单词',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isLogin ? '登录你的账号' : '创建新账号',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          // 用户名
                          TextFormField(
                            controller: _usernameController,
                            decoration: const InputDecoration(
                              labelText: '用户名',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '请输入用户名';
                              }
                              if (value.trim().length < 2) {
                                return '用户名至少2个字符';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // 密码
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入密码';
                              }
                              if (value.length < 6) {
                                return '密码至少6位';
                              }
                              return null;
                            },
                          ),
                          
                          // 注册时显示额外字段
                          if (!_isLogin) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: '手机号（选填）',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              value: _selectedGrade,
                              decoration: const InputDecoration(
                                labelText: '年级',
                                prefixIcon: Icon(Icons.school_outlined),
                              ),
                              items: List.generate(_gradeNames.length, (index) {
                                return DropdownMenuItem(
                                  value: index + 1,
                                  child: Text(_gradeNames[index]),
                                );
                              }),
                              onChanged: (value) {
                                setState(() => _selectedGrade = value!);
                              },
                            ),
                          ],
                          
                          const SizedBox(height: 24),
                          
                          // 错误提示
                          Consumer<UserProvider>(
                            builder: (context, userProvider, _) {
                              if (userProvider.error != null) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.errorContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          userProvider.error!,
                                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                          
                          // 登录/注册按钮
                          Consumer<UserProvider>(
                            builder: (context, userProvider, _) {
                              return SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton(
                                  onPressed: userProvider.isLoading ? null : _submit,
                                  child: userProvider.isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Text(_isLogin ? '登录' : '注册'),
                                ),
                              );
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // 切换登录/注册
                          TextButton(
                            onPressed: () {
                              setState(() => _isLogin = !_isLogin);
                              context.read<UserProvider>()._error = null;
                            },
                            child: Text(_isLogin ? '没有账号？立即注册' : '已有账号？立即登录'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 扩展UserProvider以便清除错误
extension on UserProvider {
  set _error(String? value) {
    // ignore: invalid_use_of_protected_member
    notifyListeners();
  }
}
