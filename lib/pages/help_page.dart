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
            answer: '在主界面点击右下角的"+"按钮，或者在时间轴和列表视图底部找到新增入口。'),
        HelpItem(
            question: '如何编辑愿望内容？',
            answer: '点击愿望卡片进入详情页（暂未完全实现），或在列表视图中通过操作按钮编辑。'),
        HelpItem(question: '如何添加子愿望？', answer: '在全屏视图下，点击右下角的子愿望入口按钮。'),
        HelpItem(question: '如何删除愿望？', answer: '在列表视图中，点击愿望卡片右下角的操作按钮，选择删除。'),
      ],
    ),
    HelpTopic(
      title: '视图切换',
      items: [
        HelpItem(
            question: '如何切换不同的愿望展示方式？',
            answer: '点击主界面右上角的视图切换按钮，可以在全屏、时间轴、列表三种模式间循环切换。'),
        HelpItem(question: '如何在全屏模式下切换愿望？', answer: '左右滑动屏幕，或者点击底部的指示器圆点。'),
      ],
    ),
    HelpTopic(
      title: '账户与同步',
      items: [
        HelpItem(question: '如何登录账户？', answer: '在设置页面点击用户卡片区域，进入登录页面。'),
        HelpItem(
            question: '数据同步是如何工作的？',
            answer: '登录后，您的愿望数据可以同步到云端（Pro会员功能），确保数据安全并在多设备间访问。'),
        HelpItem(
            question: '如何成为Pro会员？', answer: '在设置页面点击"Pro会员"入口，查看会员权益并进行升级。'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ExpansionPanelList(
          elevation: 0, // 去掉默认阴影
          expandedHeaderPadding: EdgeInsets.zero, // 去掉展开时的内边距
          dividerColor: Colors.transparent, // 去掉分割线
          expansionCallback: (int index, bool isExpanded) {
            setState(() {
              _helpTopics[index].isExpanded = !isExpanded;
            });
          },
          children: _helpTopics.map<ExpansionPanel>((HelpTopic topic) {
            return ExpansionPanel(
              backgroundColor: Colors.transparent, // 使背景透明
              canTapOnHeader: true, // 允许点击整个头部展开
              headerBuilder: (BuildContext context, bool isExpanded) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16.0, horizontal: 8.0),
                  child: Text(
                    topic.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                );
              },
              body: Container(
                color: Colors.white, // 内容区域使用白色背景
                margin: const EdgeInsets.only(bottom: 16), // 增加卡片间距
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: topic.items.map((item) {
                      return ListTile(
                        title: Text(
                          item.question,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Text(
                            item.answer,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              isExpanded: topic.isExpanded,
            );
          }).toList(),
        ),
      ),
    );
  }
}
