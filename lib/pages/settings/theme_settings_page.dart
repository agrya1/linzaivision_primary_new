import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';

/// 主题设置页面
class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('主题设置'),
            ),
            body: ListView(
              children: [
                // 跟随系统主题开关
                SwitchListTile(
                  title: const Text('跟随系统主题'),
                  subtitle: const Text('自动切换为系统的明暗主题'),
                  value: state.followSystemTheme,
                  onChanged: (value) {
                    context.read<SettingsBloc>().add(
                      ToggleFollowSystemTheme(value),
                    );
                  },
                ),
                
                // 仅当不跟随系统主题时显示主题选择
                if (!state.followSystemTheme) ...[
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('选择主题模式', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  
                  // 明亮主题
                  RadioListTile<String>(
                    title: const Text('明亮模式'),
                    value: 'light',
                    groupValue: state.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SettingsBloc>().add(
                          ChangeThemeMode(value),
                        );
                      }
                    },
                  ),
                  
                  // 暗黑主题
                  RadioListTile<String>(
                    title: const Text('暗黑模式'),
                    value: 'dark',
                    groupValue: state.themeMode,
                    onChanged: (value) {
                      if (value != null) {
                        context.read<SettingsBloc>().add(
                          ChangeThemeMode(value),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          );
        }
        
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
} 