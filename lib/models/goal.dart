/// 目标状态枚举
enum GoalStatus {
  pending, // 待完成
  completed, // 已完成
  abandoned // 已废弃
}

/// 目标数据模型
class Goal {
  int? id; // 唯一标识符
  String title; // 目标标题
  String description; // 目标描述
  String imagePath; // 目标图片路径
  DateTime createdTime; // 创建时间
  DateTime? targetDate; // 目标完成日期
  GoalStatus status; // 目标状态
  List<Goal> subGoals; // 子目标列表
  int? parentId; // 父目标引用

  Goal({
    this.id,
    required this.title,
    this.description = '',
    required this.imagePath,
    this.status = GoalStatus.pending,
    required this.createdTime,
    this.targetDate,
    this.parentId,
    this.subGoals = const [],
  });

  /// 从 JSON 创建目标
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      createdTime: DateTime.parse(json['createdTime'] as String),
      targetDate: json['targetDate'] != null
          ? DateTime.parse(json['targetDate'] as String)
          : null,
      status: GoalStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => GoalStatus.pending,
      ),
      subGoals: (json['subGoals'] as List<dynamic>?)
              ?.map((e) => Goal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'createdTime': createdTime.toIso8601String(),
      'targetDate': targetDate?.toIso8601String(),
      'status': status.toString(),
      'subGoals': subGoals.map((goal) => goal.toJson()).toList(),
    };
  }

  /// 复制目标（用于状态更新）
  Goal copyWith({
    String? title,
    String? description,
    String? imagePath,
    DateTime? createdTime,
    DateTime? targetDate,
    GoalStatus? status,
    List<Goal>? subGoals,
    int? parentId,
  }) {
    return Goal(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      createdTime: createdTime ?? this.createdTime,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      subGoals: subGoals ?? this.subGoals,
      parentId: parentId ?? this.parentId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_path': imagePath,
      'status': status.index,
      'created_time': createdTime.millisecondsSinceEpoch,
      'target_date': targetDate?.millisecondsSinceEpoch,
      'parent_id': parentId,
    };
  }

  /// 从数据库Map创建对象
  factory Goal.fromMap(Map<String, dynamic> map) {
    return Goal(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      imagePath: map['image_path'],
      status: GoalStatus.values[map['status']],
      createdTime: DateTime.fromMillisecondsSinceEpoch(map['created_time']),
      targetDate: map['target_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['target_date'])
          : null,
      parentId: map['parent_id'],
    );
  }
}
