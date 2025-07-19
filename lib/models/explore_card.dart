/// 探索卡片数据模型
class ExploreCard {
  final String id;
  final String title;
  final String description;
  final String imagePath;
  final String? videoPath;
  final bool hasVideo;
  final DateTime createdTime;
  final String? category;
  final List<String> tags;
  
  const ExploreCard({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    this.videoPath,
    this.hasVideo = false,
    required this.createdTime,
    this.category,
    this.tags = const [],
  });
  
  /// 从JSON创建探索卡片
  factory ExploreCard.fromJson(Map<String, dynamic> json) {
    return ExploreCard(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String,
      videoPath: json['videoPath'] as String?,
      hasVideo: json['hasVideo'] as bool? ?? false,
      createdTime: DateTime.parse(json['createdTime'] as String),
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'videoPath': videoPath,
      'hasVideo': hasVideo,
      'createdTime': createdTime.toIso8601String(),
      'category': category,
      'tags': tags,
    };
  }
  
  /// 复制探索卡片
  ExploreCard copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    String? videoPath,
    bool? hasVideo,
    DateTime? createdTime,
    String? category,
    List<String>? tags,
  }) {
    return ExploreCard(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      videoPath: videoPath ?? this.videoPath,
      hasVideo: hasVideo ?? this.hasVideo,
      createdTime: createdTime ?? this.createdTime,
      category: category ?? this.category,
      tags: tags ?? this.tags,
    );
  }
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExploreCard && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
  
  @override
  String toString() {
    return 'ExploreCard{id: $id, title: $title, description: $description}';
  }
} 