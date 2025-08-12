/// 事务管理器
///
/// 负责管理复杂操作的事务处理，确保操作的原子性、一致性、隔离性和持久性
library;

import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// 事务状态
enum TransactionStatus {
  pending, // 待执行
  executing, // 执行中
  completed, // 已完成
  failed, // 执行失败
  rolledBack, // 已回滚
  cancelled, // 已取消
}

/// 事务隔离级别
enum IsolationLevel {
  readUncommitted, // 读未提交
  readCommitted, // 读已提交
  repeatableRead, // 可重复读
  serializable, // 串行化
}

/// 事务优先级
enum TransactionPriority {
  low, // 低优先级
  normal, // 普通优先级
  high, // 高优先级
  critical, // 关键优先级
}

/// 事务操作
abstract class TransactionOperation {
  final String id;
  final String description;
  final Duration timeout;
  final List<String> dependencies;

  const TransactionOperation({
    required this.id,
    required this.description,
    this.timeout = const Duration(seconds: 30),
    this.dependencies = const [],
  });

  /// 执行操作
  Future<TransactionOperationResult> execute();

  /// 回滚操作
  Future<void> rollback();

  /// 验证操作前置条件
  Future<bool> validate();

  /// 获取操作影响的资源
  Set<String> getAffectedResources();
}

/// 事务操作结果
class TransactionOperationResult {
  final bool success;
  final String? error;
  final Map<String, dynamic> data;
  final Duration executionTime;

  const TransactionOperationResult({
    required this.success,
    this.error,
    this.data = const {},
    required this.executionTime,
  });

  factory TransactionOperationResult.success({
    Map<String, dynamic> data = const {},
    required Duration executionTime,
  }) {
    return TransactionOperationResult(
      success: true,
      data: data,
      executionTime: executionTime,
    );
  }

  factory TransactionOperationResult.failure({
    required String error,
    required Duration executionTime,
  }) {
    return TransactionOperationResult(
      success: false,
      error: error,
      executionTime: executionTime,
    );
  }
}

/// 事务上下文
class TransactionContext {
  final String transactionId;
  final IsolationLevel isolationLevel;
  final TransactionPriority priority;
  final Map<String, dynamic> metadata;
  final DateTime startTime;

  TransactionContext({
    required this.transactionId,
    this.isolationLevel = IsolationLevel.readCommitted,
    this.priority = TransactionPriority.normal,
    this.metadata = const {},
    DateTime? startTime,
  }) : startTime = startTime ?? DateTime.now();

  /// 获取事务运行时长
  Duration get duration => DateTime.now().difference(startTime);
}

/// 事务
class Transaction {
  final String id;
  final String description;
  final List<TransactionOperation> operations;
  final TransactionContext context;
  final Duration timeout;

  TransactionStatus _status = TransactionStatus.pending;
  final List<TransactionOperationResult> _results = [];
  final List<String> _executedOperations = [];
  String? _error;
  DateTime? _startTime;
  DateTime? _endTime;

  Transaction({
    required this.id,
    required this.description,
    required this.operations,
    required this.context,
    this.timeout = const Duration(minutes: 5),
  });

  /// 事务状态
  TransactionStatus get status => _status;

  /// 错误信息
  String? get error => _error;

  /// 开始时间
  DateTime? get startTime => _startTime;

  /// 结束时间
  DateTime? get endTime => _endTime;

  /// 执行时长
  Duration? get duration {
    if (_startTime == null) return null;
    final end = _endTime ?? DateTime.now();
    return end.difference(_startTime!);
  }

  /// 操作结果
  List<TransactionOperationResult> get results => List.unmodifiable(_results);

  /// 已执行的操作
  List<String> get executedOperations => List.unmodifiable(_executedOperations);

  /// 设置状态
  void _setStatus(TransactionStatus status) {
    _status = status;
    if (status == TransactionStatus.executing && _startTime == null) {
      _startTime = DateTime.now();
    } else if ([
      TransactionStatus.completed,
      TransactionStatus.failed,
      TransactionStatus.rolledBack,
      TransactionStatus.cancelled
    ].contains(status)) {
      _endTime = DateTime.now();
    }
  }

  /// 添加操作结果
  void _addResult(String operationId, TransactionOperationResult result) {
    _results.add(result);
    if (result.success) {
      _executedOperations.add(operationId);
    }
  }

  /// 设置错误
  void _setError(String error) {
    _error = error;
  }

  /// 获取影响的资源
  Set<String> getAffectedResources() {
    final resources = <String>{};
    for (final operation in operations) {
      resources.addAll(operation.getAffectedResources());
    }
    return resources;
  }

  /// 检查资源冲突
  bool hasResourceConflict(Transaction other) {
    final myResources = getAffectedResources();
    final otherResources = other.getAffectedResources();
    return myResources.intersection(otherResources).isNotEmpty;
  }
}

/// 事务管理器
class TransactionManager {
  static final TransactionManager _instance = TransactionManager._internal();
  factory TransactionManager() => _instance;
  TransactionManager._internal();

  final Map<String, Transaction> _transactions = {};
  final Queue<Transaction> _pendingQueue = Queue<Transaction>();
  final Set<Transaction> _executingTransactions = <Transaction>{};
  final Map<String, Set<String>> _resourceLocks = {};

  /// 事务状态流
  final StreamController<TransactionEvent> _eventController =
      StreamController<TransactionEvent>.broadcast();

  Stream<TransactionEvent> get events => _eventController.stream;

  /// 创建事务
  Transaction createTransaction({
    required String description,
    required List<TransactionOperation> operations,
    IsolationLevel isolationLevel = IsolationLevel.readCommitted,
    TransactionPriority priority = TransactionPriority.normal,
    Duration timeout = const Duration(minutes: 5),
    Map<String, dynamic> metadata = const {},
  }) {
    final transactionId = _generateTransactionId();
    final context = TransactionContext(
      transactionId: transactionId,
      isolationLevel: isolationLevel,
      priority: priority,
      metadata: metadata,
    );

    final transaction = Transaction(
      id: transactionId,
      description: description,
      operations: operations,
      context: context,
      timeout: timeout,
    );

    _transactions[transactionId] = transaction;
    _emitEvent(TransactionEvent.created(transaction));

    return transaction;
  }

  /// 提交事务
  Future<TransactionResult> commitTransaction(String transactionId) async {
    final transaction = _transactions[transactionId];
    if (transaction == null) {
      throw ArgumentError('Transaction not found: $transactionId');
    }

    if (transaction.status != TransactionStatus.pending) {
      throw StateError(
          'Transaction is not in pending state: ${transaction.status}');
    }

    // 检查资源冲突
    if (_hasResourceConflict(transaction)) {
      _addToQueue(transaction);
      _emitEvent(TransactionEvent.queued(transaction));
      return TransactionResult.queued(transactionId);
    }

    return await _executeTransaction(transaction);
  }

  /// 执行事务
  Future<TransactionResult> _executeTransaction(Transaction transaction) async {
    try {
      transaction._setStatus(TransactionStatus.executing);
      _executingTransactions.add(transaction);
      _lockResources(transaction);
      _emitEvent(TransactionEvent.started(transaction));

      // 验证所有操作
      for (final operation in transaction.operations) {
        if (!await operation.validate()) {
          throw TransactionException(
              'Operation validation failed: ${operation.id}');
        }
      }

      // 按依赖关系排序操作
      final sortedOperations =
          _sortOperationsByDependencies(transaction.operations);

      // 执行操作
      for (final operation in sortedOperations) {
        final stopwatch = Stopwatch()..start();

        try {
          final result = await operation.execute().timeout(operation.timeout);
          stopwatch.stop();

          transaction._addResult(
              operation.id,
              TransactionOperationResult.success(
                data: result.data,
                executionTime: stopwatch.elapsed,
              ));

          _emitEvent(
              TransactionEvent.operationCompleted(transaction, operation.id));
        } catch (e) {
          stopwatch.stop();
          transaction._addResult(
              operation.id,
              TransactionOperationResult.failure(
                error: e.toString(),
                executionTime: stopwatch.elapsed,
              ));

          throw TransactionException('Operation failed: ${operation.id} - $e');
        }
      }

      transaction._setStatus(TransactionStatus.completed);
      _emitEvent(TransactionEvent.completed(transaction));

      return TransactionResult.success(transaction.id, transaction.results);
    } catch (e) {
      transaction._setError(e.toString());
      transaction._setStatus(TransactionStatus.failed);
      _emitEvent(TransactionEvent.failed(transaction, e.toString()));

      // 回滚已执行的操作
      await _rollbackTransaction(transaction);

      return TransactionResult.failure(transaction.id, e.toString());
    } finally {
      _executingTransactions.remove(transaction);
      _unlockResources(transaction);
      _processQueue();
    }
  }

  /// 回滚事务
  Future<void> _rollbackTransaction(Transaction transaction) async {
    try {
      // 按相反顺序回滚已执行的操作
      final executedOperations = transaction.executedOperations.reversed;

      for (final operationId in executedOperations) {
        final operation =
            transaction.operations.firstWhere((op) => op.id == operationId);
        try {
          await operation.rollback();
        } catch (e) {
          debugPrint('Rollback failed for operation $operationId: $e');
        }
      }

      transaction._setStatus(TransactionStatus.rolledBack);
      _emitEvent(TransactionEvent.rolledBack(transaction));
    } catch (e) {
      debugPrint('Transaction rollback failed: $e');
    }
  }

  /// 取消事务
  Future<void> cancelTransaction(String transactionId) async {
    final transaction = _transactions[transactionId];
    if (transaction == null) return;

    if (transaction.status == TransactionStatus.pending) {
      _pendingQueue.remove(transaction);
      transaction._setStatus(TransactionStatus.cancelled);
      _emitEvent(TransactionEvent.cancelled(transaction));
    } else if (transaction.status == TransactionStatus.executing) {
      // 正在执行的事务需要等待当前操作完成后取消
      transaction._setStatus(TransactionStatus.cancelled);
      _emitEvent(TransactionEvent.cancelled(transaction));
    }
  }

  /// 生成事务ID
  String _generateTransactionId() {
    return 'tx_${DateTime.now().millisecondsSinceEpoch}_${_transactions.length}';
  }

  /// 检查资源冲突
  bool _hasResourceConflict(Transaction transaction) {
    for (final executingTransaction in _executingTransactions) {
      if (executingTransaction.hasResourceConflict(transaction)) {
        return true;
      }
    }

    return false;
  }

  /// 添加到队列
  void _addToQueue(Transaction transaction) {
    // 按优先级插入队列
    final priority = transaction.context.priority;

    if (_pendingQueue.isEmpty || priority == TransactionPriority.critical) {
      _pendingQueue.addFirst(transaction);
    } else {
      // 找到合适的插入位置
      final list = _pendingQueue.toList();
      int insertIndex = list.length;

      for (int i = 0; i < list.length; i++) {
        if (_getPriorityValue(priority) >
            _getPriorityValue(list[i].context.priority)) {
          insertIndex = i;
          break;
        }
      }

      _pendingQueue.clear();
      _pendingQueue.addAll(list.take(insertIndex));
      _pendingQueue.add(transaction);
      _pendingQueue.addAll(list.skip(insertIndex));
    }
  }

  /// 获取优先级数值
  int _getPriorityValue(TransactionPriority priority) {
    switch (priority) {
      case TransactionPriority.low:
        return 1;
      case TransactionPriority.normal:
        return 2;
      case TransactionPriority.high:
        return 3;
      case TransactionPriority.critical:
        return 4;
    }
  }

  /// 锁定资源
  void _lockResources(Transaction transaction) {
    final resources = transaction.getAffectedResources();
    for (final resource in resources) {
      _resourceLocks
          .putIfAbsent(resource, () => <String>{})
          .add(transaction.id);
    }
  }

  /// 解锁资源
  void _unlockResources(Transaction transaction) {
    final resources = transaction.getAffectedResources();
    for (final resource in resources) {
      _resourceLocks[resource]?.remove(transaction.id);
      if (_resourceLocks[resource]?.isEmpty == true) {
        _resourceLocks.remove(resource);
      }
    }
  }

  /// 处理队列
  void _processQueue() {
    while (_pendingQueue.isNotEmpty) {
      final transaction = _pendingQueue.first;

      if (!_hasResourceConflict(transaction)) {
        _pendingQueue.removeFirst();
        _executeTransaction(transaction);
        break;
      } else {
        break; // 如果第一个事务有冲突，后面的也需要等待
      }
    }
  }

  /// 按依赖关系排序操作
  List<TransactionOperation> _sortOperationsByDependencies(
      List<TransactionOperation> operations) {
    final sorted = <TransactionOperation>[];
    final remaining = List<TransactionOperation>.from(operations);
    final processed = <String>{};

    while (remaining.isNotEmpty) {
      bool found = false;

      for (int i = 0; i < remaining.length; i++) {
        final operation = remaining[i];
        final canExecute =
            operation.dependencies.every((dep) => processed.contains(dep));

        if (canExecute) {
          sorted.add(operation);
          processed.add(operation.id);
          remaining.removeAt(i);
          found = true;
          break;
        }
      }

      if (!found) {
        throw TransactionException(
            'Circular dependency detected in operations');
      }
    }

    return sorted;
  }

  /// 发送事件
  void _emitEvent(TransactionEvent event) {
    _eventController.add(event);
  }

  /// 获取事务信息
  Transaction? getTransaction(String transactionId) {
    return _transactions[transactionId];
  }

  /// 获取所有事务
  List<Transaction> getAllTransactions() {
    return List.unmodifiable(_transactions.values);
  }

  /// 获取执行中的事务
  List<Transaction> getExecutingTransactions() {
    return List.unmodifiable(_executingTransactions);
  }

  /// 获取队列中的事务
  List<Transaction> getQueuedTransactions() {
    return List.unmodifiable(_pendingQueue);
  }

  /// 清理已完成的事务
  void cleanupCompletedTransactions({Duration? olderThan}) {
    final cutoff = olderThan != null
        ? DateTime.now().subtract(olderThan)
        : DateTime.now().subtract(const Duration(hours: 1));

    final toRemove = <String>[];

    for (final entry in _transactions.entries) {
      final transaction = entry.value;
      if ([
            TransactionStatus.completed,
            TransactionStatus.failed,
            TransactionStatus.rolledBack,
            TransactionStatus.cancelled
          ].contains(transaction.status) &&
          transaction.endTime != null &&
          transaction.endTime!.isBefore(cutoff)) {
        toRemove.add(entry.key);
      }
    }

    for (final id in toRemove) {
      _transactions.remove(id);
    }
  }

  /// 关闭管理器
  void dispose() {
    _eventController.close();
  }
}

/// 事务结果
class TransactionResult {
  final String transactionId;
  final bool success;
  final String? error;
  final List<TransactionOperationResult>? results;
  final bool queued;

  const TransactionResult({
    required this.transactionId,
    required this.success,
    this.error,
    this.results,
    this.queued = false,
  });

  factory TransactionResult.success(
      String transactionId, List<TransactionOperationResult> results) {
    return TransactionResult(
      transactionId: transactionId,
      success: true,
      results: results,
    );
  }

  factory TransactionResult.failure(String transactionId, String error) {
    return TransactionResult(
      transactionId: transactionId,
      success: false,
      error: error,
    );
  }

  factory TransactionResult.queued(String transactionId) {
    return TransactionResult(
      transactionId: transactionId,
      success: false,
      queued: true,
    );
  }
}

/// 事务事件
class TransactionEvent {
  final String type;
  final Transaction transaction;
  final String? operationId;
  final String? error;
  final DateTime timestamp;

  TransactionEvent({
    required this.type,
    required this.transaction,
    this.operationId,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory TransactionEvent.created(Transaction transaction) {
    return TransactionEvent(type: 'created', transaction: transaction);
  }

  factory TransactionEvent.queued(Transaction transaction) {
    return TransactionEvent(type: 'queued', transaction: transaction);
  }

  factory TransactionEvent.started(Transaction transaction) {
    return TransactionEvent(type: 'started', transaction: transaction);
  }

  factory TransactionEvent.operationCompleted(
      Transaction transaction, String operationId) {
    return TransactionEvent(
        type: 'operation_completed',
        transaction: transaction,
        operationId: operationId);
  }

  factory TransactionEvent.completed(Transaction transaction) {
    return TransactionEvent(type: 'completed', transaction: transaction);
  }

  factory TransactionEvent.failed(Transaction transaction, String error) {
    return TransactionEvent(
        type: 'failed', transaction: transaction, error: error);
  }

  factory TransactionEvent.rolledBack(Transaction transaction) {
    return TransactionEvent(type: 'rolled_back', transaction: transaction);
  }

  factory TransactionEvent.cancelled(Transaction transaction) {
    return TransactionEvent(type: 'cancelled', transaction: transaction);
  }
}

/// 事务异常
class TransactionException implements Exception {
  final String message;

  const TransactionException(this.message);

  @override
  String toString() => 'TransactionException: $message';
}
