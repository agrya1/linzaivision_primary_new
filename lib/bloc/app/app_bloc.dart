import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'app_event.dart';
import 'app_state.dart';
import '../../repository/goal_repository.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

/// 应用级BLoC，管理全局应用状态
class AppBloc extends Bloc<AppEvent, AppState> {
  final GoalRepository? goalRepository;
  final AuthService? authService;
  final StorageService? storageService;

  // 内部状态管理
  Timer? _syncTimer;
  StreamSubscription? _authSubscription;

  AppBloc({
    this.goalRepository,
    this.authService,
    this.storageService,
  }) : super(const AppInitial()) {
    // 注册事件处理器
    on<InitializeApp>(_onInitializeApp);
    on<AppResumed>(_onAppResumed);
    on<AppPaused>(_onAppPaused);
    on<AppTerminated>(_onAppTerminated);
    on<SyncAllData>(_onSyncAllData);
    on<SyncGoals>(_onSyncGoals);
    on<SyncUserProfile>(_onSyncUserProfile);
    on<SyncSettings>(_onSyncSettings);
    on<NetworkStatusChanged>(_onNetworkStatusChanged);
    on<ThemeModeChanged>(_onThemeModeChanged);
    on<LanguageChanged>(_onLanguageChanged);
    on<GlobalError>(_onGlobalError);
    on<ClearGlobalError>(_onClearGlobalError);
    on<ShowGlobalLoading>(_onShowGlobalLoading);
    on<HideGlobalLoading>(_onHideGlobalLoading);
    on<UpdateAppVersion>(_onUpdateAppVersion);
    on<CheckAppUpdate>(_onCheckAppUpdate);
    on<ForceRefreshAppData>(_onForceRefreshAppData);
    on<ClearAppCache>(_onClearAppCache);
    on<ExportAppData>(_onExportAppData);
    on<ImportAppData>(_onImportAppData);
    on<ResetAppState>(_onResetAppState);
    on<EnableDebugMode>(_onEnableDebugMode);
    on<DisableDebugMode>(_onDisableDebugMode);
    on<UpdateAppConfig>(_onUpdateAppConfig);

    // 启动定期同步
    _startPeriodicSync();
  }

  @override
  Future<void> close() {
    _syncTimer?.cancel();
    _authSubscription?.cancel();
    return super.close();
  }

  /// 应用初始化处理
  Future<void> _onInitializeApp(
      InitializeApp event, Emitter<AppState> emit) async {
    try {
      emit(const AppLoading(message: '正在初始化应用...'));

      // 获取应用版本信息
      final packageInfo = await PackageInfo.fromPlatform();

      // 从存储中恢复设置
      final themeMode = await _getStoredThemeMode();
      final languageCode = await _getStoredLanguageCode();
      final isDebugMode = await _getStoredDebugMode();
      final config = await _getStoredConfig();

      // 发出应用就绪状态
      emit(AppReady(
        version: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        themeMode: themeMode,
        languageCode: languageCode,
        isDebugMode: isDebugMode,
        config: config,
        lastSyncTime: DateTime.now(),
      ));

      // 初始化完成后，触发数据同步
      add(const SyncAllData());

      if (kDebugMode) {
        print('【AppBloc】应用初始化完成 - 版本: ${packageInfo.version}');
      }
    } catch (e) {
      emit(AppError('应用初始化失败: $e'));
      if (kDebugMode) {
        print('【AppBloc】应用初始化失败: $e');
      }
    }
  }

  /// 应用恢复处理
  Future<void> _onAppResumed(AppResumed event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(lifecycleState: AppLifecycleState.resumed));

      // 应用恢复时检查是否需要同步数据
      if (currentState.needsDataSync) {
        add(const SyncAllData());
      }

      if (kDebugMode) {
        print('【AppBloc】应用已恢复');
      }
    }
  }

  /// 应用暂停处理
  Future<void> _onAppPaused(AppPaused event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(lifecycleState: AppLifecycleState.paused));

      if (kDebugMode) {
        print('【AppBloc】应用已暂停');
      }
    }
  }

  /// 应用终止处理
  Future<void> _onAppTerminated(
      AppTerminated event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(lifecycleState: AppLifecycleState.detached));

      // 保存当前状态到存储
      await _saveCurrentState(currentState);

      if (kDebugMode) {
        print('【AppBloc】应用即将终止，状态已保存');
      }
    }
  }

  /// 同步所有数据
  Future<void> _onSyncAllData(SyncAllData event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;

      try {
        emit(const AppSyncing(syncMessage: '正在同步数据...'));

        // 并行同步各种数据
        await Future.wait([
          _syncGoalsData(),
          _syncUserProfileData(),
          _syncSettingsData(),
        ]);

        emit(currentState.copyWith(lastSyncTime: DateTime.now()));

        if (kDebugMode) {
          print('【AppBloc】数据同步完成');
        }
      } catch (e) {
        emit(currentState.copyWith(
          globalError: '数据同步失败: $e',
          globalErrorCode: 'SYNC_ERROR',
        ));

        if (kDebugMode) {
          print('【AppBloc】数据同步失败: $e');
        }
      }
    }
  }

  /// 同步目标数据
  Future<void> _onSyncGoals(SyncGoals event, Emitter<AppState> emit) async {
    try {
      await _syncGoalsData();
      if (kDebugMode) {
        print('【AppBloc】目标数据同步完成');
      }
    } catch (e) {
      if (state is AppReady) {
        final currentState = state as AppReady;
        emit(currentState.copyWith(
          globalError: '目标数据同步失败: $e',
          globalErrorCode: 'GOALS_SYNC_ERROR',
        ));
      }
    }
  }

  /// 网络状态变化处理
  Future<void> _onNetworkStatusChanged(
      NetworkStatusChanged event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      final networkState = event.isConnected
          ? NetworkState.connected
          : NetworkState.disconnected;

      emit(currentState.copyWith(networkState: networkState));

      // 网络恢复时自动同步数据
      if (event.isConnected && currentState.needsDataSync) {
        add(const SyncAllData());
      }

      if (kDebugMode) {
        print('【AppBloc】网络状态变化: ${event.isConnected ? "已连接" : "已断开"}');
      }
    }
  }

  /// 主题模式变化处理
  Future<void> _onThemeModeChanged(
      ThemeModeChanged event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(themeMode: event.themeMode));

      // 保存主题设置
      await _saveThemeMode(event.themeMode);

      if (kDebugMode) {
        print('【AppBloc】主题模式已变更: ${event.themeMode}');
      }
    }
  }

  /// 全局错误处理
  Future<void> _onGlobalError(GlobalError event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(
        globalError: event.message,
        globalErrorCode: event.code,
      ));

      if (kDebugMode) {
        print('【AppBloc】全局错误: ${event.message} (${event.code})');
      }
    }
  }

  /// 清除全局错误
  Future<void> _onClearGlobalError(
      ClearGlobalError event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(clearGlobalError: true));
    }
  }

  /// 显示全局加载指示器
  Future<void> _onShowGlobalLoading(
      ShowGlobalLoading event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(
        isGlobalLoading: true,
        globalLoadingMessage: event.message,
      ));
    }
  }

  /// 隐藏全局加载指示器
  Future<void> _onHideGlobalLoading(
      HideGlobalLoading event, Emitter<AppState> emit) async {
    if (state is AppReady) {
      final currentState = state as AppReady;
      emit(currentState.copyWith(
        isGlobalLoading: false,
        clearGlobalLoadingMessage: true,
      ));
    }
  }

  // 私有辅助方法
  Future<String> _getStoredThemeMode() async {
    final result = await storageService?.getString('theme_mode');
    return result ?? 'system';
  }

  Future<String> _getStoredLanguageCode() async {
    final result = await storageService?.getString('language_code');
    return result ?? 'zh';
  }

  Future<bool> _getStoredDebugMode() async {
    final result = await storageService?.getBool('debug_mode');
    return result ?? kDebugMode;
  }

  Future<Map<String, dynamic>> _getStoredConfig() async {
    // 从存储中获取应用配置
    return {};
  }

  Future<void> _saveCurrentState(AppReady state) async {
    await storageService?.saveString('theme_mode', state.themeMode);
    await storageService?.saveString('language_code', state.languageCode);
    await storageService?.saveBool('debug_mode', state.isDebugMode);
  }

  Future<void> _saveThemeMode(String themeMode) async {
    await storageService?.saveString('theme_mode', themeMode);
  }

  Future<void> _syncGoalsData() async {
    // 实现目标数据同步逻辑
    if (goalRepository != null) {
      // 这里可以添加具体的同步逻辑
      await Future.delayed(const Duration(milliseconds: 500)); // 模拟同步
    }
  }

  Future<void> _syncUserProfileData() async {
    // 实现用户资料同步逻辑
    await Future.delayed(const Duration(milliseconds: 300)); // 模拟同步
  }

  Future<void> _syncSettingsData() async {
    // 实现设置同步逻辑
    await Future.delayed(const Duration(milliseconds: 200)); // 模拟同步
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      if (state is AppReady) {
        final currentState = state as AppReady;
        if (currentState.isNetworkConnected && currentState.isAppActive) {
          add(const SyncAllData());
        }
      }
    });
  }

  // 占位符方法，待实现
  Future<void> _onSyncUserProfile(
      SyncUserProfile event, Emitter<AppState> emit) async {}
  Future<void> _onSyncSettings(
      SyncSettings event, Emitter<AppState> emit) async {}
  Future<void> _onLanguageChanged(
      LanguageChanged event, Emitter<AppState> emit) async {}
  Future<void> _onUpdateAppVersion(
      UpdateAppVersion event, Emitter<AppState> emit) async {}
  Future<void> _onCheckAppUpdate(
      CheckAppUpdate event, Emitter<AppState> emit) async {}
  Future<void> _onForceRefreshAppData(
      ForceRefreshAppData event, Emitter<AppState> emit) async {}
  Future<void> _onClearAppCache(
      ClearAppCache event, Emitter<AppState> emit) async {}
  Future<void> _onExportAppData(
      ExportAppData event, Emitter<AppState> emit) async {}
  Future<void> _onImportAppData(
      ImportAppData event, Emitter<AppState> emit) async {}
  Future<void> _onResetAppState(
      ResetAppState event, Emitter<AppState> emit) async {}
  Future<void> _onEnableDebugMode(
      EnableDebugMode event, Emitter<AppState> emit) async {}
  Future<void> _onDisableDebugMode(
      DisableDebugMode event, Emitter<AppState> emit) async {}
  Future<void> _onUpdateAppConfig(
      UpdateAppConfig event, Emitter<AppState> emit) async {}
}
