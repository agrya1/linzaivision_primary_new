import 'package:flutter/material.dart';
import 'package:linzaivision_primary/pages/auth/login_page.dart';
import 'package:linzaivision_primary/pages/membership/membership_page.dart';
import 'package:linzaivision_primary/pages/help_page.dart';
import 'package:linzaivision_primary/pages/feedback_page.dart';
import 'package:linzaivision_primary/pages/about_page.dart';
import 'package:linzaivision_primary/services/auth_service.dart';
import 'package:linzaivision_primary/widgets/user_avatar.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linzaivision_primary/pages/avatar_upload_page.dart';
import 'package:linzaivision_primary/pages/team_apps_page.dart';
import 'package:linzaivision_primary/pages/developer_settings_page.dart';
import 'package:linzaivision_primary/pages/settings/theme_settings_page.dart';
import 'package:linzaivision_primary/pages/settings/language_settings_page.dart';
import 'package:linzaivision_primary/pages/settings/home_page_settings_page.dart';
import 'package:linzaivision_primary/bloc/settings/settings_bloc.dart';
import 'package:linzaivision_primary/bloc/profile/profile_bloc.dart';
import 'package:linzaivision_primary/bloc/profile/profile_event.dart';
import 'package:linzaivision_primary/bloc/profile/profile_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '设置',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<AuthService>(builder: (context, authService, child) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 24),

            // 用户信息卡片
            _buildUserCard(context, authService),

            const SizedBox(height: 24),

            // 设置分组
            _buildSettingsGroup(
              context,
              title: '账户',
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.star_outline,
                  title: 'Pro会员',
                  subtitle: '解锁更多高级功能',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MembershipPage()),
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.sync,
                  title: '数据同步',
                  subtitle: '敬请期待',
                  onTap: () {},
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 个性化设置分组
            BlocBuilder<SettingsBloc, SettingsState>(
              builder: (context, state) {
                if (state is SettingsLoaded) {
                  return _buildSettingsGroup(
                    context,
                    title: '个性化',
                    children: [
                      _buildSettingItem(
                        context,
                        icon: Icons.brightness_6,
                        title: '主题设置',
                        subtitle: state.followSystemTheme 
                            ? '跟随系统' 
                            : (state.themeMode == 'dark' ? '暗黑模式' : '明亮模式'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ThemeSettingsPage()),
                        ),
                      ),
                      _buildSettingItem(
                        context,
                        icon: Icons.language,
                        title: '语言设置',
                        subtitle: _getLanguageName(state.language),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LanguageSettingsPage()),
                        ),
                      ),
                      _buildSettingItem(
                        context,
                        icon: Icons.home,
                        title: '首页设置',
                        subtitle: state.homePage == 'explore' ? '意识探索' : '我的意识',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const HomePageSettingsPage()),
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink(); // 如果状态未加载，则不显示此分组
              },
            ),

            const SizedBox(height: 24),

            // 关于分组
            _buildSettingsGroup(
              context,
              title: '关于',
              children: [
                _buildSettingItem(
                  context,
                  icon: Icons.help_outline,
                  title: '帮助中心',
                  subtitle: '常见问题解答',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpPage()),
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.feedback_outlined,
                  title: '意见反馈',
                  subtitle: '帮助我们改进产品',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FeedbackPage()),
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.info_outline,
                  title: '关于临在',
                  subtitle: '了解更多关于我们的信息',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AboutPage()),
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.apps_outlined,
                  title: '我们的应用',
                  subtitle: '探索更多应用',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TeamAppsPage()),
                  ),
                ),
                _buildSettingItem(
                  context,
                  icon: Icons.developer_mode,
                  title: '开发者设置',
                  subtitle: 'BLoC功能开关和调试选项',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DeveloperSettingsPage()),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // 退出登录按钮
            if (authService.isLoggedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: () => _showLogoutDialog(context, authService),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('退出登录'),
                ),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildUserCard(BuildContext context, AuthService authService) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, profileState) {
            final bool isLoggedIn = profileState is ProfileLoaded ? profileState.isLoggedIn : authService.isLoggedIn;
            final String? displayName = profileState is ProfileLoaded ? profileState.displayName : authService.userName;
            final String? phoneNumber = authService.phoneNumber;
            final bool isUpdating = profileState is DisplayNameUpdating;
            
            return isLoggedIn
                ? Row(
                    children: [
                      // 用户头像，点击修改
                      GestureDetector(
                        onTap: () => _navigateToAvatarUpload(context),
                        child: Stack(
                          children: [
                            const UserAvatar(
                              size: 60,
                              borderRadius: 30,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 用户昵称，点击修改
                            GestureDetector(
                              onTap: () => _showDisplayNameDialog(context, displayName ?? ''),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      displayName ?? '用户${phoneNumber?.substring(7) ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 16),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              phoneNumber != null
                                  ? '手机号: ${_formatPhoneNumber(phoneNumber)}'
                                  : '未绑定手机号',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : InkWell(
                    onTap: () => _navigateToLogin(context),
                    child: Row(
                      children: [
                        // 未登录的头像
                        const UserAvatar(
                          size: 60,
                          borderRadius: 30,
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '未登录',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '登录以同步您的数据',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  );
          },
        ),
      ),
    );
  }

  // 格式化手机号，中间四位显示为星号
  String _formatPhoneNumber(String phone) {
    if (phone.length != 11) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(7)}';
  }

  // 导航到登录页面
  Future<void> _navigateToLogin(BuildContext context) async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const LoginPage()));

    // 如果登录成功，刷新页面
    if (result == true) {
      // 页面会自动刷新，因为我们使用了Consumer
    }
  }

  // 导航到头像上传页面
  void _navigateToAvatarUpload(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AvatarUploadPage()),
    );
  }

  Widget _buildSettingsGroup(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.black),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  void _showHelpPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HelpPage()),
    );
  }

  void _showFeedbackPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FeedbackPage()),
    );
  }

  void _showAboutPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AboutPage()),
    );
  }

  void _showTeamAppsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TeamAppsPage()),
    );
  }
  
  void _showDeveloperSettingsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeveloperSettingsPage()),
    );
  }

  void _showDisplayNameDialog(BuildContext context, String currentDisplayName) {
    final TextEditingController _displayNameController = TextEditingController(text: currentDisplayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: _displayNameController,
          decoration: const InputDecoration(
            hintText: '请输入新的昵称',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newDisplayName = _displayNameController.text.trim();
              if (newDisplayName.isNotEmpty) {
                context.read<ProfileBloc>().add(UpdateDisplayName(newDisplayName));
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('昵称不能为空')),
                );
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              // 实现退出登录逻辑
              await authService.logout();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
  
  /// 根据语言代码获取语言名称
  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'zh_CN':
        return '简体中文';
      case 'en_US':
        return 'English';
      case 'zh_TW':
        return '繁體中文';
      default:
        return '简体中文';
    }
  }
}
