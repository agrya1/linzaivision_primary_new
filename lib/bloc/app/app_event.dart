import 'package:equatable/equatable.dart';

/// 应用级事件基类
abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

/// 应用初始化事件
class InitializeApp extends AppEvent {
  const InitializeApp();
}

/// 应用恢复事件（从后台返回）
class AppResumed extends AppEvent {
  const AppResumed();
}

/// 应用暂停事件（进入后台）
class AppPaused extends AppEvent {
  const AppPaused();
}

/// 应用终止事件
class AppTerminated extends AppEvent {
  const AppTerminated();
}

/// 全局数据同步事件
class SyncAllData extends AppEvent {
  const SyncAllData();
}

/// 同步目标数据事件
class SyncGoals extends AppEvent {
  const SyncGoals();
}

/// 同步用户资料事件
class SyncUserProfile extends AppEvent {
  const SyncUserProfile();
}

/// 同步设置事件
class SyncSettings extends AppEvent {
  const SyncSettings();
}

/// 网络状态变化事件
class NetworkStatusChanged extends AppEvent {
  final bool isConnected;
  
  const NetworkStatusChanged(this.isConnected);
  
  @override
  List<Object?> get props => [isConnected];
}

/// 主题模式变化事件
class ThemeModeChanged extends AppEvent {
  final String themeMode; // 'light', 'dark', 'system'
  
  const ThemeModeChanged(this.themeMode);
  
  @override
  List<Object?> get props => [themeMode];
}

/// 语言变化事件
class LanguageChanged extends AppEvent {
  final String languageCode;
  
  const LanguageChanged(this.languageCode);
  
  @override
  List<Object?> get props => [languageCode];
}

/// 全局错误事件
class GlobalError extends AppEvent {
  final String message;
  final String? code;
  final dynamic error;
  
  const GlobalError(this.message, {this.code, this.error});
  
  @override
  List<Object?> get props => [message, code, error];
}

/// 清除全局错误事件
class ClearGlobalError extends AppEvent {
  const ClearGlobalError();
}

/// 显示全局加载指示器事件
class ShowGlobalLoading extends AppEvent {
  final String? message;
  
  const ShowGlobalLoading({this.message});
  
  @override
  List<Object?> get props => [message];
}

/// 隐藏全局加载指示器事件
class HideGlobalLoading extends AppEvent {
  const HideGlobalLoading();
}

/// 更新应用版本信息事件
class UpdateAppVersion extends AppEvent {
  final String version;
  final String buildNumber;
  
  const UpdateAppVersion(this.version, this.buildNumber);
  
  @override
  List<Object?> get props => [version, buildNumber];
}

/// 检查应用更新事件
class CheckAppUpdate extends AppEvent {
  const CheckAppUpdate();
}

/// 强制刷新应用数据事件
class ForceRefreshAppData extends AppEvent {
  const ForceRefreshAppData();
}

/// 清理应用缓存事件
class ClearAppCache extends AppEvent {
  const ClearAppCache();
}

/// 导出应用数据事件
class ExportAppData extends AppEvent {
  const ExportAppData();
}

/// 导入应用数据事件
class ImportAppData extends AppEvent {
  final String dataPath;
  
  const ImportAppData(this.dataPath);
  
  @override
  List<Object?> get props => [dataPath];
}

/// 重置应用状态事件
class ResetAppState extends AppEvent {
  const ResetAppState();
}

/// 启用调试模式事件
class EnableDebugMode extends AppEvent {
  const EnableDebugMode();
}

/// 禁用调试模式事件
class DisableDebugMode extends AppEvent {
  const DisableDebugMode();
}

/// 更新应用配置事件
class UpdateAppConfig extends AppEvent {
  final Map<String, dynamic> config;
  
  const UpdateAppConfig(this.config);
  
  @override
  List<Object?> get props => [config];
}
