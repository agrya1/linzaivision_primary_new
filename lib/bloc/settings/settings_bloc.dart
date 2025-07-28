import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repository/settings_repository.dart';
import 'settings_event.dart';
import 'settings_state.dart';

// 导出事件和状态，方便其他文件引用
export 'settings_event.dart';
export 'settings_state.dart';

/// 设置管理Bloc
/// 
/// 负责处理应用设置相关的事件和状态
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final SettingsRepository repository;
  
  SettingsBloc({required this.repository}) : super(SettingsInitial()) {
    on<LoadSettings>(_onLoadSettings);
    on<ChangeThemeMode>(_onChangeThemeMode);
    on<ChangeLanguage>(_onChangeLanguage);
    on<ChangeHomePage>(_onChangeHomePage);
    on<ToggleFollowSystemTheme>(_onToggleFollowSystemTheme);
    on<ToggleBlocMode>(_onToggleBlocMode);
    on<TogglePerformanceMonitoring>(_onTogglePerformanceMonitoring);
    on<ToggleErrorLogging>(_onToggleErrorLogging);
    on<ResetAllSettings>(_onResetAllSettings);
  }
  
  /// 处理加载设置事件
  Future<void> _onLoadSettings(LoadSettings event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      final themeMode = await repository.getThemeMode();
      final language = await repository.getLanguage();
      final homePage = await repository.getHomePage();
      final followSystemTheme = await repository.getFollowSystemTheme();
      final useBlocMode = await repository.getUseBlocMode();
      final enablePerformanceMonitoring = await repository.getEnablePerformanceMonitoring();
      final enableErrorLogging = await repository.getEnableErrorLogging();
      
      emit(SettingsLoaded(
        themeMode: themeMode,
        language: language,
        homePage: homePage,
        followSystemTheme: followSystemTheme,
        useBlocMode: useBlocMode,
        enablePerformanceMonitoring: enablePerformanceMonitoring,
        enableErrorLogging: enableErrorLogging,
      ));
    } catch (e) {
      emit(SettingsError('加载设置失败: $e'));
    }
  }
  
  /// 处理更改主题模式事件
  Future<void> _onChangeThemeMode(ChangeThemeMode event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setThemeMode(event.themeMode);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(themeMode: event.themeMode));
      } catch (e) {
        emit(SettingsError('更改主题模式失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理更改语言事件
  Future<void> _onChangeLanguage(ChangeLanguage event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setLanguage(event.language);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(language: event.language));
      } catch (e) {
        emit(SettingsError('更改语言失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理更改首页设置事件
  Future<void> _onChangeHomePage(ChangeHomePage event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setHomePage(event.homePage);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(homePage: event.homePage));
      } catch (e) {
        emit(SettingsError('更改首页设置失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理切换跟随系统主题事件
  Future<void> _onToggleFollowSystemTheme(ToggleFollowSystemTheme event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setFollowSystemTheme(event.followSystemTheme);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(followSystemTheme: event.followSystemTheme));
      } catch (e) {
        emit(SettingsError('更改跟随系统主题设置失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理切换BLoC模式事件
  Future<void> _onToggleBlocMode(ToggleBlocMode event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setUseBlocMode(event.useBlocMode);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(useBlocMode: event.useBlocMode));
      } catch (e) {
        emit(SettingsError('更改BLoC模式设置失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理切换性能监控事件
  Future<void> _onTogglePerformanceMonitoring(TogglePerformanceMonitoring event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setEnablePerformanceMonitoring(event.enablePerformanceMonitoring);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(enablePerformanceMonitoring: event.enablePerformanceMonitoring));
      } catch (e) {
        emit(SettingsError('更改性能监控设置失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理切换错误日志事件
  Future<void> _onToggleErrorLogging(ToggleErrorLogging event, Emitter<SettingsState> emit) async {
    if (state is SettingsLoaded) {
      try {
        await repository.setEnableErrorLogging(event.enableErrorLogging);
        final currentState = state as SettingsLoaded;
        emit(currentState.copyWith(enableErrorLogging: event.enableErrorLogging));
      } catch (e) {
        emit(SettingsError('更改错误日志设置失败: $e'));
        emit(state); // 恢复到之前的状态
      }
    }
  }
  
  /// 处理重置所有设置事件
  Future<void> _onResetAllSettings(ResetAllSettings event, Emitter<SettingsState> emit) async {
    emit(SettingsLoading());
    try {
      await repository.clearAllSettings();
      // 重新加载默认设置
      add(LoadSettings());
    } catch (e) {
      emit(SettingsError('重置设置失败: $e'));
      emit(state); // 恢复到之前的状态
    }
  }
} 