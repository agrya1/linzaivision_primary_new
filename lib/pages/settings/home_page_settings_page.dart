import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/settings/settings_bloc.dart';

/// 首页设置页面
class HomePageSettingsPage extends StatelessWidget {
  const HomePageSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, state) {
        if (state is SettingsLoaded) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('首页设置'),
            ),
            body: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('选择启动时显示的页面', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                
                // 意识探索
                RadioListTile<String>(
                  title: const Text('意识探索'),
                  subtitle: const Text('启动时显示探索页面'),
                  value: 'explore',
                  groupValue: state.homePage,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsBloc>().add(
                        ChangeHomePage(value),
                      );
                    }
                  },
                ),
                
                // 第一条意识条目
                RadioListTile<String>(
                  title: const Text('我的意识'),
                  subtitle: const Text('启动时显示第一条意识条目'),
                  value: 'first_goal',
                  groupValue: state.homePage,
                  onChanged: (value) {
                    if (value != null) {
                      context.read<SettingsBloc>().add(
                        ChangeHomePage(value),
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