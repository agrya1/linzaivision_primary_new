import 'package:flutter/material.dart';
import '../utils/bloc_feature_toggles.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 开发者设置页面
/// 
/// 用于控制BLoC功能开关和其他开发者选项
class DeveloperSettingsPage extends StatefulWidget {
  const DeveloperSettingsPage({Key? key}) : super(key: key);

  @override
  _DeveloperSettingsPageState createState() => _DeveloperSettingsPageState();
}

class _DeveloperSettingsPageState extends State<DeveloperSettingsPage> {
  // BLoC功能开关
  final BlocFeatureToggles _featureToggles = BlocFeatureToggles();
  
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
  
  // 全局BLoC执行模式
  bool _blocExecuteMode = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  // 加载设置
  Future<void> _loadSettings() async {
    await _featureToggles.loadSettings();
    
    setState(() {
      _titleEditing = _featureToggles.titleEditing;
      _descriptionEditing = _featureToggles.descriptionEditing;
      _statusChanging = _featureToggles.statusChanging;
      _viewSwitching = _featureToggles.viewSwitching;
      _goalAdding = _featureToggles.goalAdding;
      _goalDeleting = _featureToggles.goalDeleting;
      _imageUpdating = _featureToggles.imageUpdating;
      _dateUpdating = _featureToggles.dateUpdating;
      _countdownToggling = _featureToggles.countdownToggling;
      
      // 从SharedPreferences加载BLoC执行模式
      _loadBlocExecuteMode();
    });
  }
  
  // 加载BLoC执行模式
  Future<void> _loadBlocExecuteMode() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _blocExecuteMode = prefs.getBool('bloc_execute_mode') ?? false;
    });
  }
  
  // 保存BLoC执行模式
  Future<void> _saveBlocExecuteMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bloc_execute_mode', value);
    setState(() {
      _blocExecuteMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('开发者设置'),
        backgroundColor: Colors.grey[900],
      ),
      body: ListView(
        children: [
          // BLoC执行模式开关
          _buildSectionHeader('BLoC执行模式'),
          SwitchListTile(
            title: const Text('启用BLoC执行模式'),
            subtitle: const Text('开启后，BLoC将真正执行操作而不仅是记录日志'),
            value: _blocExecuteMode,
            onChanged: (value) async {
              await _saveBlocExecuteMode(value);
            },
          ),
          
          const Divider(),
          
          // BLoC功能开关
          _buildSectionHeader('BLoC功能开关'),
          _buildFeatureToggle(
            '标题编辑', 
            '使用BLoC处理标题编辑功能',
            _titleEditing, 
            (value) async {
              await _featureToggles.setFeatureEnabled('titleEditing', value);
              setState(() {
                _titleEditing = value;
              });
            }
          ),
          _buildFeatureToggle(
            '描述编辑', 
            '使用BLoC处理描述编辑功能',
            _descriptionEditing, 
            (value) async {
              await _featureToggles.setFeatureEnabled('descriptionEditing', value);
              setState(() {
                _descriptionEditing = value;
              });
            }
          ),
          _buildFeatureToggle(
            '状态切换', 
            '使用BLoC处理目标状态切换功能',
            _statusChanging, 
            (value) async {
              await _featureToggles.setFeatureEnabled('statusChanging', value);
              setState(() {
                _statusChanging = value;
              });
            }
          ),
          _buildFeatureToggle(
            '视图切换', 
            '使用BLoC处理视图模式切换功能',
            _viewSwitching, 
            (value) async {
              await _featureToggles.setFeatureEnabled('viewSwitching', value);
              setState(() {
                _viewSwitching = value;
              });
            }
          ),
          _buildFeatureToggle(
            '目标添加', 
            '使用BLoC处理目标添加功能',
            _goalAdding, 
            (value) async {
              await _featureToggles.setFeatureEnabled('goalAdding', value);
              setState(() {
                _goalAdding = value;
              });
            }
          ),
          _buildFeatureToggle(
            '目标删除', 
            '使用BLoC处理目标删除功能',
            _goalDeleting, 
            (value) async {
              await _featureToggles.setFeatureEnabled('goalDeleting', value);
              setState(() {
                _goalDeleting = value;
              });
            }
          ),
          _buildFeatureToggle(
            '图片更新', 
            '使用BLoC处理目标图片更新功能',
            _imageUpdating, 
            (value) async {
              await _featureToggles.setFeatureEnabled('imageUpdating', value);
              setState(() {
                _imageUpdating = value;
              });
            }
          ),
          _buildFeatureToggle(
            '日期更新', 
            '使用BLoC处理目标日期更新功能',
            _dateUpdating, 
            (value) async {
              await _featureToggles.setFeatureEnabled('dateUpdating', value);
              setState(() {
                _dateUpdating = value;
              });
            }
          ),
          _buildFeatureToggle(
            '倒计时切换', 
            '使用BLoC处理倒计时显示切换功能',
            _countdownToggling, 
            (value) async {
              await _featureToggles.setFeatureEnabled('countdownToggling', value);
              setState(() {
                _countdownToggling = value;
              });
            }
          ),
          
          const Divider(),
          
          // 批量操作按钮
          _buildSectionHeader('批量操作'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _featureToggles.enableAllFeatures();
                    await _loadSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('启用所有功能'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _featureToggles.disableAllFeatures();
                    await _loadSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  child: const Text('禁用所有功能'),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  // 构建功能开关
  Widget _buildFeatureToggle(
    String title, 
    String subtitle, 
    bool value, 
    Function(bool) onChanged
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }
  
  // 构建分区标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }
} 