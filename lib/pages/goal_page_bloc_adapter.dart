import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'dart:async';
import '../models/goal.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/search/search_bloc.dart';
import '../bloc/search/search_event.dart';
import '../bloc/search/search_state.dart';
import '../utils/error_handler.dart';
import '../utils/performance_utils.dart';
import '../utils/bloc_feature_toggles.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'goal_page.dart'; // 导入GoalPage

/// GoalPage BLoC适配器
/// 
/// 这个类作为现有GoalPage和新的BLoC架构之间的桥梁，实现渐进式重构。
/// 它不会直接替换现有功能，而是并行运行，逐步验证并最终替换。
class GoalPageBlocAdapter {
  final BuildContext context;
  final int logLevel;
  final bool executeMode;
  final bool enablePerformanceMonitoring;
  
  // 性能统计数据
  final Map<String, Map<String, dynamic>> _performanceStats = {};
  
  GoalPageBlocAdapter(
    this.context, {
    this.logLevel = 1,
    this.executeMode = false,
    this.enablePerformanceMonitoring = false,
  }) {
    _log(1, '【影子模式】初始化BLoC适配器, 执行模式: $executeMode');
    
    if (enablePerformanceMonitoring) {
      _log(2, '【影子模式】已启用性能监控');
    }
  }
  
  /// 加载目标数据
  void loadGoals({
    int? parentId,
    Function(List<Goal> goals, List<Goal> allGoals)? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】加载目标数据, 父ID: ${parentId ?? "根目标"}');
    
    try {
      // 开始性能监控
      final operationId = 'loadGoals_${parentId ?? "root"}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】加载目标成功: ${state.goals.length} 个目标');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalsCount': state.goals.length},
            );
          }
          
          // 触发回调，传递数据
          onSuccess?.call(state.goals, state.allGoals);
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】加载目标失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送加载事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(LoadGoals(parentId: parentId));
      _log(2, '【影子模式】已发送LoadGoals事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('加载目标失败: $e');
    }
  }
  
  /// 刷新目标树
  void refreshGoalTree({
    Function(List<Goal> allGoals)? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】刷新目标树');
    
    try {
      // 开始性能监控
      final operationId = 'refreshGoalTree';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】目标树刷新成功: ${state.allGoals.length}个目标');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'allGoalsCount': state.allGoals.length},
            );
          }
          
          // 触发回调，传递数据
          onSuccess?.call(state.allGoals);
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】目标树刷新失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送刷新事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(const RefreshGoalTree());
      _log(2, '【影子模式】已发送RefreshGoalTree事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('刷新目标树失败: $e');
    }
  }
  
  /// 添加目标
  void addGoal({
    required Goal goal,
    Function(Goal goal)? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】添加目标: ${goal.title}');
    
    try {
      // 开始性能监控
      final operationId = 'addGoal';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded && state.lastAddedGoal != null) {
          _log(1, '【影子模式】添加目标成功: ${state.lastAddedGoal!.id}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalId': state.lastAddedGoal!.id},
            );
          }
          
          // 触发回调，传递数据
          onSuccess?.call(state.lastAddedGoal!);
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】添加目标失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送添加事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(AddGoal(goal));
      _log(2, '【影子模式】已发送AddGoal事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('添加目标失败: $e');
    }
  }
  
  /// 更新目标
  void updateGoal({
    required Goal goal,
    Function()? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】更新目标: ${goal.id}');
    
    try {
      // 开始性能监控
      final operationId = 'updateGoal';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】更新目标成功: ${goal.id}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalId': goal.id},
            );
          }
          
          // 触发回调
          onSuccess?.call();
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】更新目标失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送更新事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(UpdateGoal(goal));
      _log(2, '【影子模式】已发送UpdateGoal事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('更新目标失败: $e');
    }
  }
  
  /// 删除目标
  void deleteGoal({
    required int goalId,
    Function()? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】删除目标: $goalId');
    
    try {
      // 开始性能监控
      final operationId = 'deleteGoal';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】删除目标成功: $goalId');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalId': goalId},
            );
          }
          
          // 触发回调
          onSuccess?.call();
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】删除目标失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送删除事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(DeleteGoal(goalId));
      _log(2, '【影子模式】已发送DeleteGoal事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('删除目标失败: $e');
    }
  }
  
  /// 保存初始目标数据
  void saveInitialGoals({
    required List<Goal> goals,
    Function()? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】保存初始目标数据: ${goals.length} 个目标');
    
    try {
      // 开始性能监控
      final operationId = 'saveInitialGoals';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】保存初始目标数据成功');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalsCount': goals.length},
            );
          }
          
          // 触发回调
          onSuccess?.call();
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】保存初始目标数据失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送保存初始目标事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(SaveInitialGoals(goals));
      _log(2, '【影子模式】已发送SaveInitialGoals事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('保存初始目标数据失败: $e');
    }
  }
  
  /// 获取性能统计数据
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    return PerformanceUtils.getAllStats();
  }
  
  /// 打印性能统计数据
  void printPerformanceStats() {
    _log(1, '【影子模式】性能统计数据:');
    PerformanceUtils.printAllStats();
  }
  
  /// 记录操作结果，用于性能监控和比较
  void recordOperationResult({
    required String operation,
    required bool success,
    Map<String, dynamic>? data,
  }) {
    // 记录操作结果到日志
    _log(2, '【性能监控】操作: $operation, 结果: ${success ? "成功" : "失败"}');
    
    // 如果有数据，也记录下来
    if (data != null && data.isNotEmpty) {
      _log(3, '【性能监控】数据: $data');
    }
  }
  
  /// 记录日志
  /// 
  /// 参数:
  /// - level: 日志级别
  /// - message: 日志消息
  void _log(int level, String message) {
    if (level <= logLevel) {
      debugPrint(message);
    }
  }

  /// 更新目标日期
  void updateGoalDate({
    required Goal goal,
    DateTime? newDate,
    Function()? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】更新目标日期: ${goal.id}, 新日期: ${newDate?.toString() ?? "无"}');
    
    try {
      // 开始性能监控
      final operationId = 'updateGoalDate';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 创建更新后的目标
      final updatedGoal = goal.copyWith(targetDate: newDate);
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded) {
          _log(1, '【影子模式】更新目标日期成功: ${goal.id}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalId': goal.id, 'newDate': newDate?.toString()},
            );
          }
          
          // 触发回调
          onSuccess?.call();
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】更新目标日期失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送更新事件 - 即使在影子模式下也发送事件，但不会影响UI
      goalBloc.add(UpdateGoalDate(updatedGoal, newDate));
      _log(2, '【影子模式】已发送UpdateGoalDate事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('更新目标日期失败: $e');
    }
  }
  
  /// 加载特定目标
  void loadSpecificGoal({
    required int goalId,
    Function(Goal goal)? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】加载特定目标: $goalId');
    
    try {
      // 开始性能监控
      final operationId = 'loadSpecificGoal_$goalId';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取GoalBloc实例
      final goalBloc = BlocProvider.of<GoalBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<GoalState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = goalBloc.stream.listen((state) {
        if (state is GoalsLoaded && state.currentGoal != null) {
          final loadedGoal = state.currentGoal!;
          _log(1, '【影子模式】加载特定目标成功: ID=${loadedGoal.id}, 标题=${loadedGoal.title}');
          
          // 检查加载的目标ID是否与请求的ID匹配
          if (loadedGoal.id != goalId) {
            _log(1, '【影子模式】警告：加载的目标ID(${loadedGoal.id})与请求的ID($goalId)不匹配');
          }
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              data: {'goalId': loadedGoal.id, 'requestedId': goalId},
            );
          }
          
          // 触发回调，传递数据
          onSuccess?.call(loadedGoal);
          subscription.cancel();
        } else if (state is GoalError) {
          _log(1, '【影子模式】加载特定目标失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(
              operationId,
              success: false,
              message: state.message,
            );
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送加载特定目标事件 - 即使在影子模式下也发送事件，但不会影响UI
      _log(2, '【影子模式】发送LoadSpecificGoal事件，goalId: $goalId');
      goalBloc.add(LoadSpecificGoal(goalId));
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('加载特定目标失败: $e');
    }
  }
} 