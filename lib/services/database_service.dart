/// 本地SQLite数据库服务
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'vocabulary_app.db';
  static const int _dbVersion = 1;

  /// 获取数据库实例
  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建表结构
  static Future<void> _onCreate(Database db, int version) async {
    // 单词表
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY,
        word TEXT NOT NULL,
        phonetic TEXT,
        meaning TEXT NOT NULL,
        example TEXT,
        level_id INTEGER NOT NULL,
        level_name TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // 创建索引加速查询
    await db.execute('CREATE INDEX idx_words_level ON words(level_id)');
    await db.execute('CREATE INDEX idx_words_word ON words(word)');

    // 学习记录表
    await db.execute('''
      CREATE TABLE learning_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        is_correct INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0,
        local_id INTEGER PRIMARY KEY AUTOINCREMENT
      )
    ''');

    // 生词本表
    await db.execute('''
      CREATE TABLE word_book (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL UNIQUE,
        word TEXT NOT NULL,
        phonetic TEXT,
        meaning TEXT NOT NULL,
        level_name TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        synced INTEGER DEFAULT 0
      )
    ''');

    // 同步状态表
    await db.execute('''
      CREATE TABLE sync_status (
        id INTEGER PRIMARY KEY,
        last_sync_time TEXT,
        current_level_id INTEGER,
        synced_records INTEGER DEFAULT 0,
        pending_records INTEGER DEFAULT 0
      )
    ''');

    // 词库下载状态表
    await db.execute('''
      CREATE TABLE downloaded_levels (
        level_id INTEGER PRIMARY KEY,
        level_name TEXT NOT NULL,
        word_count INTEGER NOT NULL,
        downloaded_at TEXT DEFAULT CURRENT_TIMESTAMP,
        size_bytes INTEGER DEFAULT 0
      )
    ''');
  }

  /// 数据库升级
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 未来版本升级逻辑
  }

  // ==================== 单词操作 ====================

  /// 批量插入单词
  static Future<void> insertWords(List<Map<String, dynamic>> words) async {
    final db = await database;
    final batch = db.batch();
    
    for (final word in words) {
      batch.insert(
        'words',
        {
          'id': word['id'],
          'word': word['word'],
          'phonetic': word['phonetic'] ?? '',
          'meaning': word['meaning'],
          'example': word['example'],
          'level_id': word['level_id'],
          'level_name': word['level_name'] ?? '',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  /// 获取本地单词列表
  static Future<List<Word>> getLocalWords({int? levelId, int limit = 20, int offset = 0}) async {
    final db = await database;
    
    List<Map<String, dynamic>> results;
    if (levelId != null) {
      results = await db.query(
        'words',
        where: 'level_id = ?',
        whereArgs: [levelId],
        limit: limit,
        offset: offset,
      );
    } else {
      results = await db.query(
        'words',
        limit: limit,
        offset: offset,
      );
    }
    
    return results.map((e) => Word.fromJson(e)).toList();
  }

  /// 获取本地新词（未学习过的）
  static Future<List<Word>> getLocalNewWords({int count = 10}) async {
    final db = await database;
    
    // 获取还没有学习记录的单词
    final results = await db.rawQuery('''
      SELECT w.* FROM words w
      LEFT JOIN learning_records lr ON w.id = lr.word_id
      WHERE lr.word_id IS NULL
      LIMIT ?
    ''', [count]);
    
    return results.map((e) => Word.fromJson(e)).toList();
  }

  /// 获取本地复习词（学习过但需要复习的）
  static Future<List<Word>> getLocalReviewWords({int count = 10}) async {
    final db = await database;
    
    // 获取学习过但正确率低的单词
    final results = await db.rawQuery('''
      SELECT w.*, 
             COUNT(lr.id) as learn_count,
             SUM(CASE WHEN lr.is_correct = 1 THEN 1 ELSE 0 END) as correct_count
      FROM words w
      INNER JOIN learning_records lr ON w.id = lr.word_id
      GROUP BY w.id
      HAVING correct_count < learn_count * 0.7
      LIMIT ?
    ''', [count]);
    
    return results.map((e) => Word.fromJson(e)).toList();
  }

  /// 搜索本地单词
  static Future<List<Word>> searchLocalWords(String keyword) async {
    final db = await database;
    
    final results = await db.query(
      'words',
      where: 'word LIKE ? OR meaning LIKE ?',
      whereArgs: ['%$keyword%', '%$keyword%'],
      limit: 50,
    );
    
    return results.map((e) => Word.fromJson(e)).toList();
  }

  /// 获取指定等级的单词数量
  static Future<int> getWordCountByLevel(int levelId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM words WHERE level_id = ?',
      [levelId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取本地所有单词数量
  static Future<int> getTotalWordCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM words');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== 学习记录操作 ====================

  /// 保存学习记录（本地）
  static Future<void> saveLearningRecord({
    required int wordId,
    required bool isCorrect,
    required int duration,
  }) async {
    final db = await database;
    await db.insert('learning_records', {
      'word_id': wordId,
      'is_correct': isCorrect ? 1 : 0,
      'duration': duration,
      'created_at': DateTime.now().toIso8601String(),
      'synced': 0,
    });
  }

  /// 获取未同步的学习记录
  static Future<List<Map<String, dynamic>>> getUnsyncedRecords() async {
    final db = await database;
    return await db.query(
      'learning_records',
      where: 'synced = 0',
    );
  }

  /// 标记记录已同步
  static Future<void> markRecordsSynced(List<int> localIds) async {
    final db = await database;
    final placeholders = List.filled(localIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE learning_records SET synced = 1 WHERE local_id IN ($placeholders)',
      localIds,
    );
  }

  /// 获取本地学习统计
  static Future<Map<String, dynamic>> getLocalStats() async {
    final db = await database;
    
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM learning_records');
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    
    final todayResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_records WHERE created_at >= ?',
      [todayStart.toIso8601String()],
    );
    
    final todayCorrectResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_records WHERE created_at >= ? AND is_correct = 1',
      [todayStart.toIso8601String()],
    );
    
    final totalCorrectResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_records WHERE is_correct = 1',
    );
    
    final uniqueWordsResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT word_id) as count FROM learning_records',
    );
    
    return {
      'total_words': Sqflite.firstIntValue(uniqueWordsResult) ?? 0,
      'today_words': Sqflite.firstIntValue(todayResult) ?? 0,
      'today_correct': Sqflite.firstIntValue(todayCorrectResult) ?? 0,
      'total_correct': Sqflite.firstIntValue(totalCorrectResult) ?? 0,
      'total_records': Sqflite.firstIntValue(totalResult) ?? 0,
    };
  }

  /// 获取未同步记录数
  static Future<int> getPendingRecordCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM learning_records WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ==================== 生词本操作 ====================

  /// 添加到本地生词本
  static Future<void> addToLocalWordBook(Word word) async {
    final db = await database;
    await db.insert(
      'word_book',
      {
        'word_id': word.id,
        'word': word.word,
        'phonetic': word.phonetic,
        'meaning': word.meaning,
        'level_name': word.levelName,
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 获取本地生词本
  static Future<List<Word>> getLocalWordBook() async {
    final db = await database;
    final results = await db.query('word_book', orderBy: 'created_at DESC');
    
    return results.map((e) => Word(
      id: e['word_id'] as int,
      word: e['word'] as String,
      phonetic: e['phonetic'] as String? ?? '',
      meaning: e['meaning'] as String,
      levelId: 0,
      levelName: e['level_name'] as String? ?? '',
    )).toList();
  }

  /// 从本地生词本移除
  static Future<void> removeFromLocalWordBook(int wordId) async {
    final db = await database;
    await db.delete('word_book', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 获取未同步的生词本记录
  static Future<List<Map<String, dynamic>>> getUnsyncedWordBook() async {
    final db = await database;
    return await db.query('word_book', where: 'synced = 0');
  }

  /// 标记生词本记录已同步
  static Future<void> markWordBookSynced(List<int> wordIds) async {
    final db = await database;
    final placeholders = List.filled(wordIds.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE word_book SET synced = 1 WHERE word_id IN ($placeholders)',
      wordIds,
    );
  }

  // ==================== 下载状态操作 ====================

  /// 记录词库下载
  static Future<void> recordLevelDownload({
    required int levelId,
    required String levelName,
    required int wordCount,
    required int sizeBytes,
  }) async {
    final db = await database;
    await db.insert(
      'downloaded_levels',
      {
        'level_id': levelId,
        'level_name': levelName,
        'word_count': wordCount,
        'size_bytes': sizeBytes,
        'downloaded_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取已下载的词库列表
  static Future<List<Map<String, dynamic>>> getDownloadedLevels() async {
    final db = await database;
    return await db.query('downloaded_levels', orderBy: 'downloaded_at DESC');
  }

  /// 检查词库是否已下载
  static Future<bool> isLevelDownloaded(int levelId) async {
    final db = await database;
    final result = await db.query(
      'downloaded_levels',
      where: 'level_id = ?',
      whereArgs: [levelId],
    );
    return result.isNotEmpty;
  }

  /// 获取当前使用的词库ID
  static Future<int?> getCurrentLevelId() async {
    final db = await database;
    final result = await db.query('sync_status', where: 'id = 1');
    if (result.isNotEmpty) {
      return result.first['current_level_id'] as int?;
    }
    return null;
  }

  /// 设置当前使用的词库ID
  static Future<void> setCurrentLevelId(int levelId) async {
    final db = await database;
    await db.insert(
      'sync_status',
      {'id': 1, 'current_level_id': levelId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取总下载大小
  static Future<int> getTotalDownloadSize() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(size_bytes) as total FROM downloaded_levels',
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// 更新同步状态
  static Future<void> updateSyncStatus({
    String? lastSyncTime,
    int? syncedRecords,
    int? pendingRecords,
  }) async {
    final db = await database;
    final existing = await db.query('sync_status', where: 'id = 1');
    
    if (existing.isEmpty) {
      await db.insert('sync_status', {
        'id': 1,
        'last_sync_time': lastSyncTime,
        'synced_records': syncedRecords ?? 0,
        'pending_records': pendingRecords ?? 0,
      });
    } else {
      await db.update('sync_status', {
        if (lastSyncTime != null) 'last_sync_time': lastSyncTime,
        if (syncedRecords != null) 'synced_records': syncedRecords,
        if (pendingRecords != null) 'pending_records': pendingRecords,
      }, where: 'id = 1');
    }
  }

  /// 获取同步状态
  static Future<Map<String, dynamic>?> getSyncStatus() async {
    final db = await database;
    final result = await db.query('sync_status', where: 'id = 1');
    return result.isNotEmpty ? result.first : null;
  }

  /// 清空数据库（用于重置）
  static Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('words');
    await db.delete('learning_records');
    await db.delete('word_book');
    await db.delete('downloaded_levels');
    await db.delete('sync_status');
  }

  /// 关闭数据库连接
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
