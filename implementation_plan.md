# 临在意识项目升级实施计划

## 项目概述
将当前的愿景管理工具扩展为更广泛的"意识观测和管理工具"，支持更灵活的意识条目管理和视频背景功能。

## 实施优先级与任务依赖

### 优先级排序
1. 模型层和数据库修改（基础设施）
2. 全屏视图操作菜单
3. 时间显示逻辑调整
4. 树视图修改
5. 视频背景支持
6. 探索模块新增

### 关键任务依赖关系
- 所有UI修改依赖于模型层修改
- 视频背景支持依赖于菜单UI实现
- 倒计时逻辑调整依赖于时间显示逻辑调整
- 探索模块可以独立实现，与其他功能耦合度低

## 一、时间逻辑调整

### 1. 模型层修改
- [ ] 确认现有`Goal`模型中的`targetDate`已是可选字段
- [ ] 在数据库操作相关代码中确保正确处理无截止日期的条目
- [ ] 扩展`Goal`类，添加判断方法：
  ```dart
  bool get hasTargetDate => targetDate != null;
  ```
- [ ] 审查并确保数据库中目标的JSON序列化和反序列化正确处理null的targetDate

### 2. 全屏视图截止日期逻辑
- [ ] 在`full_screen_view.dart`右上角添加操作menu，实现如下：
  ```dart
  Widget _buildOptionsMenu(Goal goal) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      right: 16,
      child: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.white),
        onSelected: (value) {
          // 处理不同的菜单选项
          switch (value) {
            case 'setDeadline': _handleSetDeadline(); break;
            case 'deleteDeadline': _handleDeleteDeadline(); break;
            // 其他菜单项...
          }
        },
        itemBuilder: (context) => _buildMenuItems(goal),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems(Goal goal) {
    final List<PopupMenuEntry<String>> items = [];
    
    // 添加截止日期相关选项
    if (goal.hasTargetDate) {
      items.add(_buildMenuItem('deleteDeadline', '删除截止日期'));
    } else {
      items.add(_buildMenuItem('setDeadline', '设置截止日期'));
    }
    
    // 其他菜单项...
    
    return items;
  }
  ```
- [ ] 添加"设置截止日期"功能，已有截止日期时显示为"删除截止日期"
- [ ] 修改日期显示逻辑，仅在设置截止日期后显示日期编辑文本
- [ ] 将"显示时间"和"关闭时间"功能名称改为"显示截止日期"和"隐藏截止日期"
- [ ] 为没有截止日期的条目隐藏截止日期相关功能选项

### 3. 时间轴视图调整
- [ ] 修改`timeline_view.dart`中时间显示逻辑：
  ```dart
  Widget _buildDateDisplay(Goal goal) {
    if (goal.targetDate == null) {
      return SizedBox.shrink(); // 无截止日期不显示时间
    }
    
    return Column(
      children: [
        Text(
          '${DateFormat('yyyy.MM.dd').format(goal.createdTime)}',
          style: TextStyle(/* ... */),
        ),
        Text('—', style: TextStyle(/* ... */)),
        Text(
          '${DateFormat('yyyy.MM.dd').format(goal.targetDate!)}',
          style: TextStyle(/* ... */),
        ),
      ],
    );
  }
  ```
- [ ] 调整左侧时间显示为"新建日期——截止日期"时间段格式
- [ ] 为无截止日期的条目隐藏时间显示
- [ ] 从新建条目弹窗中移除日期设置开关入口：
  ```dart
  // 修改现有的新建目标弹窗，移除日期相关组件
  Widget _buildNewGoalDialog() {
    return Dialog(
      // ...
      child: Column(
        children: [
          // 标题、描述输入
          // 移除原有的日期设置开关
          // 图片/视频选择
          // ...
        ],
      ),
    );
  }
  ```

### 4. 倒计时逻辑优化
- [ ] 修改倒计时相关代码，区分有截止日期和无截止日期的情况：
  ```dart
  Widget _buildCountdownOption(Goal goal) {
    if (goal.hasTargetDate) {
      // 有截止日期时的倒计时选项
      return PopupMenuItem<String>(
        value: _showCountdown ? 'hideCountdown' : 'showCountdown',
        child: Text(_showCountdown ? '隐藏倒计时' : '显示倒计时'),
      );
    } else {
      // 无截止日期时的倒计时选项
      return PopupMenuItem<String>(
        value: _hasCustomCountdown ? 'closeCountdown' : 'setCountdown',
        child: Text(_hasCustomCountdown ? '关闭倒计时' : '设置倒计时'),
      );
    }
  }
  ```
- [ ] 有截止日期时：添加"显示倒计时"/"隐藏倒计时"选项，精确到日期
- [ ] 无截止日期时：提供"设置倒计时"/"关闭倒计时"选项，需要实现自定义倒计时设置对话框
- [ ] 实现自定义倒计时设置对话框：
  ```dart
  Future<void> _showCustomCountdownDialog() async {
    final initialDays = _customCountdownDays ?? 30;
    int selectedDays = initialDays;
    
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置倒计时天数'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择倒计时天数: $selectedDays'),
                Slider(
                  min: 1,
                  max: 365,
                  divisions: 364,
                  value: selectedDays.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      selectedDays = value.round();
                    });
                  },
                ),
              ],
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, selectedDays),
            child: Text('确定'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      setState(() {
        _customCountdownDays = result;
        _hasCustomCountdown = true;
      });
      // 保存设置
    }
  }
  ```

## 二、全屏视图操作菜单优化

### 1. 右上角操作菜单实现
- [ ] 设计菜单图标和弹出样式：
  ```dart
  // 菜单图标样式
  final menuIconStyle = BoxDecoration(
    color: Colors.black.withOpacity(0.3),
    shape: BoxShape.circle,
  );
  
  // 菜单项样式
  final menuItemTextStyle = TextStyle(
    color: Colors.black87,
    fontSize: 16,
  );
  ```
- [ ] 实现菜单弹出逻辑和动画效果
- [ ] 将原有的显示控制功能整合到menu中，包括时间显示、描述显示等

### 2. 文本标题控制
- [ ] 添加状态变量：
  ```dart
  bool _showTitle = true; // 默认显示标题
  ```
- [ ] 添加"显示文本"/"隐藏文本"开关功能：
  ```dart
  PopupMenuItem<String>(
    value: 'toggleTitle',
    child: Text(_showTitle ? '隐藏文本' : '显示文本'),
  )
  ```
- [ ] 实现文本显示隐藏的状态管理：
  ```dart
  void _toggleTitleVisibility() {
    setState(() {
      _showTitle = !_showTitle;
    });
  }
  ```
- [ ] 修改标题显示逻辑：
  ```dart
  Widget _buildTitle(Goal goal) {
    if (!_showTitle) return SizedBox.shrink();
    
    return Text(
      goal.title,
      style: TextStyle(/* ... */),
    );
  }
  ```

### 3. 子条目管理
- [ ] 将"新增子条目"功能移至右上角menu：
  ```dart
  PopupMenuItem<String>(
    value: 'addSubGoal',
    child: Text('新增子条目'),
  )
  ```
- [ ] 实现子条目添加逻辑，复用现有的添加功能
- [ ] 移除屏幕右下角原有的添加按钮：
  ```dart
  // 在full_screen_view.dart中移除以下组件
  // Positioned(
  //   bottom: 32,
  //   right: 32,
  //   child: FloatingActionButton(
  //     onPressed: _handleAddSubGoal,
  //     child: Icon(Icons.add),
  //   ),
  // ),
  ```

## 三、树视图修改

### 1. 界面元素更新
- [ ] 在`goal_tree_view.dart`中将"心愿池"文案替换为logo图标：
  ```dart
  // 替换
  // Text('心愿池', style: Theme.of(context).textTheme.headlineMedium),
  // 为
  GestureDetector(
    onTap: _navigateToFirstCard,
    child: Image.asset(
      'assets/images/logo.png',
      width: 40,
      height: 40,
    ),
  )
  ```
- [ ] 实现logo点击回到第一个意识卡片的功能：
  ```dart
  void _navigateToFirstCard() {
    if (widget.goals.isNotEmpty && widget.onGoalSelect != null) {
      widget.onGoalSelect!(widget.goals.first);
    }
  }
  ```

### 2. 搜索功能调整
- [ ] 将树视图的搜索条目移除：
  ```dart
  // 删除以下搜索栏相关代码
  // Material(
  //   color: Colors.transparent,
  //   child: InkWell(
  //     onTap: widget.onSearchTap,
  //     child: Container(/* 搜索栏UI */),
  //   ),
  // ),
  ```
- [ ] 在右上角添加搜索图标：
  ```dart
  Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Logo
      Image.asset('assets/images/logo.png', width: 40, height: 40),
      
      // 右上角搜索图标
      IconButton(
        icon: Icon(Icons.search),
        onPressed: widget.onSearchTap,
      ),
    ],
  )
  ```
- [ ] 调整搜索交互逻辑，确保功能不变

## 四、探索模块新增

### 1. 模块架构设计
- [ ] 创建`explore_view.dart`视图文件：
  ```dart
  class ExploreView extends StatefulWidget {
    final Function(Goal) onSelectCard;
    
    const ExploreView({
      Key? key,
      required this.onSelectCard,
    }) : super(key: key);
    
    @override
    _ExploreViewState createState() => _ExploreViewState();
  }
  
  class _ExploreViewState extends State<ExploreView> with SingleTickerProviderStateMixin {
    late TabController _tabController;
    final List<String> _categories = ['推荐', '工作', '学习', '健康', '生活'];
    
    // 状态变量
    List<Goal> _exploreCards = [];
    bool _isLoading = true;
    
    @override
    void initState() {
      super.initState();
      _tabController = TabController(length: _categories.length, vsync: this);
      _loadExploreData();
    }
    
    // 加载数据逻辑
    Future<void> _loadExploreData() async {
      // TODO: 实现后台数据加载
    }
    
    @override
    Widget build(BuildContext context) {
      return Column(
        children: [
          // 分类标签栏
          TabBar(
            controller: _tabController,
            tabs: _categories.map((e) => Tab(text: e)).toList(),
            // 样式设置...
          ),
          
          // 网格内容区
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _categories.map((category) => 
                _buildCategoryGrid(category)
              ).toList(),
            ),
          ),
        ],
      );
    }
    
    Widget _buildCategoryGrid(String category) {
      // TODO: 实现网格视图
    }
  }
  ```
- [ ] 设计探索页面的基本布局，包括顶部分类标签和网格内容区

### 2. 树视图入口
- [ ] 在树视图中添加"探索"入口项：
  ```dart
  Widget _buildExploreEntry() {
    return ListTile(
      leading: Icon(Icons.explore),
      title: Text('探索'),
      onTap: widget.onExploreTab,
    );
  }
  ```
- [ ] 在`goal_page.dart`中添加探索页面导航：
  ```dart
  void _navigateToExplore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('探索')),
          body: ExploreView(
            onSelectCard: (Goal card) {
              // 处理卡片选择
            },
          ),
        ),
      ),
    );
  }
  ```

### 3. 网格视图实现
- [ ] 设计网格布局，复用现有的网格视图组件：
  ```dart
  Widget _buildCategoryGrid(String category) {
    // 根据分类过滤卡片
    final filteredCards = _exploreCards.where((card) => 
      // TODO: 实现分类过滤逻辑
    ).toList();
    
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
  
  Widget _buildGridItem(Goal card) {
    // 复用现有的GoalCard组件或创建新的卡片组件
    return GestureDetector(
      onTap: () => widget.onSelectCard(card),
      child: // 卡片UI
    );
  }
  ```
- [ ] 实现分类标签的UI和交互

### 4. 数据源对接
- [ ] 设计与后台API的数据交互接口：
  ```dart
  class ExploreService {
    static Future<List<Goal>> getExploreCards({String? category}) async {
      try {
        // TODO: 实现API调用
        final response = await http.get(
          Uri.parse('https://api.example.com/explore?category=$category'),
        );
        
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.map((json) => Goal.fromJson(json)).toList();
        } else {
          throw Exception('Failed to load explore cards');
        }
      } catch (e) {
        // 错误处理
        return [];
      }
    }
  }
  ```
- [ ] 实现数据加载和缓存机制：
  ```dart
  // 在ExploreView中添加
  Future<void> _loadExploreData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final cards = await ExploreService.getExploreCards();
      
      setState(() {
        _exploreCards = cards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // 显示错误提示
    }
  }
  ```

## 五、视频背景支持

### 1. 模型扩展
- [ ] 扩展`Goal`模型，添加`videoPath`和相关的视频属性：
  ```dart
  // 在lib/models/goal.dart中添加
  class Goal {
    // 现有属性...
    String? videoPath; // 视频路径
    bool hasVideo; // 是否有视频
    bool videoMuted; // 视频是否静音
    
    Goal({
      // 现有参数...
      this.videoPath,
      this.hasVideo = false,
      this.videoMuted = false,
    });
    
    // 修改fromJson方法
    factory Goal.fromJson(Map<String, dynamic> json) {
      return Goal(
        // 现有字段...
        videoPath: json['videoPath'] as String?,
        hasVideo: json['hasVideo'] as bool? ?? false,
        videoMuted: json['videoMuted'] as bool? ?? false,
      );
    }
    
    // 修改toJson方法
    Map<String, dynamic> toJson() {
      return {
        // 现有字段...
        'videoPath': videoPath,
        'hasVideo': hasVideo,
        'videoMuted': videoMuted,
      };
    }
    
    // 同样修改toMap和fromMap方法
  }
  ```
- [ ] 更新数据库相关代码支持视频存储：
  ```dart
  // 在database_helper.dart中修改数据库表结构
  final String createGoalsTable = '''
    CREATE TABLE goals(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT,
      image_path TEXT NOT NULL,
      status INTEGER NOT NULL,
      created_time INTEGER NOT NULL,
      target_date INTEGER,
      parent_id INTEGER,
      video_path TEXT,
      has_video INTEGER NOT NULL DEFAULT 0,
      video_muted INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (parent_id) REFERENCES goals (id) ON DELETE CASCADE
    )
  ''';
  
  // 修改插入和查询方法
  ```

### 2. 视频选择功能
- [ ] 扩展现有的图片选择器，支持视频选择：
  ```dart
  // 在image_picker_dialog.dart中添加视频选择功能
  Future<void> _pickVideo(ImageSource source) async {
    final XFile? pickedFile = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 1), // 限制视频长度
    );
    
    if (pickedFile != null) {
      // 处理选择的视频文件
      widget.onFileSelected?.call(pickedFile.path, true); // 第二个参数表示这是视频
    }
    Navigator.pop(context);
  }
  ```
- [ ] 在新建弹窗中添加视频选择选项：
  ```dart
  // 添加视频选项按钮
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // 现有的图片选择按钮
      IconButton(
        icon: Icon(Icons.image),
        onPressed: _showImagePicker,
      ),
      // 新增视频选择按钮
      IconButton(
        icon: Icon(Icons.videocam),
        onPressed: _showVideoPicker,
      ),
    ],
  ),
  ```

### 3. 视频播放控制
- [ ] 添加视频播放器组件：
  ```dart
  // 在full_screen_view.dart中添加
  import 'package:video_player/video_player.dart';
  
  // 状态类中添加
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  
  // 初始化视频控制器
  void _initializeVideoController(Goal goal) {
    if (goal.hasVideo && goal.videoPath != null) {
      _videoController = VideoPlayerController.file(File(goal.videoPath!))
        ..initialize().then((_) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController!.setLooping(true);
          _videoController!.play();
          _videoController!.setVolume(goal.videoMuted ? 0 : 1);
        });
    }
  }
  
  // 释放资源
  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }
  ```
- [ ] 在全屏视图中实现视频背景的播放功能：
  ```dart
  Widget _buildBackgroundMedia(Goal goal) {
    if (goal.hasVideo && goal.videoPath != null) {
      if (_videoController != null && _isVideoInitialized) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      } else {
        return Center(child: CircularProgressIndicator());
      }
    } else {
      // 原有的图片背景逻辑
      return _buildBackgroundImage(goal);
    }
  }
  ```
- [ ] 在右上角菜单中添加"关闭声音"和"暂停播放"按钮：
  ```dart
  // 视频控制菜单项
  if (goal.hasVideo) {
    // 声音控制
    items.add(PopupMenuItem<String>(
      value: 'toggleSound',
      child: Text(_isMuted ? '打开声音' : '关闭声音'),
    ));
    
    // 播放控制
    items.add(PopupMenuItem<String>(
      value: 'togglePlay',
      child: Text(_isPlaying ? '暂停播放' : '继续播放'),
    ));
  }
  ```
- [ ] 实现视频控制相关的状态管理：
  ```dart
  void _toggleVideoSound() {
    if (_videoController != null) {
      setState(() {
        _isMuted = !_isMuted;
        _videoController!.setVolume(_isMuted ? 0 : 1);
      });
      
      // 更新数据库中的静音状态
      if (widget.currentGoal != null) {
        final updatedGoal = widget.currentGoal!.copyWith(
          videoMuted: _isMuted,
        );
        // 保存更新...
      }
    }
  }
  
  void _toggleVideoPlayback() {
    if (_videoController != null) {
      setState(() {
        _isPlaying = !_isPlaying;
        _isPlaying ? _videoController!.play() : _videoController!.pause();
      });
    }
  }
  ```

## 六、数据库迁移策略

### 1. 数据库版本升级
- [ ] 在`database_helper.dart`中定义新版本号：
  ```dart
  static const int _databaseVersion = 2; // 从1升级到2
  ```
- [ ] 实现数据库版本升级回调：
  ```dart
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加视频支持字段
      await db.execute('ALTER TABLE goals ADD COLUMN video_path TEXT');
      await db.execute('ALTER TABLE goals ADD COLUMN has_video INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE goals ADD COLUMN video_muted INTEGER NOT NULL DEFAULT 0');
      
      // 添加自定义倒计时支持字段
      await db.execute('ALTER TABLE goals ADD COLUMN custom_countdown_days INTEGER');
      await db.execute('ALTER TABLE goals ADD COLUMN has_custom_countdown INTEGER NOT NULL DEFAULT 0');
      
      print('数据库从版本 $oldVersion 升级到版本 $newVersion 完成');
    }
  }
  ```
  
### 2. 数据备份与恢复策略
- [ ] 实现数据库备份功能：
  ```dart
  Future<File> backupDatabase() async {
    final dbPath = await getDatabasesPath();
    final dbFile = File(join(dbPath, 'goals.db'));
    
    // 创建备份目录
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/backups');
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
    
    // 创建备份文件
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final backupFile = File('${backupDir.path}/goals_backup_$timestamp.db');
    
    // 复制数据库文件
    await dbFile.copy(backupFile.path);
    return backupFile;
  }
  ```

- [ ] 在版本升级前执行自动备份：
  ```dart
  Future _initDatabase() async {
    final dbPath = await getDatabasesPath();
    String path = join(dbPath, 'goals.db');
    
    // 检查数据库是否存在，如果存在则在升级前备份
    if (await databaseExists(path)) {
      await backupDatabase();
    }
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  ```

### 3. 数据迁移验证
- [ ] 创建数据迁移验证工具类：
  ```dart
  class DatabaseMigrationValidator {
    static Future<bool> validateMigration(DatabaseHelper dbHelper) async {
      try {
        // 验证所有目标数据是否正确
        final goals = await dbHelper.getGoalTree();
        
        // 检查新增字段是否正确设置
        for (var goal in goals) {
          // 基本检查
          if (goal.title == null || goal.title.isEmpty) {
            print('错误: 发现标题为空的目标，ID: ${goal.id}');
            return false;
          }
          
          // 检查图片/视频路径有效性
          if (goal.imagePath.isEmpty && (goal.videoPath == null || goal.videoPath!.isEmpty)) {
            print('错误: 目标ID ${goal.id} 既没有图片也没有视频');
            return false;
          }
        }
        
        return true;
      } catch (e) {
        print('验证迁移失败: $e');
        return false;
      }
    }
  }
  ```

## 测试计划

### 1. 功能测试
- [ ] 测试截止日期设置和删除：
  - 确认能正确添加截止日期
  - 验证删除截止日期功能
  - 检查日期格式显示是否正确
  - 测试截止日期相关菜单项的显示/隐藏逻辑

- [ ] 测试倒计时显示在不同情况下的表现：
  - 有截止日期的倒计时显示
  - 无截止日期的自定义倒计时
  - 倒计时格式和准确性
  - 倒计时显示/隐藏功能

- [ ] 测试右上角菜单的各项功能：
  - 菜单弹出和UI表现
  - 各菜单项点击操作的响应
  - 菜单项状态变化

- [ ] 验证树视图和探索模块的交互：
  - 从树视图进入探索模块
  - 探索模块标签切换
  - 从探索模块选择卡片后的行为

### 2. 界面测试
- [ ] 验证在不同屏幕尺寸下的UI表现：
  - 在小屏手机上测试（5.0寸）
  - 在大屏手机上测试（6.5寸+）
  - 在平板设备上测试（如有需要）

- [ ] 测试视频播放的性能和稳定性：
  - 测试各种分辨率的视频文件
  - 测试较长视频的循环播放稳定性
  - 测试视频切换的性能
  - 测试视频播放时的内存使用情况

- [ ] 验证全屏视图中各元素的显示隐藏效果：
  - 标题显示/隐藏
  - 描述显示/隐藏
  - 日期显示/隐藏
  - 视频控制按钮的显示/隐藏

### 3. 数据完整性测试
- [ ] 确保数据库迁移正确处理新旧数据：
  ```dart
  // 数据库迁移脚本
  Future<void> _upgradeDb(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 添加新字段
      await db.execute('''
        ALTER TABLE goals ADD COLUMN video_path TEXT;
        ALTER TABLE goals ADD COLUMN has_video INTEGER NOT NULL DEFAULT 0;
        ALTER TABLE goals ADD COLUMN video_muted INTEGER NOT NULL DEFAULT 0;
      ''');
    }
  }
  ```

- [ ] 验证添加/删除截止日期后的数据一致性：
  - 添加后检查数据库中是否正确保存日期
  - 删除后检查字段是否正确置空
  - 确认相关UI正确反映变更

- [ ] 测试数据迁移的边界情况：
  - 数据库中有大量数据时的迁移
  - 迁移过程中断的恢复
  - 从备份恢复数据

### 4. 集成测试
- [ ] 创建自动化测试脚本，测试关键功能流程：
  ```dart
  void main() {
    testWidgets('测试设置和删除截止日期', (WidgetTester tester) async {
      // 构建测试应用
      await tester.pumpWidget(MyApp());
      
      // 模拟操作流程
      // ...
      
      // 验证结果
      // ...
    });
    
    testWidgets('测试视频背景功能', (WidgetTester tester) async {
      // 构建测试应用
      await tester.pumpWidget(MyApp());
      
      // 模拟操作流程
      // ...
      
      // 验证结果
      // ...
    });
  }
  ```

## 风险管理

### 主要风险点及应对措施

#### 1. 数据迁移风险
- **风险描述**：升级后用户现有数据丢失或损坏
- **严重程度**：高
- **应对措施**：
  - 实施自动数据库备份机制
  - 设置迁移验证流程
  - 首批限制范围内测试升级
  - 提供手动恢复功能

#### 2. 视频播放性能
- **风险描述**：视频播放可能导致内存占用过高或卡顿
- **严重程度**：中
- **应对措施**：
  - 限制视频文件大小和时长
  - 实现视频压缩和转码
  - 预设缓冲策略
  - 低配设备降级处理

#### 3. 新旧功能兼容
- **风险描述**：新功能与已有功能的交互冲突
- **严重程度**：中
- **应对措施**：
  - 增量开发和测试
  - 建立完整回归测试
  - 提供功能开关，允许用户临时关闭新功能

#### 4. 用户体验断层
- **风险描述**：用户对新交互方式不适应
- **严重程度**：低
- **应对措施**：
  - 添加新功能引导
  - 收集用户反馈渠道
  - 在关键改动处增加提示

## 交付时间线

### 第一阶段：模型调整和基础框架 (5天)
- 模型扩展
- 数据库适配
- 界面框架调整

### 第二阶段：全屏视图和时间逻辑 (7天)
- 右上角菜单实现
- 截止日期和倒计时逻辑调整
- 时间显示格式更新

### 第三阶段：树视图和探索模块 (6天)
- 树视图界面调整
- 探索模块基本框架
- 后台数据对接

### 第四阶段：视频功能和优化 (7天)
- 视频选择和播放功能
- 视频控制界面
- 整体性能优化

### 第五阶段：测试和修复 (5天)
- 全面功能测试
- bug修复
- 文档完善

## 依赖管理

需要在`pubspec.yaml`中添加的新依赖：

```yaml
dependencies:
  # 现有依赖...
  video_player: ^2.6.0  # 视频播放功能
  chewie: ^1.5.0        # 视频播放器UI
  path_provider: ^2.0.15 # 文件路径管理
  cached_network_image: ^3.2.3 # 网络图片缓存（探索模块）
``` 