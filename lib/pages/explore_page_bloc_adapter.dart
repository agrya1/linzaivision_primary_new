import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../models/explore_card.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_event.dart';
import '../bloc/explore/explore_state.dart';
import '../bloc/use_card/use_card_bloc.dart';
import '../bloc/use_card/use_card_event.dart';
import '../bloc/use_card/use_card_state.dart';
import '../utils/performance_utils.dart';

/// ExplorePage BLoC适配器
/// 
/// 这个类作为现有ExplorePage和新的BLoC架构之间的桥梁，实现渐进式重构。
/// 它不会直接替换现有功能，而是并行运行，逐步验证并最终替换。
class ExplorePageBlocAdapter {
  final BuildContext context;
  
  // 日志级别，用于控制日志输出详细程度
  // 0: 不输出日志, 1: 只输出关键日志, 2: 输出详细日志, 3: 输出调试日志
  final int logLevel;
  
  // 执行模式，控制是否真正执行操作或只是记录日志
  // false: 只记录日志不执行, true: 执行操作
  final bool executeMode;
  
  // 性能监控开关
  final bool enablePerformanceMonitoring;
  
  // 构造函数
  ExplorePageBlocAdapter(this.context, {
    this.logLevel = 2,
    this.executeMode = false,
    this.enablePerformanceMonitoring = true,
  });
  
  /// 加载探索卡片
  /// 
  /// 参数:
  /// - onSuccess: 加载成功回调
  /// - onError: 加载失败回调
  void loadExploreCards({
    Function(List<ExploreCard> cards)? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】加载探索卡片');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      const operationId = 'loadExploreCards';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取ExploreBloc实例
      final exploreBloc = BlocProvider.of<ExploreBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<ExploreState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = exploreBloc.stream.listen((state) {
        if (state is ExploreLoaded) {
          _log(1, '【影子模式】探索卡片加载成功: ${state.cards.length}个卡片');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call(state.cards);
          subscription.cancel();
        } else if (state is ExploreError) {
          _log(1, '【影子模式】探索卡片加载失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送加载事件
      exploreBloc.add(FetchExploreCards());
      _log(2, '【影子模式】已发送FetchExploreCards事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('加载探索卡片失败: $e');
    }
  }
  
  /// 切换视图模式
  /// 
  /// 参数:
  /// - viewMode: 视图模式
  /// - onSuccess: 切换成功回调
  /// - onError: 切换失败回调
  void changeViewMode({
    required ViewMode viewMode,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】切换视图模式: $viewMode');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'changeViewMode_${viewMode.toString()}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取ExploreBloc实例
      final exploreBloc = BlocProvider.of<ExploreBloc>(context);
      
      // 发送切换视图模式事件
      exploreBloc.add(ChangeViewMode(viewMode));
      _log(2, '【影子模式】已发送ChangeViewMode事件');
      
      // 结束性能监控
      if (enablePerformanceMonitoring) {
        PerformanceUtils.endOperation(operationId);
      }
      
      onSuccess?.call();
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('切换视图模式失败: $e');
    }
  }
  
  /// 选择卡片
  /// 
  /// 参数:
  /// - card: 要选择的卡片
  /// - onSuccess: 选择成功回调
  /// - onError: 选择失败回调
  void selectCard({
    required ExploreCard card,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】选择卡片: ${card.title}');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'selectCard_${card.id}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取ExploreBloc实例
      final exploreBloc = BlocProvider.of<ExploreBloc>(context);
      
      // 发送选择卡片事件
      exploreBloc.add(SelectCard(card));
      _log(2, '【影子模式】已发送SelectCard事件');
      
      // 结束性能监控
      if (enablePerformanceMonitoring) {
        PerformanceUtils.endOperation(operationId);
      }
      
      onSuccess?.call();
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('选择卡片失败: $e');
    }
  }
  
  /// 开始使用卡片
  /// 
  /// 参数:
  /// - card: 要使用的卡片
  /// - onSuccess: 操作成功回调
  /// - onError: 操作失败回调
  void startUsingCard({
    required ExploreCard card,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】开始使用卡片: ${card.title}');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'startUsingCard_${card.id}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取UseCardBloc实例
      final useCardBloc = BlocProvider.of<UseCardBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<UseCardState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = useCardBloc.stream.listen((state) {
        if (state is EditingCardText) {
          _log(1, '【影子模式】开始编辑卡片文本');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call();
          subscription.cancel();
        } else if (state is UseCardError) {
          _log(1, '【影子模式】使用卡片失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送开始使用卡片事件
      useCardBloc.add(StartUseCard(card));
      _log(2, '【影子模式】已发送StartUseCard事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('开始使用卡片失败: $e');
    }
  }
  
  /// 编辑卡片文本
  /// 
  /// 参数:
  /// - text: 编辑后的文本
  /// - onSuccess: 操作成功回调
  /// - onError: 操作失败回调
  void editCardText({
    required String text,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】编辑卡片文本');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      const operationId = 'editCardText';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取UseCardBloc实例
      final useCardBloc = BlocProvider.of<UseCardBloc>(context);
      
      // 发送编辑卡片文本事件
      useCardBloc.add(EditCardText(text));
      _log(2, '【影子模式】已发送EditCardText事件');
      
      // 结束性能监控
      if (enablePerformanceMonitoring) {
        PerformanceUtils.endOperation(operationId);
      }
      
      onSuccess?.call();
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('编辑卡片文本失败: $e');
    }
  }
  
  /// 保存编辑后的卡片
  /// 
  /// 参数:
  /// - card: 卡片
  /// - editedText: 编辑后的文本
  /// - onSuccess: 保存成功回调
  /// - onError: 保存失败回调
  void saveEditedCard({
    required ExploreCard card,
    required String editedText,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】保存编辑后的卡片: ${card.title}');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'saveEditedCard_${card.id}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取ExploreBloc实例
      final exploreBloc = BlocProvider.of<ExploreBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<ExploreState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = exploreBloc.stream.listen((state) {
        if (state is ExploreLoaded) {
          _log(1, '【影子模式】卡片保存成功');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call();
          subscription.cancel();
        } else if (state is ExploreError) {
          _log(1, '【影子模式】卡片保存失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送保存编辑后的卡片事件
      exploreBloc.add(SaveEditedCard(card: card, editedText: editedText));
      _log(2, '【影子模式】已发送SaveEditedCard事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('保存卡片失败: $e');
    }
  }
  
  /// 切换分类
  /// 
  /// 参数:
  /// - category: 分类名称
  /// - onSuccess: 切换成功回调
  /// - onError: 切换失败回调
  void changeCategory({
    required String category,
    VoidCallback? onSuccess,
    Function(String error)? onError,
  }) {
    _log(1, '【影子模式】切换分类: $category');
    
    if (!executeMode) {
      _log(2, '【影子模式】执行模式关闭，不发送BLoC事件');
      return;
    }
    
    try {
      // 开始性能监控
      final operationId = 'changeCategory_${category.hashCode}';
      if (enablePerformanceMonitoring) {
        PerformanceUtils.startOperation(operationId);
      }
      
      // 获取ExploreBloc实例
      final exploreBloc = BlocProvider.of<ExploreBloc>(context);
      
      // 声明监听器变量
      late final StreamSubscription<ExploreState> subscription;
      
      // 添加监听器，只监听一次结果
      subscription = exploreBloc.stream.listen((state) {
        if (state is ExploreLoaded && state.activeCategory == category) {
          _log(1, '【影子模式】分类切换成功: $category');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation(operationId);
          }
          
          onSuccess?.call();
          subscription.cancel();
        } else if (state is ExploreError) {
          _log(1, '【影子模式】分类切换失败: ${state.message}');
          
          // 结束性能监控
          if (enablePerformanceMonitoring) {
            PerformanceUtils.endOperation('${operationId}_error');
          }
          
          onError?.call(state.message);
          subscription.cancel();
        }
      });
      
      // 发送切换分类事件
      exploreBloc.add(ChangeCategory(category));
      _log(2, '【影子模式】已发送ChangeCategory事件');
    } catch (e) {
      _log(1, '【影子模式】发送BLoC事件失败: $e');
      onError?.call('切换分类失败: $e');
    }
  }
  
  /// 获取性能统计数据
  /// 
  /// 返回各操作的性能统计信息
  Map<String, Map<String, dynamic>> getPerformanceStats() {
    final result = <String, Map<String, dynamic>>{};
    
    // 获取所有操作的统计信息
    final operations = [
      'loadExploreCards',
      'changeViewMode',
      'selectCard',
      'startUsingCard',
      'editCardText',
      'saveEditedCard',
      'changeCategory',
    ];
    
    for (final operation in operations) {
      result[operation] = PerformanceUtils.getOperationStats(operation);
    }
    
    return result;
  }
  
  /// 输出性能统计信息
  void printPerformanceStats() {
    if (!enablePerformanceMonitoring) {
      _log(1, '【影子模式】性能监控未启用');
      return;
    }
    
    PerformanceUtils.printAllStats();
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
} 