import 'package:equatable/equatable.dart';

/// 设置状态基类
abstract class SettingsState extends Equatable {
  const SettingsState();
  
  @override
  List<Object?> get props => [];
}

/// 初始状态
class SettingsInitial extends SettingsState {}

/// 加载中状态
class SettingsLoading extends SettingsState {}

/// 加载完成状态
class SettingsLoaded extends SettingsState {
  final String themeMode;
  final String language;
  final String homePage;
  final bool followSystemTheme;
  final bool useBlocMode;
  final bool enablePerformanceMonitoring;
  final bool enableErrorLogging;
  
  const SettingsLoaded({
    required this.themeMode,
    required this.language,
    required this.homePage,
    required this.followSystemTheme,
    required this.useBlocMode,
    required this.enablePerformanceMonitoring,
    required this.enableErrorLogging,
  });
  
  @override
  List<Object?> get props => [
    themeMode,
    language,
    homePage,
    followSystemTheme,
    useBlocMode,
    enablePerformanceMonitoring,
    enableErrorLogging,
  ];
  
  /// 创建新的状态对象，可以选择性地更新部分属性
  SettingsLoaded copyWith({
    String? themeMode,
    String? language,
    String? homePage,
    bool? followSystemTheme,
    bool? useBlocMode,
    bool? enablePerformanceMonitoring,
    bool? enableErrorLogging,
  }) {
    return SettingsLoaded(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      homePage: homePage ?? this.homePage,
      followSystemTheme: followSystemTheme ?? this.followSystemTheme,
      useBlocMode: useBlocMode ?? this.useBlocMode,
      enablePerformanceMonitoring: enablePerformanceMonitoring ?? this.enablePerformanceMonitoring,
      enableErrorLogging: enableErrorLogging ?? this.enableErrorLogging,
    );
  }
}

/// 错误状态
class SettingsError extends SettingsState {
  final String message;
  
  const SettingsError(this.message);
  
  @override
  List<Object?> get props => [message];
} 