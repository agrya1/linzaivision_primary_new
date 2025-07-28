import 'package:shared_preferences/shared_preferences.dart';

/// BLoC功能开关
/// 
/// 用于控制BLoC架构的渐进式启用，允许按功能点逐步迁移
class BlocFeatureToggles {
  // 单例实例
  static final BlocFeatureToggles _instance = BlocFeatureToggles._internal();
  
  // 工厂构造函数
  factory BlocFeatureToggles() => _instance;
  
  // 内部构造函数
  BlocFeatureToggles._internal();
  
  // 功能开关状态
  bool _titleEditing = false;
  bool _descriptionEditing = false;
  bool _statusChanging = false;
  bool _viewSwitching = false;
  bool _goalAdding = false;
  bool _goalDeleting = false;
  bool _imageUpdating = false;
  bool _dateUpdating = false;
  bool _countdownToggling = false;
  
  // Getters
  bool get titleEditing => _titleEditing;
  bool get descriptionEditing => _descriptionEditing;
  bool get statusChanging => _statusChanging;
  bool get viewSwitching => _viewSwitching;
  bool get goalAdding => _goalAdding;
  bool get goalDeleting => _goalDeleting;
  bool get imageUpdating => _imageUpdating;
  bool get dateUpdating => _dateUpdating;
  bool get countdownToggling => _countdownToggling;
  
  // 检查特定功能是否启用BLoC模式
  bool isFeatureEnabled(String featureName) {
    switch (featureName) {
      case 'titleEditing': return _titleEditing;
      case 'descriptionEditing': return _descriptionEditing;
      case 'statusChanging': return _statusChanging;
      case 'viewSwitching': return _viewSwitching;
      case 'goalAdding': return _goalAdding;
      case 'goalDeleting': return _goalDeleting;
      case 'imageUpdating': return _imageUpdating;
      case 'dateUpdating': return _dateUpdating;
      case 'countdownToggling': return _countdownToggling;
      default: return false;
    }
  }
  
  // 设置特定功能的BLoC模式状态
  Future<void> setFeatureEnabled(String featureName, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    
    switch (featureName) {
      case 'titleEditing':
        _titleEditing = enabled;
        await prefs.setBool('bloc_feature_titleEditing', enabled);
        break;
      case 'descriptionEditing':
        _descriptionEditing = enabled;
        await prefs.setBool('bloc_feature_descriptionEditing', enabled);
        break;
      case 'statusChanging':
        _statusChanging = enabled;
        await prefs.setBool('bloc_feature_statusChanging', enabled);
        break;
      case 'viewSwitching':
        _viewSwitching = enabled;
        await prefs.setBool('bloc_feature_viewSwitching', enabled);
        break;
      case 'goalAdding':
        _goalAdding = enabled;
        await prefs.setBool('bloc_feature_goalAdding', enabled);
        break;
      case 'goalDeleting':
        _goalDeleting = enabled;
        await prefs.setBool('bloc_feature_goalDeleting', enabled);
        break;
      case 'imageUpdating':
        _imageUpdating = enabled;
        await prefs.setBool('bloc_feature_imageUpdating', enabled);
        break;
      case 'dateUpdating':
        _dateUpdating = enabled;
        await prefs.setBool('bloc_feature_dateUpdating', enabled);
        break;
      case 'countdownToggling':
        _countdownToggling = enabled;
        await prefs.setBool('bloc_feature_countdownToggling', enabled);
        break;
    }
  }
  
  // 启用所有功能
  Future<void> enableAllFeatures() async {
    await setFeatureEnabled('titleEditing', true);
    await setFeatureEnabled('descriptionEditing', true);
    await setFeatureEnabled('statusChanging', true);
    await setFeatureEnabled('viewSwitching', true);
    await setFeatureEnabled('goalAdding', true);
    await setFeatureEnabled('goalDeleting', true);
    await setFeatureEnabled('imageUpdating', true);
    await setFeatureEnabled('dateUpdating', true);
    await setFeatureEnabled('countdownToggling', true);
  }
  
  // 禁用所有功能
  Future<void> disableAllFeatures() async {
    await setFeatureEnabled('titleEditing', false);
    await setFeatureEnabled('descriptionEditing', false);
    await setFeatureEnabled('statusChanging', false);
    await setFeatureEnabled('viewSwitching', false);
    await setFeatureEnabled('goalAdding', false);
    await setFeatureEnabled('goalDeleting', false);
    await setFeatureEnabled('imageUpdating', false);
    await setFeatureEnabled('dateUpdating', false);
    await setFeatureEnabled('countdownToggling', false);
  }
  
  // 加载保存的设置
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    _titleEditing = prefs.getBool('bloc_feature_titleEditing') ?? false;
    _descriptionEditing = prefs.getBool('bloc_feature_descriptionEditing') ?? false;
    _statusChanging = prefs.getBool('bloc_feature_statusChanging') ?? false;
    _viewSwitching = prefs.getBool('bloc_feature_viewSwitching') ?? false;
    _goalAdding = prefs.getBool('bloc_feature_goalAdding') ?? false;
    _goalDeleting = prefs.getBool('bloc_feature_goalDeleting') ?? false;
    _imageUpdating = prefs.getBool('bloc_feature_imageUpdating') ?? false;
    _dateUpdating = prefs.getBool('bloc_feature_dateUpdating') ?? false;
    _countdownToggling = prefs.getBool('bloc_feature_countdownToggling') ?? false;
  }
} 