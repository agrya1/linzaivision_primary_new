import '../models/explore_card.dart';

/// 探索数据仓库抽象层
abstract class ExploreRepository {
  /// 获取探索卡片列表
  Future<List<ExploreCard>> getExploreCards();
  
  /// 根据分类获取探索卡片
  Future<List<ExploreCard>> getExploreCardsByCategory(String category);
  
  /// 获取单个探索卡片
  Future<ExploreCard?> getExploreCard(String id);
}

/// 探索数据仓库实现
class ExploreRepositoryImpl implements ExploreRepository {
  @override
  Future<List<ExploreCard>> getExploreCards() async {
    // 模拟数据，实际应该从API或本地存储获取
    await Future.delayed(const Duration(milliseconds: 500)); // 模拟网络延迟
    
    return [
      ExploreCard(
        id: '1',
        title: '学习新技能',
        description: '设定一个学习目标，掌握一项新技能',
        imagePath: 'assets/images/default/default.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 1)),
        category: '学习',
        tags: ['技能', '成长', '自我提升'],
      ),
      ExploreCard(
        id: '2',
        title: '健康生活',
        description: '建立健康的生活习惯，包括运动和饮食',
        imagePath: 'assets/images/default/default2.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 2)),
        category: '健康',
        tags: ['运动', '饮食', '生活习惯'],
      ),
      ExploreCard(
        id: '3',
        title: '职业发展',
        description: '规划职业发展路径，提升专业能力',
        imagePath: 'assets/images/default/default3.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 3)),
        category: '职业',
        tags: ['职业规划', '技能提升', '工作'],
      ),
      ExploreCard(
        id: '4',
        title: '人际关系',
        description: '改善人际关系，建立更好的社交网络',
        imagePath: 'assets/images/default/default.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 4)),
        category: '社交',
        tags: ['人际关系', '社交', '沟通'],
      ),
      ExploreCard(
        id: '5',
        title: '财务规划',
        description: '制定财务计划，实现财务自由',
        imagePath: 'assets/images/default/default2.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 5)),
        category: '财务',
        tags: ['理财', '投资', '财务自由'],
      ),
      ExploreCard(
        id: '6',
        title: '创意项目',
        description: '启动一个创意项目，发挥你的创造力',
        imagePath: 'assets/images/default/default3.jpg',
        createdTime: DateTime.now().subtract(const Duration(days: 6)),
        category: '创意',
        tags: ['创意', '项目', '创新'],
      ),
    ];
  }
  
  @override
  Future<List<ExploreCard>> getExploreCardsByCategory(String category) async {
    final allCards = await getExploreCards();
    return allCards.where((card) => card.category == category).toList();
  }
  
  @override
  Future<ExploreCard?> getExploreCard(String id) async {
    final allCards = await getExploreCards();
    try {
      return allCards.firstWhere((card) => card.id == id);
    } catch (e) {
      return null;
    }
  }
} 