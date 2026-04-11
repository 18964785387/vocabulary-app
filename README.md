# 疯狂背单词 - Flutter学生端APP

## 项目结构
```
flutter_app/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/
│   │   └── models.dart           # 数据模型
│   ├── providers/
│   │   └── user_provider.dart    # 用户状态管理
│   ├── screens/
│   │   ├── login_screen.dart     # 登录注册页
│   │   ├── home_screen.dart      # 主页框架
│   │   ├── learn_screen.dart     # 学习主页
│   │   ├── card_learning_screen.dart  # 卡片学习页
│   │   ├── word_book_screen.dart # 生词本页
│   │   └── profile_screen.dart   # 个人中心页
│   ├── services/
│   │   └── api_service.dart      # API服务
│   └── widgets/                  # 自定义组件
├── assets/
│   ├── images/                   # 图片资源
│   └── audio/                    # 音频资源
└── pubspec.yaml                  # 项目配置
```

## 核心功能

### 1. 用户认证
- 用户注册（用户名、密码、手机号、年级）
- 用户登录
- 自动登录（Token持久化）

### 2. 学习功能
- 词库选择（初中、高中、四六级等）
- 学习新词（卡片翻牌式）
- 复习巩固（SM-2记忆曲线算法）
- 学习统计（今日学习、正确率、连续天数）

### 3. 生词本
- 生词列表
- 搜索单词
- 滑动删除
- 单词详情

### 4. 个人中心
- 用户信息展示
- 学习统计
- 家长绑定（生成绑定码）
- 退出登录

## 运行步骤

### 1. 安装Flutter
```bash
# 下载Flutter SDK: https://flutter.dev/docs/get-started/install
flutter doctor
```

### 2. 创建项目
```bash
flutter create vocabulary_app
cd vocabulary_app
```

### 3. 替换文件
将本目录下的 `lib/` 文件夹和 `pubspec.yaml` 复制到项目根目录

### 4. 安装依赖
```bash
flutter pub get
```

### 5. 运行项目
```bash
# 运行在模拟器或真机
flutter run

# 构建APK
flutter build apk --release
```

### 6. 修改API地址
编辑 `lib/services/api_service.dart`，修改 `baseUrl` 为你的后端地址：
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8000/api/v1';
```

## 注意事项

1. **网络权限**：Android需要在 `android/app/src/main/AndroidManifest.xml` 添加：
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

2. **HTTP明文传输**：Android 9+需要在 `android/app/src/main/AndroidManifest.xml` 的 `<application>` 标签添加：
```xml
android:usesCleartextTraffic="true"
```

3. **后端服务**：确保后端API服务已启动并可访问

## 后续开发计划

- [ ] 发音功能（TTS）
- [ ] 离线词库
- [ ] 学习打卡分享
- [ ] 成就系统
- [ ] 夜间模式
