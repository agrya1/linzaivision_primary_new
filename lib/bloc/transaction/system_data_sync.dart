/// 系统级数据同步管理器
/// 
/// 实现从服务器批量同步目标数据、批量更新本地缓存、批量清理过期数据等系统级批量处理功能
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'batch_processor.dart';
import 'transaction_manager.dart';
import '../../models/goal.dart';
import '../../database/database_helper.dart';
import '../goal/goal_bloc.dart';
import '../goal/goal_event.dart';

/// 同步操作类型
enum SyncOperationType {
  fullSync,           // 全量同步
  incrementalSync,    // 增量同步
  cacheUpdate,        // 缓存更新
  dataCleanup,        // 数据清理
  conflictResolution, // 冲突解决
}

/// 同步策略
enum SyncStrategy {
  serverFirst,        // 服务器优先
  clientFirst,        // 客户端优先
  lastModified,       // 最后修改时间优先
  manual,             // 手动解决
}

/// 同步配置
class SystemSyncConfig {
  final String serverUrl;
  final Duration syncInterval;
  final int batchSize;
  final Duration timeout;
  final SyncStrategy conflictStrategy;
  final bool enableAutoSync;
  final bool enableCompression;
  final int maxRetries;
  final Duration retryDelay;
  
  const SystemSyncConfig({
    required this.serverUrl,
    this.syncInterval = const Duration(minutes: 30),
    this.batchSize = 100,
    this.timeout = const Duration(minutes: 5),
    this.conflictStrategy = SyncStrategy.lastModified,
    this.enableAutoSync = true,
    this.enableCompression = true,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 5),
  });
}

/// 同步结果
class SyncResult {
  final SyncOperationType operationType;
  final bool success;
  final Duration executionTime;
  final int processedItems;
  final int successfulItems;
  final int failedItems;
  final int conflictItems;
  final List<String> errors;
  final Map<String, dynamic> metadata;
  
  const SyncResult({
    required this.operationType,
    required this.success,
    required this.executionTime,
    required this.processedItems,
    required this.successfulItems,
    required this.failedItems,
    required this.conflictItems,
    required this.errors,
    this.metadata = const {},
  });
  
  double get successRate => processedItems == 0 ? 0.0 : successfulItems / processedItems;
  double get failureRate => processedItems == 0 ? 0.0 : failedItems / processedItems;
  double get conflictRate => processedItems == 0 ? 0.0 : conflictItems / processedItems;
}

/// 数据冲突
class DataConflict {
  final String id;
  final Goal localData;
  final Goal serverData;
  final DateTime detectedAt;
  final String conflictType;
  
  const DataConflict({
    required this.id,
    required this.localData,
    required this.serverData,
    required this.detectedAt,
    required this.conflictType,
  });
}

/// 系统级数据同步管理器
class SystemDataSyncManager {
  final SystemSyncConfig config;
  final DatabaseHelper databaseHelper;
  final GoalBloc goalBloc;
  final TransactionManager transactionManager;
  final BatchProcessor<Goal> batchProcessor;
  
  // 同步状态
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _autoSyncTimer;
  
  // 冲突管理
  final List<DataConflict> _conflicts = [];
  
  // 统计信息
  int _totalSyncs = 0;
  int _successfulSyncs = 0;
  int _failedSyncs = 0;
  final List<SyncResult> _syncHistory = [];
  
  SystemDataSyncManager({
    required this.config,
    required this.databaseHelper,
    required this.goalBloc,
    required this.transactionManager,
  }) : batchProcessor = BatchProcessor<Goal>(
          processor: (item) async => item.data,
          config: BatchProcessingConfig(
            maxBatchSize: config.batchSize,
            strategy: BatchProcessingStrategy.parallel,
          ),
        ) {
    if (config.enableAutoSync) {
      _startAutoSync();
    }
  }
  
  /// 执行全量同步
  Future<SyncResult> performFullSync() async {
    if (_isSyncing) {
      throw StateError('Sync operation already in progress');
    }
    
    _isSyncing = true;
    final stopwatch = Stopwatch()..start();
    _totalSyncs++;
    
    try {
      // 1. 从服务器获取所有数据
      final serverGoals = await _fetchAllGoalsFromServer();
      
      // 2. 获取本地所有数据
      final localGoals = await databaseHelper.getGoals();
      
      // 3. 比较和合并数据
      final mergeResult = await _mergeGoalData(localGoals, serverGoals);
      
      // 4. 批量更新本地数据
      await _batchUpdateLocalData(mergeResult.toUpdate);
      
      // 5. 批量插入新数据
      await _batchInsertNewData(mergeResult.toInsert);
      
      // 6. 批量删除过期数据
      await _batchDeleteObsoleteData(mergeResult.toDelete);
      
      stopwatch.stop();
      _successfulSyncs++;
      _lastSyncTime = DateTime.now();
      
      final result = SyncResult(
        operationType: SyncOperationType.fullSync,
        success: true,
        executionTime: stopwatch.elapsed,
        processedItems: serverGoals.length,
        successfulItems: mergeResult.toUpdate.length + mergeResult.toInsert.length,
        failedItems: 0,
        conflictItems: mergeResult.conflicts.length,
        errors: [],
        metadata: {
          'serverGoalsCount': serverGoals.length,
          'localGoalsCount': localGoals.length,
          'updatedCount': mergeResult.toUpdate.length,
          'insertedCount': mergeResult.toInsert.length,
          'deletedCount': mergeResult.toDelete.length,
        },
      );
      
      _syncHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _failedSyncs++;
      
      final result = SyncResult(
        operationType: SyncOperationType.fullSync,
        success: false,
        executionTime: stopwatch.elapsed,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        conflictItems: 0,
        errors: [e.toString()],
      );
      
      _syncHistory.add(result);
      return result;
      
    } finally {
      _isSyncing = false;
    }
  }
  
  /// 执行增量同步
  Future<SyncResult> performIncrementalSync() async {
    if (_isSyncing) {
      throw StateError('Sync operation already in progress');
    }
    
    _isSyncing = true;
    final stopwatch = Stopwatch()..start();
    _totalSyncs++;
    
    try {
      final lastSync = _lastSyncTime ?? DateTime.now().subtract(const Duration(days: 1));
      
      // 1. 获取服务器增量数据
      final incrementalData = await _fetchIncrementalDataFromServer(lastSync);
      
      // 2. 获取本地修改的数据
      final localChanges = await _getLocalChanges(lastSync);
      
      // 3. 合并增量数据
      final mergeResult = await _mergeIncrementalData(localChanges, incrementalData);
      
      // 4. 应用更改
      await _applyIncrementalChanges(mergeResult);
      
      stopwatch.stop();
      _successfulSyncs++;
      _lastSyncTime = DateTime.now();
      
      final result = SyncResult(
        operationType: SyncOperationType.incrementalSync,
        success: true,
        executionTime: stopwatch.elapsed,
        processedItems: incrementalData.length,
        successfulItems: incrementalData.length - mergeResult.conflicts.length,
        failedItems: 0,
        conflictItems: mergeResult.conflicts.length,
        errors: [],
        metadata: {
          'incrementalDataCount': incrementalData.length,
          'localChangesCount': localChanges.length,
          'appliedChangesCount': incrementalData.length - mergeResult.conflicts.length,
        },
      );
      
      _syncHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      _failedSyncs++;
      
      final result = SyncResult(
        operationType: SyncOperationType.incrementalSync,
        success: false,
        executionTime: stopwatch.elapsed,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        conflictItems: 0,
        errors: [e.toString()],
      );
      
      _syncHistory.add(result);
      return result;
      
    } finally {
      _isSyncing = false;
    }
  }
  
  /// 批量更新本地缓存
  Future<SyncResult> updateLocalCache() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1. 获取需要更新的缓存数据
      final cacheData = await _getCacheUpdateData();
      
      // 2. 批量更新缓存
      final updateItems = cacheData.map((goal) => BatchOperationItem<Goal>(
        id: 'cache_update_${goal.id}',
        data: goal,
        type: BatchOperationType.update,
      )).toList();
      
      final batchResult = await batchProcessor.processBatch(updateItems);
      
      stopwatch.stop();
      
      final result = SyncResult(
        operationType: SyncOperationType.cacheUpdate,
        success: batchResult.successCount == cacheData.length,
        executionTime: stopwatch.elapsed,
        processedItems: cacheData.length,
        successfulItems: batchResult.successCount,
        failedItems: batchResult.failureCount,
        conflictItems: 0,
        errors: batchResult.failedResults.map((r) => r.error ?? 'Unknown error').toList(),
        metadata: {
          'cacheDataCount': cacheData.length,
          'batchDuration': batchResult.totalDuration.inMilliseconds,
        },
      );
      
      _syncHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      
      final result = SyncResult(
        operationType: SyncOperationType.cacheUpdate,
        success: false,
        executionTime: stopwatch.elapsed,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        conflictItems: 0,
        errors: [e.toString()],
      );
      
      _syncHistory.add(result);
      return result;
    }
  }
  
  /// 批量清理过期数据
  Future<SyncResult> cleanupExpiredData() async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // 1. 识别过期数据
      final expiredGoals = await _identifyExpiredData();
      
      // 2. 批量删除过期数据
      final deleteItems = expiredGoals.map((goal) => BatchOperationItem<Goal>(
        id: 'cleanup_${goal.id}',
        data: goal,
        type: BatchOperationType.delete,
      )).toList();
      
      final batchResult = await batchProcessor.processBatch(deleteItems);
      
      stopwatch.stop();
      
      final result = SyncResult(
        operationType: SyncOperationType.dataCleanup,
        success: batchResult.successCount == expiredGoals.length,
        executionTime: stopwatch.elapsed,
        processedItems: expiredGoals.length,
        successfulItems: batchResult.successCount,
        failedItems: batchResult.failureCount,
        conflictItems: 0,
        errors: batchResult.failedResults.map((r) => r.error ?? 'Unknown error').toList(),
        metadata: {
          'expiredDataCount': expiredGoals.length,
          'cleanupDuration': batchResult.totalDuration.inMilliseconds,
        },
      );
      
      _syncHistory.add(result);
      return result;
      
    } catch (e) {
      stopwatch.stop();
      
      final result = SyncResult(
        operationType: SyncOperationType.dataCleanup,
        success: false,
        executionTime: stopwatch.elapsed,
        processedItems: 0,
        successfulItems: 0,
        failedItems: 0,
        conflictItems: 0,
        errors: [e.toString()],
      );
      
      _syncHistory.add(result);
      return result;
    }
  }
  
  /// 从服务器获取所有目标数据
  Future<List<Goal>> _fetchAllGoalsFromServer() async {
    final response = await http.get(
      Uri.parse('${config.serverUrl}/api/goals'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(config.timeout);
    
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Goal.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch goals from server: ${response.statusCode}');
    }
  }
  
  /// 从服务器获取增量数据
  Future<List<Goal>> _fetchIncrementalDataFromServer(DateTime since) async {
    final response = await http.get(
      Uri.parse('${config.serverUrl}/api/goals/incremental?since=${since.toIso8601String()}'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(config.timeout);
    
    if (response.statusCode == 200) {
      final List<dynamic> jsonData = json.decode(response.body);
      return jsonData.map((json) => Goal.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch incremental data: ${response.statusCode}');
    }
  }
  
  /// 合并目标数据
  Future<_MergeResult> _mergeGoalData(List<Goal> localGoals, List<Goal> serverGoals) async {
    final toUpdate = <Goal>[];
    final toInsert = <Goal>[];
    final toDelete = <Goal>[];
    final conflicts = <DataConflict>[];
    
    final localGoalMap = {for (var goal in localGoals) goal.id: goal};
    final serverGoalMap = {for (var goal in serverGoals) goal.id: goal};
    
    // 处理服务器数据
    for (final serverGoal in serverGoals) {
      final localGoal = localGoalMap[serverGoal.id];
      
      if (localGoal == null) {
        // 新数据，需要插入
        toInsert.add(serverGoal);
      } else {
        // 检查是否有冲突
        if (_hasConflict(localGoal, serverGoal)) {
          final conflict = DataConflict(
            id: '${serverGoal.id}_${DateTime.now().millisecondsSinceEpoch}',
            localData: localGoal,
            serverData: serverGoal,
            detectedAt: DateTime.now(),
            conflictType: 'data_mismatch',
          );
          
          conflicts.add(conflict);
          _conflicts.add(conflict);
          
          // 根据策略解决冲突
          final resolvedGoal = _resolveConflict(localGoal, serverGoal);
          if (resolvedGoal != null) {
            toUpdate.add(resolvedGoal);
          }
        } else if (_shouldUpdate(localGoal, serverGoal)) {
          toUpdate.add(serverGoal);
        }
      }
    }
    
    // 处理本地独有的数据（可能需要删除）
    for (final localGoal in localGoals) {
      if (!serverGoalMap.containsKey(localGoal.id)) {
        toDelete.add(localGoal);
      }
    }
    
    return _MergeResult(
      toUpdate: toUpdate,
      toInsert: toInsert,
      toDelete: toDelete,
      conflicts: conflicts,
    );
  }
  
  /// 检查是否有冲突
  bool _hasConflict(Goal localGoal, Goal serverGoal) {
    // 简化的冲突检测逻辑
    return localGoal.title != serverGoal.title ||
           localGoal.description != serverGoal.description ||
           localGoal.status != serverGoal.status;
  }
  
  /// 判断是否应该更新
  bool _shouldUpdate(Goal localGoal, Goal serverGoal) {
    // 基于最后修改时间判断
    return serverGoal.createdTime.isAfter(localGoal.createdTime);
  }
  
  /// 解决冲突
  Goal? _resolveConflict(Goal localGoal, Goal serverGoal) {
    switch (config.conflictStrategy) {
      case SyncStrategy.serverFirst:
        return serverGoal;
      case SyncStrategy.clientFirst:
        return localGoal;
      case SyncStrategy.lastModified:
        return serverGoal.createdTime.isAfter(localGoal.createdTime) ? serverGoal : localGoal;
      case SyncStrategy.manual:
        return null; // 需要手动解决
    }
  }
  
  /// 批量更新本地数据
  Future<void> _batchUpdateLocalData(List<Goal> goals) async {
    for (final goal in goals) {
      await databaseHelper.updateGoal(goal);
      goalBloc.add(UpdateGoal(goal));
    }
  }
  
  /// 批量插入新数据
  Future<void> _batchInsertNewData(List<Goal> goals) async {
    for (final goal in goals) {
      await databaseHelper.insertGoal(goal);
      goalBloc.add(AddGoal(goal));
    }
  }
  
  /// 批量删除过期数据
  Future<void> _batchDeleteObsoleteData(List<Goal> goals) async {
    for (final goal in goals) {
      await databaseHelper.deleteGoal(goal.id!);
      goalBloc.add(DeleteGoal(goal.id!));
    }
  }
  
  /// 获取本地变更
  Future<List<Goal>> _getLocalChanges(DateTime since) async {
    // 简化实现：获取所有本地目标
    return await databaseHelper.getGoals();
  }
  
  /// 合并增量数据
  Future<_MergeResult> _mergeIncrementalData(List<Goal> localChanges, List<Goal> incrementalData) async {
    // 简化实现：直接使用增量数据
    return _MergeResult(
      toUpdate: incrementalData,
      toInsert: [],
      toDelete: [],
      conflicts: [],
    );
  }
  
  /// 应用增量变更
  Future<void> _applyIncrementalChanges(_MergeResult mergeResult) async {
    await _batchUpdateLocalData(mergeResult.toUpdate);
    await _batchInsertNewData(mergeResult.toInsert);
    await _batchDeleteObsoleteData(mergeResult.toDelete);
  }
  
  /// 获取缓存更新数据
  Future<List<Goal>> _getCacheUpdateData() async {
    // 简化实现：获取所有目标
    return await databaseHelper.getGoals();
  }
  
  /// 识别过期数据
  Future<List<Goal>> _identifyExpiredData() async {
    final allGoals = await databaseHelper.getGoals();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    
    return allGoals.where((goal) => goal.createdTime.isBefore(cutoff)).toList();
  }
  
  /// 启动自动同步
  void _startAutoSync() {
    _autoSyncTimer = Timer.periodic(config.syncInterval, (_) async {
      try {
        await performIncrementalSync();
      } catch (e) {
        debugPrint('Auto sync failed: $e');
      }
    });
  }
  
  /// 停止自动同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }
  
  /// 获取同步状态
  bool get isSyncing => _isSyncing;
  
  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;
  
  /// 获取冲突列表
  List<DataConflict> get conflicts => List.unmodifiable(_conflicts);
  
  /// 获取同步历史
  List<SyncResult> get syncHistory => List.unmodifiable(_syncHistory);
  
  /// 获取同步统计
  SyncStats getSyncStats() {
    final successRate = _totalSyncs == 0 ? 0.0 : _successfulSyncs / _totalSyncs;
    
    return SyncStats(
      totalSyncs: _totalSyncs,
      successfulSyncs: _successfulSyncs,
      failedSyncs: _failedSyncs,
      successRate: successRate,
      lastSyncTime: _lastSyncTime,
      conflictsCount: _conflicts.length,
      isSyncing: _isSyncing,
    );
  }
  
  /// 清理冲突
  void clearConflicts() {
    _conflicts.clear();
  }
  
  /// 释放资源
  void dispose() {
    stopAutoSync();
  }
}

/// 合并结果
class _MergeResult {
  final List<Goal> toUpdate;
  final List<Goal> toInsert;
  final List<Goal> toDelete;
  final List<DataConflict> conflicts;
  
  const _MergeResult({
    required this.toUpdate,
    required this.toInsert,
    required this.toDelete,
    required this.conflicts,
  });
}

/// 同步统计
class SyncStats {
  final int totalSyncs;
  final int successfulSyncs;
  final int failedSyncs;
  final double successRate;
  final DateTime? lastSyncTime;
  final int conflictsCount;
  final bool isSyncing;
  
  const SyncStats({
    required this.totalSyncs,
    required this.successfulSyncs,
    required this.failedSyncs,
    required this.successRate,
    this.lastSyncTime,
    required this.conflictsCount,
    required this.isSyncing,
  });
}
