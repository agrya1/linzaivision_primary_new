import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';

/// 语言设置页面
class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('语言设置'),
            ),
            body: ListView(
              children: [
                // 简体中文
                RadioListTile<String>(
                  title: const Text('简体中文'),
                  value: 'zh_CN',
                  groupValue: state.language,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsBloc>().add(
                        ChangeLanguage(value),
                      );
                    }
                  },
                ),
                
                // 英文
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en_US',
                  groupValue: state.language,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsBloc>().add(
                        ChangeLanguage(value),
                      );
                    }
                  },
                ),
                
                // 繁体中文
                RadioListTile<String>(
                  title: const Text('繁體中文'),
                  value: 'zh_TW',
                  groupValue: state.language,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsBloc>().add(
                        ChangeLanguage(value),
                      );
                    }
                  },
                ),
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