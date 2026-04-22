# 离线词库功能说明

## 已修改/新增的文件

### 1. `pubspec.yaml`
**修改内容**：添加离线功能所需的依赖
```yaml
dependencies:
  sqflite: ^2.3.2          # SQLite数据库
  path: ^1.9.0             # 路径处理
  connectivity_plus: ^6.0.3 # 网络状态检测
  path_provider: ^2.1.2     # 应用目录路径
```

### 2. `lib/services/database_service.dart` (新增)
**功能**：本地SQLite数据库服务

#### 创建的表：
- `words` - 单词表，存储下载的单词数据
- `learning_records` - 学习记录表，含同步状态标记
- `word_book` - 生词本表，含离线同步标记
- `sync_status` - 同步状态表
- `downloaded_levels` - 词库下载状态表

#### 主要方法：
- `insertWords()` - 批量插入单词
- `getLocalWords()` - 获取本地单词列表
- `getLocalNewWords()` - 获取未学习的新词
- `getLocalReviewWords()` - 获取需要复习的单词
- `searchLocalWords()` - 搜索本地单词
- `saveLearningRecord()` - 保存学习记录（自动标记待同步）
- `getUnsyncedRecords()` - 获取未同步记录
- `markRecordsSynced()` - 标记记录已同步
- `getLocalStats()` - 获取本地学习统计
- `recordLevelDownload()` - 记录词库下载状态
- `getDownloadedLevels()` - 获取已下载的词库

### 3. `lib/services/sync_service.dart` (新增)
**功能**：数据同步服务

#### 主要功能：
- 网络状态实时监听（wifi/mobile/offline）
- WiFi下自动同步学习记录
- 词库下载管理
- 增量同步（只同步未同步的数据）
- 同步状态回调通知

#### 主要方法：
- `initialize()` - 初始化同步服务
- `checkConnectivity()` - 检查网络连接
- `downloadWordLevel()` - 下载词库到本地
- `syncLearningRecords()` - 同步学习记录
- `syncWordBook()` - 同步生词本
- `fullSync()` - 执行完整同步
- `getSyncInfo()` - 获取同步状态信息

### 4. `lib/services/api_service.dart`
**修改内容**：添加离线模式支持

#### 新增功能：
- `offlineMode` 属性 - 标记当前是否为离线模式
- `OfflineException` - 离线异常类
- 所有API方法增加离线fallback：
  - `getWordLevels()` - 离线时返回本地已下载等级
  - `getNewWords()` - 离线时从本地获取新词
  - `getReviewWords()` - 离线时从本地获取复习词
  - `searchWords()` - 离线时搜索本地单词
  - `getWordBook()` - 离线时返回本地生词本
  - `submitLearning()` - 优先保存本地，尝试同步
  - `getLearningSummary()` - 离线时返回本地统计
  - `getLearningStats()` - 离线时返回本地统计

### 5. `lib/screens/profile_screen.dart`
**修改内容**：添加离线设置界面

#### 新增UI元素：
- 网络状态指示器（在线/离线）
- 同步状态显示
- 待同步记录数提示
- "下载词库"按钮和对话框
- 同步详情页面
- 本地数据统计显示
- 离线模式标识

### 6. `lib/screens/learn_screen.dart`
**修改内容**：支持离线学习

#### 新增功能：
- 自动检测网络状态
- 离线时加载本地数据
- 离线模式UI标识
- 无数据时的引导界面
- 离线学习提示

### 7. `lib/screens/card_learning_screen.dart`
**修改内容**：支持离线学习

#### 新增功能：
- `isOffline` 参数
- 离线模式下只保存到本地
- 网络失败时自动降级到本地保存
- 离线模式完成学习后的提示

### 8. `lib/models/models.dart`
**修改内容**：添加离线相关模型

#### 新增内容：
- `DownloadedLevel` 类 - 下载的词库信息

## 使用流程

### 首次使用
1. 用户在「我的」页面点击「下载词库」
2. 选择要下载的词库等级
3. 系统下载并保存到本地SQLite数据库
4. 下载完成后自动切换到该词库

### 离线学习
1. 系统检测到无网络
2. 自动切换到离线模式
3. 学习记录保存到本地
4. 显示「离线」标识

### 数据同步
1. 检测到网络恢复（WiFi优先）
2. 自动同步待同步的学习记录
3. 同步完成后更新状态显示

## 技术特点

1. **无感知切换**：用户无需手动切换模式，系统自动检测
2. **本地优先**：学习记录先保存本地，确保不丢失
3. **增量同步**：只同步变化的数据，减少流量
4. **WiFi同步**：仅在WiFi下自动同步，节省流量
5. **状态反馈**：清晰的同步状态和待同步数量显示
