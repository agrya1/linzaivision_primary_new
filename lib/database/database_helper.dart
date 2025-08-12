import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/goal.dart';
import 'web_storage.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;
  final bool isTest;

  // 升级数据库版本号
  static const int _databaseVersion = 2;

  factory DatabaseHelper({bool isTest = false}) {
    _instance ??= DatabaseHelper._internal(isTest);
    return _instance!;
  }

  DatabaseHelper._internal(this.isTest);

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
          'SQLite database is not supported on Web platform');
    }

    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError(
          'SQLite database is not supported on Web platform');
    }

    if (isTest) {
      return await openDatabase(
        inMemoryDatabasePath,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
    }

    String path = join(await getDatabasesPath(), 'linzaivision.db');
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        image_path TEXT NOT NULL,
        status INTEGER DEFAULT 0,
        created_time INTEGER NOT NULL,
        target_date INTEGER,
        parent_id INTEGER,
        video_path TEXT,
        has_video INTEGER NOT NULL DEFAULT 0,
        video_muted INTEGER NOT NULL DEFAULT 0,
        custom_countdown_days INTEGER,
        has_custom_countdown INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (parent_id) REFERENCES goals (id) ON DELETE CASCADE
      )
    ''');
  }

  // 数据库版本升级处理
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 版本1升级到版本2：添加视频和自定义倒计时相关字段
      await db.execute('ALTER TABLE goals ADD COLUMN video_path TEXT');
      await db.execute(
          'ALTER TABLE goals ADD COLUMN has_video INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE goals ADD COLUMN video_muted INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE goals ADD COLUMN custom_countdown_days INTEGER');
      await db.execute(
          'ALTER TABLE goals ADD COLUMN has_custom_countdown INTEGER NOT NULL DEFAULT 0');

      print('数据库升级完成：从版本 $oldVersion 到版本 $newVersion');
    }
  }

  // 备份数据库
  Future<String> backupDatabase() async {
    if (kIsWeb) {
      return await exportData();
    }

    final goals = await getGoalTree();
    final List<Map<String, dynamic>> jsonList =
        goals.map((g) => g.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // 插入目标
  Future<int> insertGoal(Goal goal) async {
    print('【DatabaseHelper】开始插入目标: 标题=${goal.title}, 父ID=${goal.parentId}');

    if (kIsWeb) {
      // Web 平台使用 localStorage
      final goals = await _getWebGoals();
      final id = goals.isEmpty
          ? 1
          : goals.map((g) => g.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      goal.id = id;
      goals.add(goal);
      await _saveWebGoals(goals);
      print(
          '【DatabaseHelper】Web平台插入目标成功: ID=$id, 标题=${goal.title}, 父ID=${goal.parentId}');
      return id;
    }

    final db = await database;
    final id = await db.insert('goals', goal.toMap());
    print(
        '【DatabaseHelper】插入目标成功: ID=$id, 标题=${goal.title}, 父ID=${goal.parentId}');
    return id;
  }

  // 获取目标列表
  Future<List<Goal>> getGoals({int? parentId}) async {
    if (kIsWeb) {
      // Web 平台从 localStorage 获取
      final goals = await _getWebGoals();
      final filteredGoals = goals.where((g) => g.parentId == parentId).toList();
      // 按创建时间升序排序
      filteredGoals.sort((a, b) => a.createdTime.compareTo(b.createdTime));
      return filteredGoals;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      where: parentId != null ? 'parent_id = ?' : 'parent_id IS NULL',
      whereArgs: parentId != null ? [parentId] : null,
      orderBy: 'created_time ASC', // 按创建时间升序排序
    );
    return List.generate(maps.length, (i) => Goal.fromMap(maps[i]));
  }

  // 获取单个目标
  Future<Goal?> getGoal(int id) async {
    print('【DatabaseHelper】开始获取目标，ID: $id');

    if (kIsWeb) {
      // Web 平台从 localStorage 获取
      final goals = await _getWebGoals();
      try {
        final goal = goals.firstWhere((g) => g.id == id);
        print('【DatabaseHelper】Web平台成功获取目标，ID: ${goal.id}, 标题: ${goal.title}');
        return goal;
      } catch (e) {
        print('【DatabaseHelper】Web平台未找到目标，ID: $id, 错误: $e');
        return null;
      }
    }

    final db = await database;
    print('【DatabaseHelper】执行SQL查询: SELECT * FROM goals WHERE id = $id');
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      print('【DatabaseHelper】未找到目标，ID: $id');
      return null;
    }

    final goal = Goal.fromMap(maps.first);
    print('【DatabaseHelper】成功获取目标，ID: ${goal.id}, 标题: ${goal.title}');
    return goal;
  }

  // 更新目标
  Future<int> updateGoal(Goal goal) async {
    if (kIsWeb) {
      // Web 平台更新 localStorage
      final goals = await _getWebGoals();
      final index = goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        goals[index] = goal;
        await _saveWebGoals(goals);
        return 1;
      }
      return 0;
    }

    final db = await database;
    return await db.update(
      'goals',
      goal.toMap(),
      where: 'id = ?',
      whereArgs: [goal.id],
    );
  }

  // 重置数据库（删除所有数据）
  Future<void> resetDatabase() async {
    print('【DatabaseHelper】开始重置数据库');

    if (kIsWeb) {
      // Web平台：清除localStorage
      WebStorage.removeItem('goals');
      print('【DatabaseHelper】Web平台数据库已重置');
      return;
    }

    final db = await database;
    await db.delete('goals');
    print('【DatabaseHelper】数据库已重置，所有目标已删除');
  }

  // 删除目标
  Future<int> deleteGoal(int id) async {
    if (kIsWeb) {
      // Web 平台从 localStorage 删除
      final goals = await _getWebGoals();
      final initialLength = goals.length;
      goals.removeWhere((g) => g.id == id);
      await _saveWebGoals(goals);
      return initialLength - goals.length;
    }

    final db = await database;
    return await db.delete(
      'goals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Web 平台特定的辅助方法
  Future<List<Goal>> _getWebGoals() async {
    if (kIsWeb) {
      try {
        final data = WebStorage.getData('goals');
        if (data != null) {
          final List<dynamic> jsonList = jsonDecode(data);
          return jsonList.map((json) => Goal.fromJson(json)).toList();
        }
      } catch (e) {
        print('Error reading from localStorage: $e');
      }
    }
    return [];
  }

  Future<void> _saveWebGoals(List<Goal> goals) async {
    if (kIsWeb) {
      try {
        final jsonList = goals.map((g) => g.toJson()).toList();
        WebStorage.saveData('goals', jsonEncode(jsonList));
      } catch (e) {
        print('Error saving to localStorage: $e');
      }
    }
  }

  // 获取目标树
  Future<List<Goal>> getGoalTree() async {
    print('【DatabaseHelper】开始获取目标树');

    if (kIsWeb) {
      final goals = await _getWebGoals();
      return _buildGoalTreeFromList(goals);
    }

    final db = await database;
    // 按创建时间升序获取所有目标
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      orderBy: 'created_time ASC',
    );
    final goals = maps.map((map) => Goal.fromMap(map)).toList();

    print('【DatabaseHelper】从数据库获取了 ${goals.length} 个目标');

    // 记录父子关系统计
    final Map<int?, int> parentCounts = {};
    for (var goal in goals) {
      parentCounts[goal.parentId] = (parentCounts[goal.parentId] ?? 0) + 1;
    }

    print('【DatabaseHelper】目标父子关系统计:');
    parentCounts.forEach((parentId, count) {
      print('【DatabaseHelper】父ID=${parentId ?? "null"} 有 $count 个子目标');
    });

    return _buildGoalTreeFromList(goals);
  }

  // 从目标列表构建目标树
  List<Goal> _buildGoalTreeFromList(List<Goal> allGoals) {
    print('【DatabaseHelper】开始构建目标树，总计 ${allGoals.length} 个目标');

    // 清空所有目标的子目标列表，确保不会累积
    for (var goal in allGoals) {
      goal.subGoals = [];
    }

    // 创建ID到目标的映射，方便快速查找
    final Map<int?, Goal> idToGoalMap = {
      for (var goal in allGoals)
        if (goal.id != null) goal.id: goal
    };

    print('【DatabaseHelper】创建ID映射，共 ${idToGoalMap.length} 个映射');

    // 创建父子关系映射
    final List<Goal> rootGoals = [];
    final Map<int?, List<int?>> parentChildMap = {};

    for (var goal in allGoals) {
      if (goal.parentId == null) {
        // 这是一个根目标
        rootGoals.add(goal);
        print('【DatabaseHelper】添加根目标: ID=${goal.id}, 标题=${goal.title}');
      } else if (idToGoalMap.containsKey(goal.parentId)) {
        // 找到父目标并添加到其子目标列表中
        idToGoalMap[goal.parentId]!.subGoals.add(goal);

        // 记录父子关系
        parentChildMap[goal.parentId] = parentChildMap[goal.parentId] ?? [];
        parentChildMap[goal.parentId]!.add(goal.id);

        print(
            '【DatabaseHelper】添加子目标: ID=${goal.id}, 标题=${goal.title}, 父ID=${goal.parentId}');
      } else {
        // 如果找不到父目标，将其作为根目标处理
        print(
            '【DatabaseHelper】警告: 目标ID ${goal.id} 的父ID ${goal.parentId} 无效，作为根目标处理');
        goal.parentId = null; // 重置父ID
        rootGoals.add(goal);
      }
    }

    // 记录父子关系统计
    print('【DatabaseHelper】父子关系统计:');
    parentChildMap.forEach((parentId, childIds) {
      print(
          '【DatabaseHelper】父ID=$parentId 有 ${childIds.length} 个子目标: $childIds');
    });

    // 对每个父节点下的子目标列表进行排序 - 按创建时间升序排序
    for (var goal in allGoals) {
      if (goal.subGoals.isNotEmpty) {
        goal.subGoals.sort((a, b) => a.createdTime.compareTo(b.createdTime));
      }
    }

    // 对根目标列表排序
    rootGoals.sort((a, b) => a.createdTime.compareTo(b.createdTime));

    print(
        '【DatabaseHelper】构建的目标树: ${rootGoals.length} 个根目标，总计 ${allGoals.length} 个目标');
    return rootGoals;
  }

  // 导出数据
  Future<String> exportData() async {
    if (kIsWeb) {
      final goals = await _getWebGoals();
      final List<Map<String, dynamic>> jsonList =
          goals.map((g) => g.toJson()).toList();
      return jsonEncode(jsonList);
    }

    final goals = await getGoalTree();
    final List<Map<String, dynamic>> jsonList =
        goals.map((g) => g.toJson()).toList();
    return jsonEncode(jsonList);
  }

  // 导入数据
  Future<void> importData(String jsonData) async {
    if (kIsWeb) {
      try {
        final List<dynamic> jsonList = jsonDecode(jsonData);
        final goals = jsonList.map((json) => Goal.fromJson(json)).toList();
        await _saveWebGoals(goals);
      } catch (e) {
        print('Error importing data: $e');
        rethrow;
      }
      return;
    }

    final db = await database;
    await db.transaction((txn) async {
      // 清空现有数据
      await txn.delete('goals');

      // 解析并导入新数据
      final List<dynamic> jsonList = jsonDecode(jsonData);
      for (var json in jsonList) {
        final goal = Goal.fromJson(json);
        await txn.insert('goals', goal.toMap());
      }
    });
  }

  // 验证数据库迁移
  Future<bool> validateMigration() async {
    try {
      if (kIsWeb) {
        // Web平台不需要验证
        return true;
      }

      final db = await database;
      final List<Map<String, dynamic>> tableInfo =
          await db.rawQuery("PRAGMA table_info(goals)");

      // 检查是否存在新增字段
      bool hasVideoPath = false;
      bool hasHasVideo = false;
      bool hasVideoMuted = false;
      bool hasCustomCountdownDays = false;
      bool hasHasCustomCountdown = false;

      for (var column in tableInfo) {
        final columnName = column['name'] as String;
        if (columnName == 'video_path') hasVideoPath = true;
        if (columnName == 'has_video') hasHasVideo = true;
        if (columnName == 'video_muted') hasVideoMuted = true;
        if (columnName == 'custom_countdown_days')
          hasCustomCountdownDays = true;
        if (columnName == 'has_custom_countdown') hasHasCustomCountdown = true;
      }

      return hasVideoPath &&
          hasHasVideo &&
          hasVideoMuted &&
          hasCustomCountdownDays &&
          hasHasCustomCountdown;
    } catch (e) {
      print('验证迁移失败: $e');
      return false;
    }
  }

  // 清理数据库（仅用于测试）
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _instance = null;
  }

  // 批量插入目标（使用事务）
  Future<void> batchInsertGoals(List<Goal> goals) async {
    if (kIsWeb) {
      // Web平台不支持事务，使用普通方式插入
      final existingGoals = await _getWebGoals();
      existingGoals.addAll(goals);
      await _saveWebGoals(existingGoals);
      return;
    }

    final db = await database;
    await db.transaction((txn) async {
      for (var goal in goals) {
        final id = await txn.insert('goals', goal.toMap());
        goal.id = id;
      }
    });

    print('批量插入完成: ${goals.length} 个目标');
  }

  // 批量插入目标树（处理父子关系）
  Future<void> batchInsertGoalTree(List<Goal> rootGoals) async {
    if (kIsWeb) {
      // Web平台简单处理
      final allGoals = _flattenGoalTree(rootGoals);
      await batchInsertGoals(allGoals);
      return;
    }

    final db = await database;
    await db.transaction((txn) async {
      // 递归插入目标及其子目标
      Future<void> insertGoalWithChildren(Goal goal, int? parentId) async {
        goal.parentId = parentId;

        // 插入当前目标
        final id = await txn.insert('goals', goal.toMap());
        goal.id = id;

        // 递归插入子目标
        for (var subGoal in goal.subGoals) {
          await insertGoalWithChildren(subGoal, id);
        }
      }

      // 处理所有根目标
      for (var rootGoal in rootGoals) {
        await insertGoalWithChildren(rootGoal, null);
      }
    });

    print('批量插入目标树完成: ${rootGoals.length} 个根目标');
  }

  // 将目标树展平为列表
  List<Goal> _flattenGoalTree(List<Goal> rootGoals) {
    final result = <Goal>[];

    void addGoalAndChildren(Goal goal) {
      result.add(goal);
      for (var child in goal.subGoals) {
        addGoalAndChildren(child);
      }
    }

    for (var goal in rootGoals) {
      addGoalAndChildren(goal);
    }

    return result;
  }
}
