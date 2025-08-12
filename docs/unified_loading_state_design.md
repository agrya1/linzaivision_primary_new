# 统一加载状态管理设计方案

## 🎯 设计目标

**核心目标**: 建立统一的加载状态管理机制，解决当前加载流程的复杂性问题  
**设计原则**: 
- 🎯 **统一性** - 所有加载操作使用相同的状态管理模式
- ⚡ **高效性** - 避免重复加载，优化关键路径
- 🔄 **可控性** - 支持加载优先级和依赖管理
- 📊 **可观测性** - 提供详细的加载进度和错误信息

## 📐 整体架构设计

### 1. 三层加载状态管理架构

```
┌─────────────────────────────────────────────────────────────┐
│                 LoadingManager Layer (加载管理层)             │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  LoadingBloc    │  │ LoadingOrchest- │                   │
│  │                 │  │     rator       │                   │
│  └─────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                LoadingState Layer (状态层)                   │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │  LoadingState   │  │  LoadingTask    │                   │
│  │    Hierarchy    │  │    Manager      │                   │
│  └─────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   UI Layer (界面层)                          │
│  ┌─────────────────┐  ┌─────────────────┐                   │
│  │ LoadingIndicator│  │  ErrorHandler   │                   │
│  │    Widgets      │  │    Widgets      │                   │
│  └─────────────────┘  └─────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### 2. 核心组件设计

#### A. LoadingState 状态层次结构
```dart
/// 统一的加载状态基类
abstract class LoadingState {
  final String taskId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  
  const LoadingState({
    required this.taskId,
    required this.timestamp,
    this.metadata = const {},
  });
}

/// 加载状态层次结构
class LoadingIdle extends LoadingState {
  const LoadingIdle({required String taskId}) 
    : super(taskId: taskId, timestamp: DateTime.now());
}

class LoadingInProgress extends LoadingState {
  final String message;
  final double? progress; // 0.0 - 1.0
  final LoadingPriority priority;
  final List<String> dependencies;
  
  const LoadingInProgress({
    required String taskId,
    required this.message,
    this.progress,
    this.priority = LoadingPriority.normal,
    this.dependencies = const [],
  }) : super(taskId: taskId, timestamp: DateTime.now());
}

class LoadingSuccess extends LoadingState {
  final dynamic data;
  final Duration duration;
  
  const LoadingSuccess({
    required String taskId,
    required this.data,
    required this.duration,
  }) : super(taskId: taskId, timestamp: DateTime.now());
}

class LoadingError extends LoadingState {
  final String error;
  final String? errorCode;
  final StackTrace? stackTrace;
  final bool isRetryable;
  final int retryCount;
  
  const LoadingError({
    required String taskId,
    required this.error,
    this.errorCode,
    this.stackTrace,
    this.isRetryable = true,
    this.retryCount = 0,
  }) : super(taskId: taskId, timestamp: DateTime.now());
}

/// 加载优先级枚举
enum LoadingPriority {
  critical,  // 关键数据，阻塞UI
  high,      // 重要数据，优先加载
  normal,    // 普通数据，正常加载
  low,       // 次要数据，后台加载
  background // 背景数据，空闲时加载
}
```

#### B. LoadingTask 任务管理器
```dart
/// 加载任务定义
class LoadingTask {
  final String id;
  final String name;
  final LoadingPriority priority;
  final List<String> dependencies;
  final Future<dynamic> Function() executor;
  final Duration? timeout;
  final int maxRetries;
  final Duration retryDelay;
  
  const LoadingTask({
    required this.id,
    required this.name,
    required this.executor,
    this.priority = LoadingPriority.normal,
    this.dependencies = const [],
    this.timeout,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });
}

/// 加载任务管理器
class LoadingTaskManager {
  final Map<String, LoadingTask> _tasks = {};
  final Map<String, LoadingState> _taskStates = {};
  final Map<String, List<String>> _dependencyGraph = {};
  
  /// 注册加载任务
  void registerTask(LoadingTask task) {
    _tasks[task.id] = task;
    _taskStates[task.id] = LoadingIdle(taskId: task.id);
    _buildDependencyGraph(task);
  }
  
  /// 构建依赖图
  void _buildDependencyGraph(LoadingTask task) {
    _dependencyGraph[task.id] = task.dependencies;
  }
  
  /// 获取可执行的任务（依赖已满足）
  List<LoadingTask> getExecutableTasks() {
    return _tasks.values.where((task) {
      final state = _taskStates[task.id];
      if (state is! LoadingIdle) return false;
      
      // 检查依赖是否都已完成
      return task.dependencies.every((depId) {
        final depState = _taskStates[depId];
        return depState is LoadingSuccess;
      });
    }).toList()
      ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
  }
  
  /// 更新任务状态
  void updateTaskState(String taskId, LoadingState state) {
    _taskStates[taskId] = state;
  }
  
  /// 获取任务状态
  LoadingState? getTaskState(String taskId) {
    return _taskStates[taskId];
  }
  
  /// 获取整体加载进度
  double getOverallProgress() {
    if (_tasks.isEmpty) return 1.0;
    
    double totalProgress = 0.0;
    int completedTasks = 0;
    
    for (final state in _taskStates.values) {
      if (state is LoadingSuccess) {
        totalProgress += 1.0;
        completedTasks++;
      } else if (state is LoadingInProgress && state.progress != null) {
        totalProgress += state.progress!;
      }
    }
    
    return totalProgress / _tasks.length;
  }
}
```

#### C. LoadingBloc 统一状态管理
```dart
/// 加载事件定义
abstract class LoadingEvent {}

class StartLoadingTask extends LoadingEvent {
  final String taskId;
  const StartLoadingTask(this.taskId);
}

class RegisterLoadingTasks extends LoadingEvent {
  final List<LoadingTask> tasks;
  const RegisterLoadingTasks(this.tasks);
}

class RetryFailedTask extends LoadingEvent {
  final String taskId;
  const RetryFailedTask(this.taskId);
}

class CancelLoadingTask extends LoadingEvent {
  final String taskId;
  const CancelLoadingTask(this.taskId);
}

/// 整体加载状态
class LoadingBlocState {
  final Map<String, LoadingState> taskStates;
  final double overallProgress;
  final bool isLoading;
  final List<String> activeTasks;
  final List<String> failedTasks;
  final String? currentMessage;
  
  const LoadingBlocState({
    this.taskStates = const {},
    this.overallProgress = 0.0,
    this.isLoading = false,
    this.activeTasks = const [],
    this.failedTasks = const [],
    this.currentMessage,
  });
  
  LoadingBlocState copyWith({
    Map<String, LoadingState>? taskStates,
    double? overallProgress,
    bool? isLoading,
    List<String>? activeTasks,
    List<String>? failedTasks,
    String? currentMessage,
  }) {
    return LoadingBlocState(
      taskStates: taskStates ?? this.taskStates,
      overallProgress: overallProgress ?? this.overallProgress,
      isLoading: isLoading ?? this.isLoading,
      activeTasks: activeTasks ?? this.activeTasks,
      failedTasks: failedTasks ?? this.failedTasks,
      currentMessage: currentMessage ?? this.currentMessage,
    );
  }
}

/// 统一加载状态管理BLoC
class LoadingBloc extends Bloc<LoadingEvent, LoadingBlocState> {
  final LoadingTaskManager _taskManager = LoadingTaskManager();
  final Map<String, Timer> _timeoutTimers = {};
  final Map<String, Completer> _taskCompleters = {};
  
  LoadingBloc() : super(const LoadingBlocState()) {
    on<RegisterLoadingTasks>(_onRegisterLoadingTasks);
    on<StartLoadingTask>(_onStartLoadingTask);
    on<RetryFailedTask>(_onRetryFailedTask);
    on<CancelLoadingTask>(_onCancelLoadingTask);
  }
  
  Future<void> _onRegisterLoadingTasks(
    RegisterLoadingTasks event,
    Emitter<LoadingBlocState> emit,
  ) async {
    // 注册所有任务
    for (final task in event.tasks) {
      _taskManager.registerTask(task);
    }
    
    // 更新状态
    emit(state.copyWith(
      taskStates: Map.from(_taskManager._taskStates),
      isLoading: false,
    ));
    
    // 开始执行可执行的任务
    _executeReadyTasks(emit);
  }
  
  void _executeReadyTasks(Emitter<LoadingBlocState> emit) async {
    final executableTasks = _taskManager.getExecutableTasks();
    
    for (final task in executableTasks) {
      add(StartLoadingTask(task.id));
    }
  }
  
  Future<void> _onStartLoadingTask(
    StartLoadingTask event,
    Emitter<LoadingBlocState> emit,
  ) async {
    final task = _taskManager._tasks[event.taskId];
    if (task == null) return;
    
    // 更新为加载中状态
    final loadingState = LoadingInProgress(
      taskId: task.id,
      message: '正在${task.name}...',
      priority: task.priority,
      dependencies: task.dependencies,
    );
    
    _taskManager.updateTaskState(task.id, loadingState);
    
    emit(state.copyWith(
      taskStates: Map.from(_taskManager._taskStates),
      isLoading: true,
      activeTasks: [...state.activeTasks, task.id],
      currentMessage: loadingState.message,
      overallProgress: _taskManager.getOverallProgress(),
    ));
    
    // 设置超时定时器
    if (task.timeout != null) {
      _timeoutTimers[task.id] = Timer(task.timeout!, () {
        _handleTaskTimeout(task.id, emit);
      });
    }
    
    try {
      // 执行任务
      final startTime = DateTime.now();
      final result = await task.executor();
      final duration = DateTime.now().difference(startTime);
      
      // 取消超时定时器
      _timeoutTimers[task.id]?.cancel();
      _timeoutTimers.remove(task.id);
      
      // 更新为成功状态
      final successState = LoadingSuccess(
        taskId: task.id,
        data: result,
        duration: duration,
      );
      
      _taskManager.updateTaskState(task.id, successState);
      
      emit(state.copyWith(
        taskStates: Map.from(_taskManager._taskStates),
        activeTasks: state.activeTasks.where((id) => id != task.id).toList(),
        overallProgress: _taskManager.getOverallProgress(),
        isLoading: _taskManager.getExecutableTasks().isNotEmpty,
      ));
      
      // 继续执行下一批可执行的任务
      _executeReadyTasks(emit);
      
    } catch (e, stackTrace) {
      // 处理任务失败
      _handleTaskError(task, e, stackTrace, emit);
    }
  }
  
  void _handleTaskError(
    LoadingTask task,
    dynamic error,
    StackTrace stackTrace,
    Emitter<LoadingBlocState> emit,
  ) {
    final errorState = LoadingError(
      taskId: task.id,
      error: error.toString(),
      stackTrace: stackTrace,
      isRetryable: true,
    );
    
    _taskManager.updateTaskState(task.id, errorState);
    
    emit(state.copyWith(
      taskStates: Map.from(_taskManager._taskStates),
      activeTasks: state.activeTasks.where((id) => id != task.id).toList(),
      failedTasks: [...state.failedTasks, task.id],
      overallProgress: _taskManager.getOverallProgress(),
    ));
  }
  
  void _handleTaskTimeout(String taskId, Emitter<LoadingBlocState> emit) {
    final task = _taskManager._tasks[taskId];
    if (task == null) return;
    
    final timeoutError = LoadingError(
      taskId: taskId,
      error: '任务执行超时',
      errorCode: 'TIMEOUT',
      isRetryable: true,
    );
    
    _taskManager.updateTaskState(taskId, timeoutError);
    
    emit(state.copyWith(
      taskStates: Map.from(_taskManager._taskStates),
      activeTasks: state.activeTasks.where((id) => id != taskId).toList(),
      failedTasks: [...state.failedTasks, taskId],
    ));
  }
}
```

## 🎯 预定义加载任务

### 应用启动加载任务
```dart
class AppLoadingTasks {
  static List<LoadingTask> getStartupTasks({
    required DatabaseHelper databaseHelper,
    required List<Repository> repositories,
    required List<Bloc> blocs,
  }) {
    return [
      // 第一层：关键基础设施
      LoadingTask(
        id: 'database_init',
        name: '初始化数据库',
        priority: LoadingPriority.critical,
        executor: () => databaseHelper.database,
        timeout: const Duration(seconds: 5),
      ),
      
      LoadingTask(
        id: 'storage_init',
        name: '初始化存储服务',
        priority: LoadingPriority.critical,
        executor: () => _initializeStorage(),
        timeout: const Duration(seconds: 3),
      ),
      
      // 第二层：核心数据加载
      LoadingTask(
        id: 'settings_load',
        name: '加载应用设置',
        priority: LoadingPriority.high,
        dependencies: ['storage_init'],
        executor: () => _loadSettings(),
        timeout: const Duration(seconds: 3),
      ),
      
      LoadingTask(
        id: 'auth_check',
        name: '检查登录状态',
        priority: LoadingPriority.high,
        dependencies: ['storage_init'],
        executor: () => _checkAuthStatus(),
        timeout: const Duration(seconds: 5),
      ),
      
      LoadingTask(
        id: 'goals_load',
        name: '加载目标数据',
        priority: LoadingPriority.high,
        dependencies: ['database_init'],
        executor: () => _loadGoalsData(),
        timeout: const Duration(seconds: 10),
      ),
      
      // 第三层：次要数据加载
      LoadingTask(
        id: 'profile_load',
        name: '加载用户资料',
        priority: LoadingPriority.normal,
        dependencies: ['auth_check'],
        executor: () => _loadUserProfile(),
        timeout: const Duration(seconds: 5),
      ),
      
      LoadingTask(
        id: 'explore_load',
        name: '加载探索卡片',
        priority: LoadingPriority.normal,
        dependencies: ['database_init'],
        executor: () => _loadExploreCards(),
        timeout: const Duration(seconds: 8),
      ),
      
      // 第四层：背景数据
      LoadingTask(
        id: 'sync_service_init',
        name: '初始化同步服务',
        priority: LoadingPriority.low,
        dependencies: ['goals_load', 'explore_load'],
        executor: () => _initializeSyncService(),
        timeout: const Duration(seconds: 5),
      ),
    ];
  }
}
```

## 🚀 使用示例

### 在main.dart中使用
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    MultiBlocProvider(
      providers: [
        // 统一加载状态管理
        BlocProvider<LoadingBloc>(
          create: (context) => LoadingBloc(),
        ),
        // 其他BLoC...
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoadingBloc, LoadingBlocState>(
      builder: (context, loadingState) {
        if (loadingState.isLoading) {
          return MaterialApp(
            home: LoadingScreen(loadingState: loadingState),
          );
        }
        
        return MaterialApp(
          // 正常应用界面
          home: HomePage(),
        );
      },
    );
  }
}
```

### 加载界面组件
```dart
class LoadingScreen extends StatelessWidget {
  final LoadingBlocState loadingState;
  
  const LoadingScreen({Key? key, required this.loadingState}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: loadingState.overallProgress,
            ),
            const SizedBox(height: 16),
            Text(
              loadingState.currentMessage ?? '正在加载...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${(loadingState.overallProgress * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (loadingState.failedTasks.isNotEmpty) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  for (final taskId in loadingState.failedTasks) {
                    context.read<LoadingBloc>().add(RetryFailedTask(taskId));
                  }
                },
                child: const Text('重试失败的任务'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

---

**设计完成时间**: 2024年12月  
**设计人员**: AI Assistant  
**实现预期**: 统一加载状态管理，提升用户体验
