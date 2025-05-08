import 'package:flutter/material.dart';

// 定义帮助主题的数据结构
class HelpTopic {
  final String title;
  final List<HelpItem> items;
  bool isExpanded;

  HelpTopic({
    required this.title,
    required this.items,
    this.isExpanded = false,
  });
}

// 定义帮助条目的数据结构
class HelpItem {
  final String question;
  final String answer;

  HelpItem({required this.question, required this.answer});
}

class HelpPage extends StatefulWidget {
  const HelpPage({super.key});

  @override
  State<HelpPage> createState() => _HelpPageState();
}

class _HelpPageState extends State<HelpPage> {
  // 模拟帮助数据
  final List<HelpTopic> _helpTopics = [
    HelpTopic(
      title: '愿望管理',
      items: [
        HelpItem(
            question: '如何创建新的愿望？',
            answer:
                '在主界面点击右下角的"+"按钮可以创建新愿望。在时间轴和网格视图中，滚动到底部也能找到添加新愿望的入口。请注意，普通用户最多可创建3个主愿望，开通会员后可创建无限数量的愿望。'),
        HelpItem(
            question: '如何编辑愿望内容？',
            answer:
                '在全屏视图中，点击愿望标题可以直接编辑；点击描述文字可以编辑描述；点击背景图片可以更换愿望的背景图片。在时间轴视图中，可以通过长按日期来修改愿望的截止日期。'),
        HelpItem(
            question: '如何添加子愿望？',
            answer:
                '在全屏视图下，点击右侧的"拆解目标"按钮（图标显示为多个小方块的组合）可以进入子愿望管理页面。在该页面中，您可以添加、查看和管理子愿望，帮助您将大目标分解为可操作的小步骤。'),
        HelpItem(
            question: '如何更改愿望状态？',
            answer:
                '在全屏视图中，点击右上角的"更多"按钮，然后选择"更改状态"选项。您可以将愿望设置为"进行中"、"已完成"或"已放弃"三种状态。在时间轴和网格视图中，也可以通过操作菜单更改状态。'),
        HelpItem(
            question: '如何删除愿望？',
            answer:
                '在全屏视图中，点击右上角的"更多"按钮，然后选择"删除"选项。在时间轴和网格视图中，点击愿望卡片上的操作按钮也可以找到删除选项。删除操作无法撤销，请谨慎操作。'),
        HelpItem(
            question: '如何分享我的愿望？',
            answer:
                '在全屏视图中，点击右上角的"更多"按钮，然后选择"分享"选项。系统会生成一张精美的分享图片，您可以将其保存到本地或直接分享给朋友。'),
      ],
    ),
    HelpTopic(
      title: '视图切换与个性化',
      items: [
        HelpItem(
            question: '如何切换不同的愿望展示方式？',
            answer:
                '点击主界面右上角的视图切换按钮，可以在三种模式间循环切换：全屏视图（展示单个愿望的详细信息）、时间轴视图（按时间顺序排列所有愿望）和网格视图（以卡片形式展示所有愿望）。'),
        HelpItem(
            question: '如何在全屏模式下浏览不同愿望？',
            answer: '在全屏视图中，左右滑动屏幕可以切换到下一个或上一个愿望。您也可以点击屏幕底部的指示器圆点直接跳转到特定的愿望。'),
        HelpItem(
            question: '如何显示或隐藏愿望的倒计时？',
            answer: '在全屏视图中，点击右上角的"更多"按钮，然后选择"显示倒计时"或"隐藏倒计时"选项即可切换倒计时的显示状态。'),
        HelpItem(
            question: '如何自定义愿望的显示内容？',
            answer:
                '在全屏视图中，点击右上角的"更多"按钮，您可以选择显示/隐藏时间信息、显示/隐藏描述文字等选项，根据个人喜好自定义愿望的展示方式。'),
      ],
    ),
    HelpTopic(
      title: '会员功能与数据同步',
      items: [
        HelpItem(
            question: '如何登录账户？',
            answer:
                '点击左上角菜单图标打开侧边栏，在侧边栏底部点击"登录"按钮，或者在设置页面中点击用户信息区域，都可以进入登录页面。目前支持手机验证码登录方式。'),
        HelpItem(
            question: '会员有哪些特权？',
            answer:
                '开通会员后，您将享有以下特权：1. 创建无限数量的主愿望（普通用户限3个）；2. 使用全部高级背景图片；3. 云端数据同步功能；4. 多设备数据互通；5. 数据定期备份；6. 优先体验新功能；7. 专属主题和图标等。'),
        HelpItem(
            question: '如何开通会员？',
            answer:
                '在侧边栏底部的同步按钮处，或在设置页面中点击"会员中心"，进入会员购买页面。您可以选择包月或包年的会员方案，支持多种支付方式。'),
        HelpItem(
            question: '数据同步是如何工作的？',
            answer:
                '登录并开通会员后，您的愿望数据会自动同步到云端。点击侧边栏底部的同步按钮可以手动触发同步。同步功能确保您的数据安全，并可以在多个设备间无缝切换使用。'),
        HelpItem(
            question: '如何在多个设备上使用？',
            answer:
                '在新设备上安装应用后，使用相同的账号登录，您的所有愿望数据将自动从云端同步到新设备。会员用户可享受多设备无缝切换的体验。'),
        HelpItem(
            question: '如果遇到问题怎么办？',
            answer:
                '如果您在使用过程中遇到任何问题，可以通过设置页面中的"反馈与建议"功能联系我们，或发送邮件至support@linzai.com。我们的支持团队会尽快为您解答。'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '使用帮助',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        itemCount: _helpTopics.length,
        itemBuilder: (context, topicIndex) {
          final topic = _helpTopics[topicIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 主题标题
              InkWell(
                onTap: () {
                  setState(() {
                    topic.isExpanded = !topic.isExpanded;
                  });
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          topic.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        topic.isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.black54,
                      )
                    ],
                  ),
                ),
              ),
              // 主题内容
              if (topic.isExpanded)
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topic.items.length,
                  itemBuilder: (context, itemIndex) {
                    final item = topic.items[itemIndex];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 问题
                          Text(
                            item.question,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 答案
                          Text(
                            item.answer,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    );
                  },
                ),
              const Divider(height: 1),
            ],
          );
        },
      ),
    );
  }
}
