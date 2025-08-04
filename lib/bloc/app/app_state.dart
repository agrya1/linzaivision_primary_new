import 'package:equatable/equatable.dart';

/// 应用加载状态枚举
enum AppLoadingState {
  initial,
  loading,
  success,
  error,
}

/// 应用生命周期状态枚举
enum AppLifecycleState {
  resumed,
  paused,
  inactive,
  detached,
}

/// 网络连接状态枚举
enum NetworkState {
  connected,
  disconnected,
  unknown,
}

/// 应用级状态基类
abstract class AppState extends Equatable {
  const AppState();

  @override
  List<Object?> get props => [];
}

/// 应用初始状态
class AppInitial extends AppState {
  const AppInitial();
}

/// 应用加载中状态
class AppLoading extends AppState {
  final String? message;
  
  const AppLoading({this.message});
  
  @override
  List<Object?> get props => [message];
}

/// 应用就绪状态
class AppReady extends AppState {
  final String version;
  final String buildNumber;
  final AppLifecycleState lifecycleState;
  final NetworkState networkState;
  final String themeMode;
  final String languageCode;
  final bool isDebugMode;
  final Map<String, dynamic> config;
  final DateTime lastSyncTime;
  final bool isGlobalLoading;
  final String? globalLoadingMessage;
  final String? globalError;
  final String? globalErrorCode;
  
  const AppReady({
    required this.version,
    required this.buildNumber,
    this.lifecycleState = AppLifecycleState.resumed,
    this.networkState = NetworkState.unknown,
    this.themeMode = 'system',
    this.languageCode = 'zh',
    this.isDebugMode = false,
    this.config = const {},
    required this.lastSyncTime,
    this.isGlobalLoading = false,
    this.globalLoadingMessage,
    this.globalError,
    this.globalErrorCode,
  });
  
  @override
  List<Object?> get props => [
    version,
    buildNumber,
    lifecycleState,
    networkState,
    themeMode,
    languageCode,
    isDebugMode,
    config,
    lastSyncTime,
    isGlobalLoading,
    globalLoadingMessage,
    globalError,
    globalErrorCode,
  ];
  
  /// 复制状态并更新指定字段
  AppReady copyWith({
    String? version,
    String? buildNumber,
    AppLifecycleState? lifecycleState,
    NetworkState? networkState,
    String? themeMode,
    String? languageCode,
    bool? isDebugMode,
    Map<String, dynamic>? config,
    DateTime? lastSyncTime,
    bool? isGlobalLoading,
    String? globalLoadingMessage,
    String? globalError,
    String? globalErrorCode,
    bool clearGlobalError = false,
    bool clearGlobalLoadingMessage = false,
  }) {
    return AppReady(
      version: version ?? this.version,
      buildNumber: buildNumber ?? this.buildNumber,
      lifecycleState: lifecycleState ?? this.lifecycleState,
      networkState: networkState ?? this.networkState,
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
      isDebugMode: isDebugMode ?? this.isDebugMode,
      config: config ?? this.config,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      isGlobalLoading: isGlobalLoading ?? this.isGlobalLoading,
      globalLoadingMessage: clearGlobalLoadingMessage 
          ? null 
          : (globalLoadingMessage ?? this.globalLoadingMessage),
      globalError: clearGlobalError 
          ? null 
          : (globalError ?? this.globalError),
      globalErrorCode: clearGlobalError 
          ? null 
          : (globalErrorCode ?? this.globalErrorCode),
    );
  }
  
  /// 是否有全局错误
  bool get hasGlobalError => globalError != null;
  
  /// 是否网络已连接
  bool get isNetworkConnected => networkState == NetworkState.connected;
  
  /// 是否应用处于活跃状态
  bool get isAppActive => lifecycleState == AppLifecycleState.resumed;
  
  /// 是否需要同步数据（超过5分钟未同步）
  bool get needsDataSync {
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime);
    return difference.inMinutes > 5;
  }
  
  /// 获取主题模式枚举
  ThemeMode get themeModeEnum {
    switch (themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}

/// 应用错误状态
class AppError extends AppState {
  final String message;
  final String? code;
  final dynamic error;
  
  const AppError(this.message, {this.code, this.error});
  
  @override
  List<Object?> get props => [message, code, error];
}

/// 应用同步中状态
class AppSyncing extends AppState {
  final String? syncMessage;
  final double? progress; // 0.0 - 1.0
  
  const AppSyncing({this.syncMessage, this.progress});
  
  @override
  List<Object?> get props => [syncMessage, progress];
}

/// 应用更新可用状态
class AppUpdateAvailable extends AppState {
  final String newVersion;
  final String currentVersion;
  final String? updateDescription;
  final bool isForceUpdate;
  
  const AppUpdateAvailable({
    required this.newVersion,
    required this.currentVersion,
    this.updateDescription,
    this.isForceUpdate = false,
  });
  
  @override
  List<Object?> get props => [newVersion, currentVersion, updateDescription, isForceUpdate];
}

/// 应用维护模式状态
class AppMaintenance extends AppState {
  final String message;
  final DateTime? estimatedEndTime;
  
  const AppMaintenance(this.message, {this.estimatedEndTime});
  
  @override
  List<Object?> get props => [message, estimatedEndTime];
}

/// ThemeMode 枚举（如果不存在的话）
enum ThemeMode {
  system,
  light,
  dark,
}
