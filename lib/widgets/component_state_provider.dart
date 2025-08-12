import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../utils/component_state_manager.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/goal/goal_event.dart';
import '../bloc/explore/explore_bloc.dart';
import '../bloc/explore/explore_event.dart';
import '../bloc/shared/shared_state_bloc.dart';

/// 组件状态提供者
///
/// 为组件树提供统一的状态管理访问接口，与现有Provider系统无缝集成
class ComponentStateProvider extends InheritedWidget {
  final ComponentStateManager stateManager;

  const ComponentStateProvider({
    Key? key,
    required this.stateManager,
    required Widget child,
  }) : super(key: key, child: child);

  /// 从上下文中获取ComponentStateProvider
  static ComponentStateProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ComponentStateProvider>();
  }

  /// 从上下文中获取ComponentStateProvider（必须存在）
  static ComponentStateProvider of(BuildContext context) {
    final provider = maybeOf(context);
    if (provider == null) {
      throw FlutterError(
        'ComponentStateProvider.of() called with a context that does not contain a ComponentStateProvider.\n'
        'No ComponentStateProvider ancestor could be found starting from the context that was passed to ComponentStateProvider.of().\n'
        'This usually happens when the context provided is from the same StatefulWidget as that whose build function actually creates the ComponentStateProvider widget being sought.\n'
        'Please ensure that ComponentStateProvider is an ancestor of the widget that calls ComponentStateProvider.of().',
      );
    }
    return provider;
  }

  /// 从上下文中获取ComponentStateManager
  static ComponentStateManager? maybeManagerOf(BuildContext context) {
    return maybeOf(context)?.stateManager;
  }

  /// 从上下文中获取ComponentStateManager（必须存在）
  static ComponentStateManager managerOf(BuildContext context) {
    return of(context).stateManager;
  }

  @override
  bool updateShouldNotify(ComponentStateProvider oldWidget) {
    return stateManager != oldWidget.stateManager;
  }
}

/// 组件状态构建器
///
/// 提供便捷的状态监听和构建接口
class ComponentStateBuilder extends StatefulWidget {
  final Widget Function(
      BuildContext context, ComponentStateManager stateManager) builder;
  final List<String>? listenToKeys;
  final bool rebuildOnAnyChange;

  const ComponentStateBuilder({
    Key? key,
    required this.builder,
    this.listenToKeys,
    this.rebuildOnAnyChange = true,
  }) : super(key: key);

  @override
  State<ComponentStateBuilder> createState() => _ComponentStateBuilderState();
}

class _ComponentStateBuilderState extends State<ComponentStateBuilder> {
  ComponentStateManager? _stateManager;
  final List<VoidCallback> _listeners = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newStateManager = ComponentStateProvider.maybeManagerOf(context);
    if (newStateManager != _stateManager) {
      _removeListeners();
      _stateManager = newStateManager;
      _addListeners();
    }
  }

  void _addListeners() {
    if (_stateManager == null) return;

    if (widget.rebuildOnAnyChange) {
      // 监听所有状态变化
      _stateManager!.addListener(_onStateChanged);
    } else if (widget.listenToKeys != null) {
      // 只监听指定键的变化
      for (final key in widget.listenToKeys!) {
        final listener = () => _onStateChanged();
        _listeners.add(listener);
        _stateManager!.addStateListener(key, listener);
      }
    }
  }

  void _removeListeners() {
    if (_stateManager == null) return;

    if (widget.rebuildOnAnyChange) {
      _stateManager!.removeListener(_onStateChanged);
    } else if (widget.listenToKeys != null) {
      for (int i = 0;
          i < widget.listenToKeys!.length && i < _listeners.length;
          i++) {
        _stateManager!
            .removeStateListener(widget.listenToKeys![i], _listeners[i]);
      }
      _listeners.clear();
    }
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateManager = ComponentStateProvider.maybeManagerOf(context);
    if (stateManager == null) {
      return const SizedBox.shrink();
    }

    return widget.builder(context, stateManager);
  }
}

/// 组件状态消费者
///
/// 简化的状态消费接口，类似于BlocConsumer
class ComponentStateConsumer<T> extends StatefulWidget {
  final String stateKey;
  final Widget Function(BuildContext context, T? value) builder;
  final void Function(BuildContext context, T? value)? listener;
  final bool Function(T? previous, T? current)? listenWhen;
  final bool Function(T? previous, T? current)? buildWhen;

  const ComponentStateConsumer({
    Key? key,
    required this.stateKey,
    required this.builder,
    this.listener,
    this.listenWhen,
    this.buildWhen,
  }) : super(key: key);

  @override
  State<ComponentStateConsumer<T>> createState() =>
      _ComponentStateConsumerState<T>();
}

class _ComponentStateConsumerState<T> extends State<ComponentStateConsumer<T>> {
  ComponentStateManager? _stateManager;
  T? _previousValue;
  VoidCallback? _stateListener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newStateManager = ComponentStateProvider.maybeManagerOf(context);
    if (newStateManager != _stateManager) {
      _removeListener();
      _stateManager = newStateManager;
      _addListener();
      _previousValue = _stateManager?.getState<T>(widget.stateKey);
    }
  }

  void _addListener() {
    if (_stateManager == null) return;

    _stateListener = () => _onStateChanged();
    _stateManager!.addStateListener(widget.stateKey, _stateListener!);
  }

  void _removeListener() {
    if (_stateManager != null && _stateListener != null) {
      _stateManager!.removeStateListener(widget.stateKey, _stateListener!);
    }
  }

  void _onStateChanged() {
    if (!mounted) return;

    final currentValue = _stateManager?.getState<T>(widget.stateKey);

    // 检查是否需要触发listener
    if (widget.listener != null) {
      final shouldListen =
          widget.listenWhen?.call(_previousValue, currentValue) ?? true;
      if (shouldListen) {
        widget.listener!(context, currentValue);
      }
    }

    // 检查是否需要重建
    final shouldBuild =
        widget.buildWhen?.call(_previousValue, currentValue) ?? true;
    if (shouldBuild) {
      setState(() {
        _previousValue = currentValue;
      });
    } else {
      _previousValue = currentValue;
    }
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentValue = _stateManager?.getState<T>(widget.stateKey);
    return widget.builder(context, currentValue);
  }
}

/// 自动组件状态提供者
///
/// 自动创建ComponentStateManager并提供给子组件树
class AutoComponentStateProvider extends StatefulWidget {
  final Widget child;
  final String pageName;
  final bool enableSharedState;

  const AutoComponentStateProvider({
    Key? key,
    required this.child,
    this.pageName = 'auto_component_state',
    this.enableSharedState = true,
  }) : super(key: key);

  @override
  State<AutoComponentStateProvider> createState() =>
      _AutoComponentStateProviderState();
}

class _AutoComponentStateProviderState
    extends State<AutoComponentStateProvider> {
  ComponentStateManager? _stateManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_stateManager == null) {
      _createStateManager();
    }
  }

  void _createStateManager() {
    try {
      final goalBloc = context.read<GoalBloc>();
      final exploreBloc = context.read<ExploreBloc>();
      final sharedStateBloc =
          widget.enableSharedState ? context.read<SharedStateBloc?>() : null;

      _stateManager = ComponentStateManager(
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
        sharedStateBloc: sharedStateBloc,
        pageName: widget.pageName,
      );

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('【AutoComponentStateProvider】创建状态管理器失败: $e');
    }
  }

  @override
  void dispose() {
    _stateManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_stateManager == null) {
      return widget.child;
    }

    return ComponentStateProvider(
      stateManager: _stateManager!,
      child: widget.child,
    );
  }
}

/// 组件状态扩展方法
extension ComponentStateExtension on BuildContext {
  /// 获取ComponentStateManager
  ComponentStateManager? get componentStateManager {
    return ComponentStateProvider.maybeManagerOf(this);
  }

  /// 获取组件状态值
  T? getComponentState<T>(String key) {
    return componentStateManager?.getState<T>(key);
  }

  /// 设置组件状态值
  void setComponentState<T>(String key, T value) {
    componentStateManager?.setState(key, value);
  }

  /// 分发Goal事件
  void dispatchGoalEvent(GoalEvent event) {
    componentStateManager?.dispatchGoalEvent(event);
  }

  /// 分发Explore事件
  void dispatchExploreEvent(ExploreEvent event) {
    componentStateManager?.dispatchExploreEvent(event);
  }
}
