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
        version: 1,
        onCreate: _onCreate,
      );
    }

    String path = join(await getDatabasesPath(), 'linzaivision.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
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
        FOREIGN KEY (parent_id) REFERENCES goals (id) ON DELETE CASCADE
      )
    ''');
  }

  // 插入目标
  Future<int> insertGoal(Goal goal) async {
    if (kIsWeb) {
      // Web 平台使用 localStorage
      final goals = await _getWebGoals();
      final id = goals.isEmpty
          ? 1
          : goals.map((g) => g.id ?? 0).reduce((a, b) => a > b ? a : b) + 1;
      goal.id = id;
      goals.add(goal);
      await _saveWebGoals(goals);
      return id;
    }

    final db = await database;
    return await db.insert('goals', goal.toMap());
  }

  // 获取目标列表
  Future<List<Goal>> getGoals({int? parentId}) async {
    if (kIsWeb) {
      // Web 平台从 localStorage 获取
      final goals = await _getWebGoals();
      final filteredGoals = goals.where((g) => g.parentId == parentId).toList();
      // 按创建时间倒序排序
      filteredGoals.sort((a, b) => b.createdTime.compareTo(a.createdTime));
      return filteredGoals;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      where: parentId != null ? 'parent_id = ?' : 'parent_id IS NULL',
      whereArgs: parentId != null ? [parentId] : null,
      orderBy: 'created_time DESC', // 按创建时间倒序排序
    );
    return List.generate(maps.length, (i) => Goal.fromMap(maps[i]));
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
        debugPrint('Error reading from localStorage: $e');
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
        debugPrint('Error saving to localStorage: $e');
      }
    }
  }

  // 获取目标树
  Future<List<Goal>> getGoalTree() async {
    if (kIsWeb) {
      final goals = await _getWebGoals();

      // 构建目标树
      final Map<int?, List<Goal>> parentChildMap = {};
      for (var goal in goals) {
        if (!parentChildMap.containsKey(goal.parentId)) {
          parentChildMap[goal.parentId] = [];
        }
        parentChildMap[goal.parentId]!.add(goal);
      }

      // 对每个父节点下的子目标列表进行排序
      for (var children in parentChildMap.values) {
        children.sort((a, b) => b.createdTime.compareTo(a.createdTime));
      }

      // 递归设置子目标
      void setSubGoals(Goal goal) {
        if (parentChildMap.containsKey(goal.id)) {
          goal.subGoals = parentChildMap[goal.id]!;
          for (var subGoal in goal.subGoals) {
            setSubGoals(subGoal);
          }
        }
      }

      // 获取顶级目标并排序
      final rootGoals = parentChildMap[null] ?? [];
      rootGoals.sort((a, b) => b.createdTime.compareTo(a.createdTime));

      for (var goal in rootGoals) {
        setSubGoals(goal);
      }

      return rootGoals;
    }

    final db = await database;
    // 按创建时间倒序获取所有目标
    final List<Map<String, dynamic>> maps = await db.query(
      'goals',
      orderBy: 'created_time DESC',
    );
    final goals = maps.map((map) => Goal.fromMap(map)).toList();

    // 构建目标树
    final Map<int?, List<Goal>> parentChildMap = {};
    for (var goal in goals) {
      if (!parentChildMap.containsKey(goal.parentId)) {
        parentChildMap[goal.parentId] = [];
      }
      parentChildMap[goal.parentId]!.add(goal);
    }

    // 对每个父节点下的子目标列表进行排序
    for (var children in parentChildMap.values) {
      children.sort((a, b) => b.createdTime.compareTo(a.createdTime));
    }

    // 递归设置子目标
    void setSubGoals(Goal goal) {
      if (parentChildMap.containsKey(goal.id)) {
        goal.subGoals = parentChildMap[goal.id]!;
        for (var subGoal in goal.subGoals) {
          setSubGoals(subGoal);
        }
      }
    }

    // 获取顶级目标
    final rootGoals = parentChildMap[null] ?? [];
    for (var goal in rootGoals) {
      setSubGoals(goal);
    }

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
        debugPrint('Error importing data: $e');
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

  // 清理数据库（仅用于测试）
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    _instance = null;
  }
}
