import 'package:equatable/equatable.dart';

/// 设置事件基类
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  
  @override
  List<Object?> get props => [];
}

/// 加载设置事件
class LoadSettings extends SettingsEvent {}

/// 更改主题模式事件
class ChangeThemeMode extends SettingsEvent {
  final String themeMode; // 'light', 'dark'
  
  const ChangeThemeMode(this.themeMode);
  
  @override
  List<Object?> get props => [themeMode];
}

/// 更改语言事件
class ChangeLanguage extends SettingsEvent {
  final String language; // 'zh_CN', 'en_US', 'zh_TW'
  
  const ChangeLanguage(this.language);
  
  @override
  List<Object?> get props => [language];
}

/// 更改首页设置事件
class ChangeHomePage extends SettingsEvent {
  final String homePage; // 'explore', 'first_goal'
  
  const ChangeHomePage(this.homePage);
  
  @override
  List<Object?> get props => [homePage];
}

/// 切换跟随系统主题事件
class ToggleFollowSystemTheme extends SettingsEvent {
  final bool followSystemTheme;
  
  const ToggleFollowSystemTheme(this.followSystemTheme);
  
  @override
  List<Object?> get props => [followSystemTheme];
}

/// 切换BLoC模式事件
class ToggleBlocMode extends SettingsEvent {
  final bool useBlocMode;
  
  const ToggleBlocMode(this.useBlocMode);
  
  @override
  List<Object?> get props => [useBlocMode];
}

/// 切换性能监控事件
class TogglePerformanceMonitoring extends SettingsEvent {
  final bool enablePerformanceMonitoring;
  
  const TogglePerformanceMonitoring(this.enablePerformanceMonitoring);
  
  @override
  List<Object?> get props => [enablePerformanceMonitoring];
}

/// 切换错误日志事件
class ToggleErrorLogging extends SettingsEvent {
  final bool enableErrorLogging;
  
  const ToggleErrorLogging(this.enableErrorLogging);
  
  @override
  List<Object?> get props => [enableErrorLogging];
}

/// 重置所有设置事件
class ResetAllSettings extends SettingsEvent {} 