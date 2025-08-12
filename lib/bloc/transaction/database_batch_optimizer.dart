/// 数据库批量操作优化器
/// 
/// 优化数据库层的批量操作，包括批量插入、更新、删除，提升数据库操作性能
library;

import 'dart:async';
import 'dart:collection';
import 'package:sqflite/sqflite.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';

/// 数据库操作类型
enum DatabaseOperationType {
  insert,         // 插入操作
  update,         // 更新操作
  delete,         // 删除操作
  query,          // 查询操作
  mixed,          // 混合操作
}

/// 批量操作策略
enum BatchOperationStrategy {
  transaction,    // 事务批处理
  prepared,       // 预编译语句
  bulk,          // 批量操作
  optimized,     // 优化策略
  adaptive,      // 自适应策略
}

/// 数据库批量配置
class DatabaseBatchConfig {
  final int batchSize;
  final BatchOperationStrategy strategy;
  final Duration timeout;
  final bool enableTransaction;
  final bool enablePreparedStatements;
  final bool enableOptimization;
  final int maxRetries;
  final Duration retryDelay;
  
  const DatabaseBatchConfig({
    this.batchSize = 100,
    this.strategy = BatchOperationStrategy.adaptive,
    this.timeout = const Duration(seconds: 30),
    this.enableTransaction = true,
    this.enablePreparedStatements = true,
    this.enableOptimization = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(milliseconds: 500),
  });
  
  /// 高性能配置
  factory DatabaseBatchConfig.highPerformance() {
    return const DatabaseBatchConfig(
      batchSize: 500,
      strategy: BatchOperationStrategy.bulk,
      enableTransaction: true,
      enablePreparedStatements: true,
      enableOptimization: true,
    );
  }
  
  /// 安全配置
  factory DatabaseBatchConfig.safe() {
    return const DatabaseBatchConfig(
      batchSize: 50,
      strategy: BatchOperationStrategy.transaction,
      enableTransaction: true,
      enablePreparedStatements: false,
      enableOptimization: false,
    );
  }
}

/// 数据库操作项
class DatabaseOperationItem {
  final String id;
  final DatabaseOperationType type;
  final String table;
  final Map<String, dynamic> data;
  final String? whereClause;
  final List<dynamic>? whereArgs;
  final int priority;
  
  const DatabaseOperationItem({
    required this.id,
    required this.type,
    required this.table,
    required this.data,
    this.whereClause,
    this.whereArgs,
    this.priority = 0,
  });
  
  /// 创建插入操作项
  factory DatabaseOperationItem.insert(String table, Map<String, dynamic> data, {int priority = 0}) {
    return DatabaseOperationItem(
      id: 'insert_${table}_${DateTime.now().millisecondsSinceEpoch}',
      type: DatabaseOperationType.insert,
      table: table,
      data: data,
      priority: priority,
    );
  }
  
  /// 创建更新操作项
  factory DatabaseOperationItem.update(
    String table, 
    Map<String, dynamic> data, 
    String whereClause, 
    List<dynamic> whereArgs,
    {int priority = 0}
  ) {
    return DatabaseOperationItem(
      id: 'update_${table}_${DateTime.now().millisecondsSinceEpoch}',
      type: DatabaseOperationType.update,
      table: table,
      data: data,
      whereClause: whereClause,
      whereArgs: whereArgs,
      priority: priority,
    );
  }
  
  /// 创建删除操作项
  factory DatabaseOperationItem.delete(
    String table, 
    String whereClause, 
    List<dynamic> whereArgs,
    {int priority = 0}
  ) {
    return DatabaseOperationItem(
      id: 'delete_${table}_${DateTime.now().millisecondsSinceEpoch}',
      type: DatabaseOperationType.delete,
      table: table,
      data: {},
      whereClause: whereClause,
      whereArgs: whereArgs,
      priority: priority,
    );
  }
}

/// 批量操作结果
class DatabaseBatchResult {
  final bool success;
  final int processedItems;
  final int successfulItems;
  final int failedItems;
  final Duration executionTime;
  final List<String> errors;
  final Map<String, dynamic> statistics;
  
  const DatabaseBatchResult({
    required this.success,
    required this.processedItems,
    required this.successfulItems,
    required this.failedItems,
    required this.executionTime,
    required this.errors,
    this.statistics = const {},
  });
  
  double get successRate => processedItems == 0 ? 0.0 : successfulItems / processedItems;
  double get failureRate => processedItems == 0 ? 0.0 : failedItems / processedItems;
}

/// 数据库批量操作优化器
class DatabaseBatchOptimizer {
  final DatabaseBatchConfig config;
  final DatabaseHelper databaseHelper;
  
  // 操作队列
  final Queue<DatabaseOperationItem> _operationQueue = Queue<DatabaseOperationItem>();
  
  // 批处理定时器
  Timer? _batchTimer;
  
  // 统计信息
  int _totalOperations = 0;
  int _batchedOperations = 0;
  int _successfulBatches = 0;
  int _failedBatches = 0;
  final List<Duration> _executionTimes = [];
  
  DatabaseBatchOptimizer({
    required this.databaseHelper,
    this.config = const DatabaseBatchConfig(),
  });
  
  /// 添加数据库操作
  void addOperation(DatabaseOperationItem operation) {
    _totalOperations++;
    _operationQueue.add(operation);
    
    // 如果达到批次大小，立即处理
    if (_operationQueue.length >= config.batchSize) {
      _processBatch();
    } else {
      // 设置延迟处理
      _scheduleBatchProcessing();
    }
  }
  
  /// 批量添加操作
  void addOperations(List<DatabaseOperationItem> operations) {
    for (final operation in operations) {
      addOperation(operation);
    }
  }
  
  /// 批量插入目标
  Future<DatabaseBatchResult> batchInsertGoals(List<Goal> goals) async {
    final operations = goals.map((goal) => 
        DatabaseOperationItem.insert('goals', goal.toJson())
    ).toList();
    
    return await _executeBatchOperations(operations);
  }
  
  /// 批量更新目标
  Future<DatabaseBatchResult> batchUpdateGoals(List<Goal> goals) async {
    final operations = goals.map((goal) => 
        DatabaseOperationItem.update(
          'goals', 
          goal.toJson(), 
          'id = ?', 
          [goal.id],
        )
    ).toList();
    
    return await _executeBatchOperations(operations);
  }
  
  /// 批量删除目标
  Future<DatabaseBatchResult> batchDeleteGoals(List<int> goalIds) async {
    final operations = goalIds.map((id) => 
        DatabaseOperationItem.delete('goals', 'id = ?', [id])
    ).toList();
    
    return await _executeBatchOperations(operations);
  }
  
  /// 调度批处理
  void _scheduleBatchProcessing() {
    _batchTimer?.cancel();
    _batchTimer = Timer(const Duration(milliseconds: 100), () {
      if (_operationQueue.isNotEmpty) {
        _processBatch();
      }
    });
  }
  
  /// 处理批次
  void _processBatch() {
    if (_operationQueue.isEmpty) return;
    
    final operations = <DatabaseOperationItem>[];
    while (_operationQueue.isNotEmpty && operations.length < config.batchSize) {
      operations.add(_operationQueue.removeFirst());
    }
    
    _executeBatchOperations(operations);
  }
  
  /// 执行批量操作
  Future<DatabaseBatchResult> _executeBatchOperations(List<DatabaseOperationItem> operations) async {
    if (operations.isEmpty) {
      return const DatabaseBatchResult(
        success: true,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        executionTime: Duration.zero,
        errors: [],
      );
    }
    
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    int successfulItems = 0;
    
    try {
      switch (config.strategy) {
        case BatchOperationStrategy.transaction:
          successfulItems = await _executeWithTransaction(operations);
          break;
          
        case BatchOperationStrategy.prepared:
          successfulItems = await _executeWithPreparedStatements(operations);
          break;
          
        case BatchOperationStrategy.bulk:
          successfulItems = await _executeWithBulkOperations(operations);
          break;
          
        case BatchOperationStrategy.optimized:
          successfulItems = await _executeWithOptimization(operations);
          break;
          
        case BatchOperationStrategy.adaptive:
          successfulItems = await _executeWithAdaptiveStrategy(operations);
          break;
      }
      
      _successfulBatches++;
      
    } catch (e) {
      errors.add(e.toString());
      _failedBatches++;
    }
    
    stopwatch.stop();
    _executionTimes.add(stopwatch.elapsed);
    _batchedOperations += operations.length;
    
    final result = DatabaseBatchResult(
      success: errors.isEmpty,
      processedItems: operations.length,
      successfulItems: successfulItems,
      failedItems: operations.length - successfulItems,
      executionTime: stopwatch.elapsed,
      errors: errors,
      statistics: {
        'strategy': config.strategy.toString(),
        'batchSize': operations.length,
        'throughput': operations.length / stopwatch.elapsed.inSeconds,
      },
    );
    
    return result;
  }
  
  /// 使用事务执行
  Future<int> _executeWithTransaction(List<DatabaseOperationItem> operations) async {
    final database = await databaseHelper.database;
    int successCount = 0;
    
    await database.transaction((txn) async {
      for (final operation in operations) {
        try {
          await _executeOperation(txn, operation);
          successCount++;
        } catch (e) {
          // 在事务中，任何错误都会导致整个事务回滚
          rethrow;
        }
      }
    });
    
    return successCount;
  }
  
  /// 使用预编译语句执行
  Future<int> _executeWithPreparedStatements(List<DatabaseOperationItem> operations) async {
    final database = await databaseHelper.database;
    int successCount = 0;
    
    // 按操作类型和表分组
    final groups = _groupOperations(operations);
    
    for (final group in groups) {
      try {
        if (group.first.type == DatabaseOperationType.insert) {
          await _executePreparedInserts(database, group);
        } else if (group.first.type == DatabaseOperationType.update) {
          await _executePreparedUpdates(database, group);
        } else if (group.first.type == DatabaseOperationType.delete) {
          await _executePreparedDeletes(database, group);
        }
        successCount += group.length;
      } catch (e) {
        // 继续处理其他组
        continue;
      }
    }
    
    return successCount;
  }
  
  /// 使用批量操作执行
  Future<int> _executeWithBulkOperations(List<DatabaseOperationItem> operations) async {
    final database = await databaseHelper.database;
    final batch = database.batch();
    
    for (final operation in operations) {
      _addToBatch(batch, operation);
    }
    
    final results = await batch.commit(noResult: false);
    return results.length;
  }
  
  /// 使用优化策略执行
  Future<int> _executeWithOptimization(List<DatabaseOperationItem> operations) async {
    // 优化操作顺序：删除 -> 更新 -> 插入
    final optimizedOperations = _optimizeOperationOrder(operations);
    
    // 使用事务和批量操作结合
    return await _executeWithTransaction(optimizedOperations);
  }
  
  /// 使用自适应策略执行
  Future<int> _executeWithAdaptiveStrategy(List<DatabaseOperationItem> operations) async {
    // 根据操作数量和类型选择最佳策略
    if (operations.length < 10) {
      return await _executeWithTransaction(operations);
    } else if (operations.length < 100) {
      return await _executeWithPreparedStatements(operations);
    } else {
      return await _executeWithBulkOperations(operations);
    }
  }
  
  /// 执行单个操作
  Future<void> _executeOperation(DatabaseExecutor executor, DatabaseOperationItem operation) async {
    switch (operation.type) {
      case DatabaseOperationType.insert:
        await executor.insert(operation.table, operation.data);
        break;
        
      case DatabaseOperationType.update:
        await executor.update(
          operation.table,
          operation.data,
          where: operation.whereClause,
          whereArgs: operation.whereArgs,
        );
        break;
        
      case DatabaseOperationType.delete:
        await executor.delete(
          operation.table,
          where: operation.whereClause,
          whereArgs: operation.whereArgs,
        );
        break;
        
      case DatabaseOperationType.query:
      case DatabaseOperationType.mixed:
        throw UnsupportedError('Query and mixed operations not supported in batch');
    }
  }
  
  /// 添加到批次
  void _addToBatch(Batch batch, DatabaseOperationItem operation) {
    switch (operation.type) {
      case DatabaseOperationType.insert:
        batch.insert(operation.table, operation.data);
        break;
        
      case DatabaseOperationType.update:
        batch.update(
          operation.table,
          operation.data,
          where: operation.whereClause,
          whereArgs: operation.whereArgs,
        );
        break;
        
      case DatabaseOperationType.delete:
        batch.delete(
          operation.table,
          where: operation.whereClause,
          whereArgs: operation.whereArgs,
        );
        break;
        
      case DatabaseOperationType.query:
      case DatabaseOperationType.mixed:
        throw UnsupportedError('Query and mixed operations not supported in batch');
    }
  }
  
  /// 分组操作
  List<List<DatabaseOperationItem>> _groupOperations(List<DatabaseOperationItem> operations) {
    final groups = <String, List<DatabaseOperationItem>>{};
    
    for (final operation in operations) {
      final key = '${operation.type}_${operation.table}';
      groups.putIfAbsent(key, () => []).add(operation);
    }
    
    return groups.values.toList();
  }
  
  /// 优化操作顺序
  List<DatabaseOperationItem> _optimizeOperationOrder(List<DatabaseOperationItem> operations) {
    final sorted = List<DatabaseOperationItem>.from(operations);
    
    // 按类型排序：删除 -> 更新 -> 插入
    sorted.sort((a, b) {
      final aOrder = _getOperationOrder(a.type);
      final bOrder = _getOperationOrder(b.type);
      
      if (aOrder != bOrder) {
        return aOrder.compareTo(bOrder);
      }
      
      // 相同类型按优先级排序
      return b.priority.compareTo(a.priority);
    });
    
    return sorted;
  }
  
  /// 获取操作顺序
  int _getOperationOrder(DatabaseOperationType type) {
    switch (type) {
      case DatabaseOperationType.delete: return 1;
      case DatabaseOperationType.update: return 2;
      case DatabaseOperationType.insert: return 3;
      case DatabaseOperationType.query: return 4;
      case DatabaseOperationType.mixed: return 5;
    }
  }
  
  /// 执行预编译插入
  Future<void> _executePreparedInserts(Database database, List<DatabaseOperationItem> operations) async {
    if (operations.isEmpty) return;
    
    final table = operations.first.table;
    final columns = operations.first.data.keys.toList();
    final placeholders = columns.map((_) => '?').join(', ');
    final sql = 'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)';
    
    for (final operation in operations) {
      final values = columns.map((col) => operation.data[col]).toList();
      await database.rawInsert(sql, values);
    }
  }
  
  /// 执行预编译更新
  Future<void> _executePreparedUpdates(Database database, List<DatabaseOperationItem> operations) async {
    for (final operation in operations) {
      await database.update(
        operation.table,
        operation.data,
        where: operation.whereClause,
        whereArgs: operation.whereArgs,
      );
    }
  }
  
  /// 执行预编译删除
  Future<void> _executePreparedDeletes(Database database, List<DatabaseOperationItem> operations) async {
    for (final operation in operations) {
      await database.delete(
        operation.table,
        where: operation.whereClause,
        whereArgs: operation.whereArgs,
      );
    }
  }
  
  /// 强制处理所有待处理操作
  void flush() {
    _batchTimer?.cancel();
    if (_operationQueue.isNotEmpty) {
      _processBatch();
    }
  }
  
  /// 获取批量操作统计
  DatabaseBatchStats getStats() {
    final avgExecutionTime = _executionTimes.isEmpty
        ? Duration.zero
        : Duration(milliseconds: 
            (_executionTimes.fold(0, (sum, d) => sum + d.inMilliseconds) / _executionTimes.length).round());
    
    final batchSuccessRate = (_successfulBatches + _failedBatches) == 0 
        ? 0.0 
        : _successfulBatches / (_successfulBatches + _failedBatches);
    
    return DatabaseBatchStats(
      totalOperations: _totalOperations,
      batchedOperations: _batchedOperations,
      successfulBatches: _successfulBatches,
      failedBatches: _failedBatches,
      batchSuccessRate: batchSuccessRate,
      averageExecutionTime: avgExecutionTime,
      pendingOperations: _operationQueue.length,
    );
  }
  
  /// 重置统计
  void resetStats() {
    _totalOperations = 0;
    _batchedOperations = 0;
    _successfulBatches = 0;
    _failedBatches = 0;
    _executionTimes.clear();
  }
  
  /// 释放资源
  void dispose() {
    _batchTimer?.cancel();
    flush(); // 处理剩余操作
  }
}

/// 数据库批量操作统计
class DatabaseBatchStats {
  final int totalOperations;
  final int batchedOperations;
  final int successfulBatches;
  final int failedBatches;
  final double batchSuccessRate;
  final Duration averageExecutionTime;
  final int pendingOperations;
  
  const DatabaseBatchStats({
    required this.totalOperations,
    required this.batchedOperations,
    required this.successfulBatches,
    required this.failedBatches,
    required this.batchSuccessRate,
    required this.averageExecutionTime,
    required this.pendingOperations,
  });
  
  /// 获取性能等级
  String get performanceLevel {
    if (batchSuccessRate > 0.95 && averageExecutionTime.inMilliseconds < 100) {
      return 'Excellent';
    } else if (batchSuccessRate > 0.9 && averageExecutionTime.inMilliseconds < 200) {
      return 'Good';
    } else if (batchSuccessRate > 0.8 && averageExecutionTime.inMilliseconds < 500) {
      return 'Fair';
    } else {
      return 'Poor';
    }
  }
}
