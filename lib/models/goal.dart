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

  // 视频相关属性
  String? videoPath; // 视频路径
  bool hasVideo; // 是否有视频
  bool videoMuted; // 视频是否静音

  // 自定义倒计时
  int? customCountdownDays; // 自定义倒计时天数
  bool hasCustomCountdown; // 是否有自定义倒计时

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
    this.videoPath,
    this.hasVideo = false,
    this.videoMuted = false,
    this.customCountdownDays,
    this.hasCustomCountdown = false,
  });

  /// 判断是否有截止日期
  bool get hasTargetDate => targetDate != null;

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
      videoPath: json['videoPath'] as String?,
      hasVideo: json['hasVideo'] as bool? ?? false,
      videoMuted: json['videoMuted'] as bool? ?? false,
      customCountdownDays: json['customCountdownDays'] as int?,
      hasCustomCountdown: json['hasCustomCountdown'] as bool? ?? false,
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
      'videoPath': videoPath,
      'hasVideo': hasVideo,
      'videoMuted': videoMuted,
      'customCountdownDays': customCountdownDays,
      'hasCustomCountdown': hasCustomCountdown,
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
    String? videoPath,
    bool? hasVideo,
    bool? videoMuted,
    int? customCountdownDays,
    bool? hasCustomCountdown,
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
      videoPath: videoPath ?? this.videoPath,
      hasVideo: hasVideo ?? this.hasVideo,
      videoMuted: videoMuted ?? this.videoMuted,
      customCountdownDays: customCountdownDays ?? this.customCountdownDays,
      hasCustomCountdown: hasCustomCountdown ?? this.hasCustomCountdown,
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
      'video_path': videoPath,
      'has_video': hasVideo ? 1 : 0,
      'video_muted': videoMuted ? 1 : 0,
      'custom_countdown_days': customCountdownDays,
      'has_custom_countdown': hasCustomCountdown ? 1 : 0,
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
      videoPath: map['video_path'],
      hasVideo: map['has_video'] == 1,
      videoMuted: map['video_muted'] == 1,
      customCountdownDays: map['custom_countdown_days'],
      hasCustomCountdown: map['has_custom_countdown'] == 1,
    );
  }
}
