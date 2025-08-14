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
  // AppBar 是否采用 BLoC 驱动渲染（阶段1小步开关，默认关闭）
  bool _appBarBlocDriven = false;
  // 显示选项菜单是否采用 BLoC 驱动渲染（阶段1小步开关，默认关闭）
  bool _displayOptionsBlocDriven = false;
  // 全屏视图是否采用 BLoC 驱动渲染（阶段1小步开关，默认关闭）
  bool _fullScreenBlocDriven = false;
  // 写路径是否通过BLoC直接执行（默认关闭，阶段0用于防止双写）
  bool _writeThroughBloc = false;
  // 标题显示切换是否通过BLoC写路径（批次1灰度开关，默认关闭）
  bool _titleDisplayWriteThrough = false;
  // 描述显示切换是否通过BLoC写路径（批次1灰度开关，默认关闭）
  bool _descriptionDisplayWriteThrough = false;
  // 时间显示切换是否通过BLoC写路径（批次1灰度开关，默认关闭）
  bool _timeDisplayWriteThrough = false;
  // 视图模式切换是否通过BLoC写路径（批次1灰度开关，默认关闭）
  bool _viewModeWriteThrough = false;

  // 批次2：编辑状态BLoC化开关
  // 目标选择状态是否通过BLoC写路径（批次2灰度开关，默认关闭）
  bool _currentGoalSelectionWriteThrough = false;
  // 标题编辑状态是否通过BLoC写路径（批次2灰度开关，默认关闭）
  bool _titleEditingWriteThrough = false;
  // 描述编辑状态是否通过BLoC写路径（批次2灰度开关，默认关闭）
  bool _descriptionEditingWriteThrough = false;

  // 批次3：写路径统一开关
  // 组件通信是否通过BLoC写路径（批次3阶段1开关，默认关闭）
  bool _componentCommWriteThrough = false;
  // 目标CRUD操作是否通过BLoC写路径（批次3阶段2开关，默认关闭）
  bool _goalCRUDWriteThrough = false;
  // 数据加载是否通过BLoC路径（批次3阶段3开关，默认关闭）
  bool _dataLoadingViaBloc = false;
  // UI状态管理是否通过BLoC路径（批次3阶段4开关，默认关闭）
  bool _uiStateWriteThrough = false;

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
  bool get appBarBlocDriven => _appBarBlocDriven;
  bool get displayOptionsBlocDriven => _displayOptionsBlocDriven;
  bool get fullScreenBlocDriven => _fullScreenBlocDriven;
  bool get writeThroughBloc => _writeThroughBloc;
  bool get titleDisplayWriteThrough => _titleDisplayWriteThrough;
  bool get descriptionDisplayWriteThrough => _descriptionDisplayWriteThrough;
  bool get timeDisplayWriteThrough => _timeDisplayWriteThrough;
  bool get viewModeWriteThrough => _viewModeWriteThrough;

  // 批次2：编辑状态BLoC化 getters
  bool get currentGoalSelectionWriteThrough => _currentGoalSelectionWriteThrough;
  bool get titleEditingWriteThrough => _titleEditingWriteThrough;
  bool get descriptionEditingWriteThrough => _descriptionEditingWriteThrough;

  // 批次3：写路径统一 getters
  bool get componentCommWriteThrough => _componentCommWriteThrough;
  bool get goalCRUDWriteThrough => _goalCRUDWriteThrough;
  bool get dataLoadingViaBloc => _dataLoadingViaBloc;
  bool get uiStateWriteThrough => _uiStateWriteThrough;

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
      case 'appBarBlocDriven': return _appBarBlocDriven;
      case 'displayOptionsBlocDriven': return _displayOptionsBlocDriven;
      case 'fullScreenBlocDriven': return _fullScreenBlocDriven;
      case 'writeThroughBloc': return _writeThroughBloc;
      case 'titleDisplayWriteThrough': return _titleDisplayWriteThrough;
      case 'descriptionDisplayWriteThrough': return _descriptionDisplayWriteThrough;
      case 'timeDisplayWriteThrough': return _timeDisplayWriteThrough;
      case 'viewModeWriteThrough': return _viewModeWriteThrough;
      // 批次2：编辑状态BLoC化
      case 'currentGoalSelectionWriteThrough': return _currentGoalSelectionWriteThrough;
      case 'titleEditingWriteThrough': return _titleEditingWriteThrough;
      case 'descriptionEditingWriteThrough': return _descriptionEditingWriteThrough;
      // 批次3：写路径统一
      case 'componentCommWriteThrough': return _componentCommWriteThrough;
      case 'goalCRUDWriteThrough': return _goalCRUDWriteThrough;
      case 'dataLoadingViaBloc': return _dataLoadingViaBloc;
      case 'uiStateWriteThrough': return _uiStateWriteThrough;
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
      case 'appBarBlocDriven':
        _appBarBlocDriven = enabled;
        await prefs.setBool('bloc_feature_appBarBlocDriven', enabled);
        break;
      case 'displayOptionsBlocDriven':
        _displayOptionsBlocDriven = enabled;
        await prefs.setBool('bloc_feature_displayOptionsBlocDriven', enabled);
        break;
      case 'fullScreenBlocDriven':
        _fullScreenBlocDriven = enabled;
        await prefs.setBool('bloc_feature_fullScreenBlocDriven', enabled);
        break;
      case 'writeThroughBloc':
        _writeThroughBloc = enabled;
        await prefs.setBool('bloc_feature_writeThroughBloc', enabled);
        break;
      case 'titleDisplayWriteThrough':
        _titleDisplayWriteThrough = enabled;
        await prefs.setBool('bloc_feature_titleDisplayWriteThrough', enabled);
        break;
      case 'descriptionDisplayWriteThrough':
        _descriptionDisplayWriteThrough = enabled;
        await prefs.setBool('bloc_feature_descriptionDisplayWriteThrough', enabled);
        break;
      case 'timeDisplayWriteThrough':
        _timeDisplayWriteThrough = enabled;
        await prefs.setBool('bloc_feature_timeDisplayWriteThrough', enabled);
        break;
      case 'viewModeWriteThrough':
        _viewModeWriteThrough = enabled;
        await prefs.setBool('bloc_feature_viewModeWriteThrough', enabled);
        break;
      // 批次2：编辑状态BLoC化
      case 'currentGoalSelectionWriteThrough':
        _currentGoalSelectionWriteThrough = enabled;
        await prefs.setBool('bloc_feature_currentGoalSelectionWriteThrough', enabled);
        break;
      case 'titleEditingWriteThrough':
        _titleEditingWriteThrough = enabled;
        await prefs.setBool('bloc_feature_titleEditingWriteThrough', enabled);
        break;
      case 'descriptionEditingWriteThrough':
        _descriptionEditingWriteThrough = enabled;
        await prefs.setBool('bloc_feature_descriptionEditingWriteThrough', enabled);
        break;
      // 批次3：写路径统一
      case 'componentCommWriteThrough':
        _componentCommWriteThrough = enabled;
        await prefs.setBool('bloc_feature_componentCommWriteThrough', enabled);
        break;
      case 'goalCRUDWriteThrough':
        _goalCRUDWriteThrough = enabled;
        await prefs.setBool('bloc_feature_goalCRUDWriteThrough', enabled);
        break;
      case 'dataLoadingViaBloc':
        _dataLoadingViaBloc = enabled;
        await prefs.setBool('bloc_feature_dataLoadingViaBloc', enabled);
        break;
      case 'uiStateWriteThrough':
        _uiStateWriteThrough = enabled;
        await prefs.setBool('bloc_feature_uiStateWriteThrough', enabled);
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
    _appBarBlocDriven = prefs.getBool('bloc_feature_appBarBlocDriven') ?? false;
    _displayOptionsBlocDriven = prefs.getBool('bloc_feature_displayOptionsBlocDriven') ?? false;
    _fullScreenBlocDriven = prefs.getBool('bloc_feature_fullScreenBlocDriven') ?? false;
    _writeThroughBloc = prefs.getBool('bloc_feature_writeThroughBloc') ?? false;
    _titleDisplayWriteThrough = prefs.getBool('bloc_feature_titleDisplayWriteThrough') ?? false;
    _descriptionDisplayWriteThrough = prefs.getBool('bloc_feature_descriptionDisplayWriteThrough') ?? false;
    _timeDisplayWriteThrough = prefs.getBool('bloc_feature_timeDisplayWriteThrough') ?? false;
    _viewModeWriteThrough = prefs.getBool('bloc_feature_viewModeWriteThrough') ?? false;

    // 批次2：编辑状态BLoC化
    _currentGoalSelectionWriteThrough = prefs.getBool('bloc_feature_currentGoalSelectionWriteThrough') ?? false;
    _titleEditingWriteThrough = prefs.getBool('bloc_feature_titleEditingWriteThrough') ?? false;
    _descriptionEditingWriteThrough = prefs.getBool('bloc_feature_descriptionEditingWriteThrough') ?? false;

    // 批次3：写路径统一
    _componentCommWriteThrough = prefs.getBool('bloc_feature_componentCommWriteThrough') ?? false;
    _goalCRUDWriteThrough = prefs.getBool('bloc_feature_goalCRUDWriteThrough') ?? false;
    _dataLoadingViaBloc = prefs.getBool('bloc_feature_dataLoadingViaBloc') ?? false;
    _uiStateWriteThrough = prefs.getBool('bloc_feature_uiStateWriteThrough') ?? false;
  }
}