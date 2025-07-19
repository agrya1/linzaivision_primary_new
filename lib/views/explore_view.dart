import 'package:flutter/material.dart';
import '../models/goal.dart';
import '../widgets/common/goal_card.dart';

/// 探索模块视图
class ExploreView extends StatefulWidget {
  final Function(Goal) onSelectCard;

  const ExploreView({
    Key? key,
    required this.onSelectCard,
  }) : super(key: key);

  @override
  _ExploreViewState createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _categories = ['推荐', '工作', '学习', '健康', '生活'];

  // 状态变量
  List<Goal> _exploreCards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _loadExploreData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 加载探索数据
  Future<void> _loadExploreData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 模拟从API加载数据
      await Future.delayed(const Duration(seconds: 1));

      // 创建模拟数据
      final List<Goal> mockCards = [
        Goal(
          title: '每天读30页书',
          description: '坚持阅读，拓宽视野',
          imagePath: 'assets/images/default/books.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '学习Flutter编程',
          description: '掌握跨平台开发技能',
          imagePath: 'assets/images/default/coding.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '每周健身三次',
          description: '保持健康的生活方式',
          imagePath: 'assets/images/default/fitness.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '学习一门新语言',
          description: '拓展国际视野',
          imagePath: 'assets/images/default/language.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '每日冥想15分钟',
          description: '提高专注力和内观能力',
          imagePath: 'assets/images/default/meditation.jpg',
          createdTime: DateTime.now(),
        ),
        Goal(
          title: '完成一个个人项目',
          description: '将想法变成现实',
          imagePath: 'assets/images/default/project.jpg',
          createdTime: DateTime.now(),
        ),
      ];

      setState(() {
        _exploreCards = mockCards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载探索数据失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 分类标签栏
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.black,
            tabs: _categories.map((category) => Tab(text: category)).toList(),
          ),
        ),

        // 内容区域
        Expanded(
          child: _isLoading
              ? Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(_error!, style: TextStyle(color: Colors.red)))
                  : TabBarView(
                      controller: _tabController,
                      children: _categories
                          .map((category) => _buildCategoryGrid(category))
                          .toList(),
                    ),
        ),
      ],
    );
  }

  // 构建分类网格
  Widget _buildCategoryGrid(String category) {
    // 根据分类过滤卡片（此处简化处理，实际应根据分类标签筛选）
    final List<Goal> filteredCards = _exploreCards;

    if (filteredCards.isEmpty) {
      return Center(child: Text('暂无${category}卡片'));
    }

    return GridView.builder(
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: filteredCards.length,
      itemBuilder: (context, index) {
        return _buildGridItem(filteredCards[index]);
      },
    );
  }

  // 构建网格项
  Widget _buildGridItem(Goal card) {
    return GestureDetector(
      onTap: () => widget.onSelectCard(card),
      child: GoalCard(
        goal: card,
        onTap: () => widget.onSelectCard(card),
        onMoreTap: () {},
        onStatusChange: (_) {}, // 探索页面不提供状态更改功能
      ),
    );
  }
}
 