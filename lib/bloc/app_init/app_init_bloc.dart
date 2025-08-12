import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_init_event.dart';
import 'app_init_state.dart';
import '../loading/loading_bloc.dart';
import '../loading/loading_state.dart';
import '../loading/loading_event.dart';
import '../loading/loading_task.dart';
import '../loading/app_loading_tasks.dart';
import '../../database/database_helper.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../repository/goal_repository.dart';
import '../../repository/explore_repository.dart';
import '../../repository/settings_repository.dart';
import '../../repository/profile_repository.dart';
import '../../repository/auth_repository.dart';

/// 应用初始化BLoC
/// 管理应用启动和初始化的完整流程
class AppInitBloc extends Bloc<AppInitEvent, AppInitState> {
  final LoadingBloc _loadingBloc;
  final DatabaseHelper _databaseHelper;
  final StorageService _storageService;
  final AuthService _authService;
  final GoalRepository _goalRepository;
  final ExploreRepository _exploreRepository;
  final SettingsRepository _settingsRepository;
  final ProfileRepository _profileRepository;
  final AuthRepository _authRepository;

  // 内部状态管理
  late StreamSubscription _loadingSubscription;
  final Map<String, DateTime> _taskStartTimes = {};
  final Map<String, Duration> _taskDurations = {};
  final List<String> _completedTasks = [];
  final List<String> _failedTasks = [];
  DateTime? _initStartTime;
  Timer? _timeoutTimer;

  // 配置参数
  Map<String, dynamic> _initConfig = {};
  Duration _globalTimeout = const Duration(minutes: 2);
  final Map<AppInitPhase, Duration> _phaseTimeouts = {
    AppInitPhase.infrastructure: const Duration(seconds: 30),
    AppInitPhase.coreData: const Duration(seconds: 45),
    AppInitPhase.userData: const Duration(seconds: 30),
    AppInitPhase.services: const Duration(seconds: 15),
  };

  AppInitBloc({
    required LoadingBloc loadingBloc,
    required DatabaseHelper databaseHelper,
    required StorageService storageService,
    required AuthService authService,
    required GoalRepository goalRepository,
    required ExploreRepository exploreRepository,
    required SettingsRepository settingsRepository,
    required ProfileRepository profileRepository,
    required AuthRepository authRepository,
  })  : _loadingBloc = loadingBloc,
        _databaseHelper = databaseHelper,
        _storageService = storageService,
        _authService = authService,
        _goalRepository = goalRepository,
        _exploreRepository = exploreRepository,
        _settingsRepository = settingsRepository,
        _profileRepository = profileRepository,
        _authRepository = authRepository,
        super(const AppInitInitial()) {
    // 注册事件处理器
    on<StartAppInitialization>(_onStartInitialization);
    on<PhaseStarted>(_onPhaseStarted);
    on<TaskCompleted>(_onTaskCompleted);
    on<TaskFailed>(_onTaskFailed);
    on<ProgressUpdated>(_onProgressUpdated);
    on<PhaseCompleted>(_onPhaseCompleted);
    on<InitializationCompleted>(_onInitializationCompleted);
    on<InitializationFailed>(_onInitializationFailed);
    on<RetryInitialization>(_onRetryInitialization);
    on<SkipCurrentTask>(_onSkipCurrentTask);
    on<CancelInitialization>(_onCancelInitialization);
    on<PauseInitialization>(_onPauseInitialization);
    on<ResumeInitialization>(_onResumeInitialization);
    on<UpdateInitConfig>(_onUpdateInitConfig);
    on<RequestInitStatus>(_onRequestInitStatus);
    on<CleanupInitData>(_onCleanupInitData);
    on<SetInitTimeout>(_onSetInitTimeout);
    on<InitializationTimeout>(_onInitializationTimeout);

    // 监听LoadingBloc状态变化
    _setupLoadingSubscription();
  }

  /// 设置LoadingBloc监听
  void _setupLoadingSubscription() {
    _loadingSubscription = _loadingBloc.stream.listen((loadingState) {
      _handleLoadingStateChange(loadingState);
    });
  }

  /// 处理LoadingBloc状态变化
  void _handleLoadingStateChange(LoadingBlocState loadingState) {
    if (kDebugMode) {
      print('【AppInitBloc】LoadingBloc状态变化: ${loadingState.runtimeType}');
    }

    // 根据LoadingBloc状态更新AppInit状态
    if (loadingState.isLoading) {
      final progress = loadingState.overallProgress;
      final currentTask = loadingState.currentMessage ?? '正在初始化...';

      add(ProgressUpdated(
        progress: progress,
        message: currentTask,
        currentPhase: _getCurrentPhaseFromProgress(progress),
        progressData: {
          'activeTasks': loadingState.activeTasks.length,
          'completedTasks': loadingState.completedTasks.length,
          'failedTasks': loadingState.failedTasks.length,
        },
      ));
    } else if (loadingState.failedTasks.isNotEmpty) {
      final error = '任务执行失败';
      add(InitializationFailed(
        error: error,
        failedPhase: _getCurrentPhaseFromProgress(loadingState.overallProgress),
        failedTask: loadingState.failedTasks.first,
        isRetryable: true,
        completedTasks: _completedTasks,
      ));
    } else if (!loadingState.isLoading &&
        loadingState.completedTasks.isNotEmpty) {
      // 检查是否所有任务都完成了
      final allTasksCompleted =
          loadingState.activeTasks.isEmpty && loadingState.failedTasks.isEmpty;

      if (allTasksCompleted) {
        add(InitializationCompleted(
          initializationData:
              _extractResultsFromTaskStates(loadingState.taskStates),
          totalDuration: _initStartTime != null
              ? DateTime.now().difference(_initStartTime!)
              : Duration.zero,
          completedTasks: _completedTasks,
          taskDurations: _taskDurations,
          statistics: _generateStatistics(),
        ));
      }
    }
  }

  /// 根据进度确定当前阶段
  AppInitPhase _getCurrentPhaseFromProgress(double progress) {
    if (progress < 0.2) return AppInitPhase.infrastructure;
    if (progress < 0.6) return AppInitPhase.coreData;
    if (progress < 0.9) return AppInitPhase.userData;
    if (progress < 1.0) return AppInitPhase.services;
    return AppInitPhase.completed;
  }

  /// 开始应用初始化
  Future<void> _onStartInitialization(
    StartAppInitialization event,
    Emitter<AppInitState> emit,
  ) async {
    if (kDebugMode) {
      print('【AppInitBloc】开始应用初始化');
    }

    try {
      // 重置状态
      _resetInitializationState();
      _initConfig = Map.from(event.initConfig);
      _initStartTime = DateTime.now();

      // 设置全局超时
      _setupGlobalTimeout();

      // 发出初始化开始状态
      emit(AppInitInProgress.now(
        currentPhase: AppInitPhase.infrastructure,
        currentMessage: '准备初始化应用...',
        overallProgress: 0.0,
      ));

      // 创建初始化任务
      final tasks = _createInitializationTasks(event.skipTasks);

      // 注册任务到LoadingBloc
      _loadingBloc.add(RegisterLoadingTasks(tasks));

      // 开始执行任务
      _loadingBloc.add(StartLoadingTasks(tasks.map((t) => t.id).toList()));
    } catch (error, stackTrace) {
      if (kDebugMode) {
        print('【AppInitBloc】初始化启动失败: $error');
      }

      emit(AppInitFailure(
        error: error.toString(),
        failedPhase: AppInitPhase.infrastructure,
        failedTask: 'initialization_start',
        debugInfo: {'stackTrace': stackTrace.toString()},
        isRetryable: true,
        completedTasks: _completedTasks,
        elapsedTime: _initStartTime != null
            ? DateTime.now().difference(_initStartTime!)
            : Duration.zero,
      ));
    }
  }

  /// 创建初始化任务列表
  List<LoadingTask> _createInitializationTasks(List<String> skipTasks) {
    final tasks = AppLoadingTasks.getStartupTasks(
      databaseHelper: _databaseHelper,
      storageService: _storageService,
      authService: _authService,
      goalRepository: _goalRepository,
      exploreRepository: _exploreRepository,
      settingsRepository: _settingsRepository,
      profileRepository: _profileRepository,
      authRepository: _authRepository,
    );

    // 过滤掉需要跳过的任务
    return tasks.where((task) => !skipTasks.contains(task.id)).toList();
  }

  /// 重置初始化状态
  void _resetInitializationState() {
    _taskStartTimes.clear();
    _taskDurations.clear();
    _completedTasks.clear();
    _failedTasks.clear();
    _initStartTime = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// 设置全局超时
  void _setupGlobalTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_globalTimeout, () {
      add(InitializationTimeout(
        timeoutPhase: _getCurrentPhaseFromProgress(0.5), // 假设超时时在中间阶段
        currentTask: '全局超时',
        elapsedTime: _initStartTime != null
            ? DateTime.now().difference(_initStartTime!)
            : Duration.zero,
        timeoutDuration: _globalTimeout,
      ));
    });
  }

  /// 从任务状态中提取结果数据
  Map<String, dynamic> _extractResultsFromTaskStates(
      Map<String, LoadingState> taskStates) {
    final results = <String, dynamic>{};

    for (final entry in taskStates.entries) {
      final taskId = entry.key;
      final state = entry.value;

      if (state is LoadingSuccess) {
        results[taskId] = state.data;
      }
    }

    return results;
  }

  /// 生成统计信息
  Map<String, dynamic> _generateStatistics() {
    final totalDuration = _initStartTime != null
        ? DateTime.now().difference(_initStartTime!)
        : Duration.zero;

    return {
      'totalTasks': _completedTasks.length + _failedTasks.length,
      'completedTasks': _completedTasks.length,
      'failedTasks': _failedTasks.length,
      'totalDuration': totalDuration.inMilliseconds,
      'averageTaskDuration': _taskDurations.isNotEmpty
          ? _taskDurations.values
                  .map((d) => d.inMilliseconds)
                  .reduce((a, b) => a + b) /
              _taskDurations.length
          : 0,
      'successRate': _completedTasks.isNotEmpty
          ? _completedTasks.length /
              (_completedTasks.length + _failedTasks.length)
          : 0.0,
    };
  }

  // 其他事件处理器的简化实现
  Future<void> _onPhaseStarted(
      PhaseStarted event, Emitter<AppInitState> emit) async {
    // 实现阶段开始逻辑
  }

  Future<void> _onTaskCompleted(
      TaskCompleted event, Emitter<AppInitState> emit) async {
    _completedTasks.add(event.taskId);
    _taskDurations[event.taskId] = event.taskDuration;
  }

  Future<void> _onTaskFailed(
      TaskFailed event, Emitter<AppInitState> emit) async {
    _failedTasks.add(event.taskId);
  }

  Future<void> _onProgressUpdated(
      ProgressUpdated event, Emitter<AppInitState> emit) async {
    if (state is AppInitInProgress) {
      final currentState = state as AppInitInProgress;
      emit(currentState.copyWith(
        currentPhase: event.currentPhase,
        currentMessage: event.message,
        overallProgress: event.progress,
        phaseData: event.progressData,
      ));
    }
  }

  Future<void> _onPhaseCompleted(
      PhaseCompleted event, Emitter<AppInitState> emit) async {
    // 实现阶段完成逻辑
  }

  Future<void> _onInitializationCompleted(
      InitializationCompleted event, Emitter<AppInitState> emit) async {
    _timeoutTimer?.cancel();
    emit(AppInitSuccess(
      initializationData: event.initializationData,
      totalDuration: event.totalDuration,
      completedTasks: event.completedTasks,
      taskDurations: event.taskDurations,
    ));
  }

  Future<void> _onInitializationFailed(
      InitializationFailed event, Emitter<AppInitState> emit) async {
    _timeoutTimer?.cancel();
    emit(AppInitFailure(
      error: event.error,
      errorCode: event.errorCode,
      failedPhase: event.failedPhase,
      failedTask: event.failedTask,
      debugInfo: event.debugInfo,
      isRetryable: event.isRetryable,
      completedTasks: event.completedTasks,
      elapsedTime: _initStartTime != null
          ? DateTime.now().difference(_initStartTime!)
          : Duration.zero,
    ));
  }

  // 重试初始化
  Future<void> _onRetryInitialization(
      RetryInitialization event, Emitter<AppInitState> emit) async {
    if (kDebugMode) {
      print('【AppInitBloc】重试初始化，从阶段: ${event.fromPhase}');
    }

    // 重新开始初始化
    add(StartAppInitialization(
      forceRestart: true,
      initConfig: event.retryConfig,
      skipTasks: event.skipFailedTasks,
    ));
  }

  // 跳过当前任务
  Future<void> _onSkipCurrentTask(
      SkipCurrentTask event, Emitter<AppInitState> emit) async {
    if (kDebugMode) {
      print('【AppInitBloc】跳过任务: ${event.taskId}, 原因: ${event.reason}');
    }

    // 通知LoadingBloc跳过任务
    _loadingBloc.add(CancelLoadingTask(event.taskId));

    if (event.continueWithPhase) {
      // 继续下一个任务
      // 这里可以添加继续逻辑
    }
  }

  // 取消初始化
  Future<void> _onCancelInitialization(
      CancelInitialization event, Emitter<AppInitState> emit) async {
    if (kDebugMode) {
      print('【AppInitBloc】取消初始化: ${event.reason}');
    }

    _timeoutTimer?.cancel();

    // 取消所有正在进行的任务
    _loadingBloc.add(const CancelAllTasks());

    emit(AppInitFailure(
      error: '初始化已取消: ${event.reason}',
      failedPhase: _getCurrentPhaseFromProgress(0.0),
      failedTask: 'cancelled',
      isRetryable: true,
      completedTasks: _completedTasks,
      elapsedTime: _initStartTime != null
          ? DateTime.now().difference(_initStartTime!)
          : Duration.zero,
    ));
  }

  // 设置超时
  Future<void> _onSetInitTimeout(
      SetInitTimeout event, Emitter<AppInitState> emit) async {
    if (event.forPhase != null) {
      _phaseTimeouts[event.forPhase!] = event.timeout;
    } else {
      _globalTimeout = event.timeout;
      _setupGlobalTimeout(); // 重新设置全局超时
    }
  }

  // 处理超时
  Future<void> _onInitializationTimeout(
      InitializationTimeout event, Emitter<AppInitState> emit) async {
    if (kDebugMode) {
      print('【AppInitBloc】初始化超时: ${event.timeoutPhase}');
    }

    emit(AppInitFailure(
      error: '初始化超时: ${event.currentTask}',
      errorCode: 'TIMEOUT',
      failedPhase: event.timeoutPhase,
      failedTask: event.currentTask,
      debugInfo: {
        'elapsedTime': event.elapsedTime.inMilliseconds,
        'timeoutDuration': event.timeoutDuration.inMilliseconds,
      },
      isRetryable: true,
      completedTasks: _completedTasks,
      elapsedTime: event.elapsedTime,
    ));
  }

  // 其他简化实现
  Future<void> _onPauseInitialization(
      PauseInitialization event, Emitter<AppInitState> emit) async {
    // 暂停逻辑实现
  }

  Future<void> _onResumeInitialization(
      ResumeInitialization event, Emitter<AppInitState> emit) async {
    // 恢复逻辑实现
  }

  Future<void> _onUpdateInitConfig(
      UpdateInitConfig event, Emitter<AppInitState> emit) async {
    _initConfig.addAll(event.configUpdates);
  }

  Future<void> _onRequestInitStatus(
      RequestInitStatus event, Emitter<AppInitState> emit) async {
    // 返回当前状态信息
  }

  Future<void> _onCleanupInitData(
      CleanupInitData event, Emitter<AppInitState> emit) async {
    if (!event.keepStatistics) {
      _taskDurations.clear();
    }
    if (!event.keepErrorLogs) {
      _failedTasks.clear();
    }
  }

  @override
  Future<void> close() {
    _loadingSubscription.cancel();
    _timeoutTimer?.cancel();
    return super.close();
  }
}
