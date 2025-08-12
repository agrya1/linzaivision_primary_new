# 标准化BLoC迁移模板

## 🎯 基于showTitle成功经验的可复用迁移模板

### 📋 迁移步骤模板

#### 步骤A：触发改造与只读同步
```dart
// 1. 添加专用开关
bool _{feature}DisplayWriteThrough = false;
bool get {feature}DisplayWriteThrough => _{feature}DisplayWriteThrough;

// 2. 修改触发方法（保留本地变量）
void _toggle{Feature}() {
  if (_featureToggles.{feature}DisplayWriteThrough) {
    // 新路径：Guard检查 + BLoC状态取值 + 事件驱动
    final currentState = context.read<GoalBloc>().state;
    if (currentState is GoalsLoaded) {
      // 性能监控开始
      UIStatePerformanceMonitor.startMeasure('{feature}_toggle');
      UIStatePerformanceMonitor.recordEvent('{feature}_toggle');

      // 从BLoC状态取反，确保一致性
      context.read<GoalBloc>().add(Toggle{Feature}Display(!currentState.{feature}));

      print('【批次1灰度】{feature}切换: ${!currentState.{feature}}');
    } else {
      // Guard保护：非GoalsLoaded状态禁用操作
      UIStatePerformanceMonitor.recordError('{feature}_toggle');
      print('【批次1灰度】{feature}切换被禁用：当前状态${currentState.runtimeType}');
    }
  } else {
    // 传统路径：完全保持不变
    setState(() {
      _{feature} = !_{feature};
    });
    context.read<GoalBloc>().add(Toggle{Feature}Display(_{feature}));
  }
}

// 3. 在syncStateFromBloc中添加只读同步
void syncStateFromBloc(GoalsLoaded state) {
  // 现有同步逻辑保持不变...

  // 新增：{feature}只读同步（仅在灰度模式下）
  if (_featureToggles.{feature}DisplayWriteThrough) {
    _{feature} = state.{feature};  // 只读覆盖，确保一致性
    print('【批次1灰度】{feature}只读同步: $_{feature}');
  }
}
```

#### 步骤B：强制渲染分支统一
```dart
// 1. 统一BLoC事件处理器
void _onToggle{Feature}Display(Toggle{Feature}Display event, Emitter<GoalState> emit) {
  if (state is GoalsLoaded) {
    final currentState = state as GoalsLoaded;

    // 性能监控结束
    UIStatePerformanceMonitor.endMeasure('{feature}_toggle');

    // 统一处理：immediate优先级 + 立即flush
    _smartEmit(
        currentState.copyWith({feature}: event.{feature}),
        emit,
        priority: UIUpdatePriority.immediate);
    _uiBatchUpdater.flush();

    print('【批次1灰度】BLoC处理Toggle{Feature}Display: ${event.{feature}}');
  }
}

// 2. UI组件条件渲染
{feature}: _featureToggles.{feature}DisplayWriteThrough 
    ? (context.read<GoalBloc>().state is GoalsLoaded 
        ? (context.read<GoalBloc>().state as GoalsLoaded).{feature} 
        : true)
    : _{feature},

// 3. 事件回调统一
onToggle{Feature}: _toggle{Feature},
```

### 🛡️ 护栏机制模板

#### 1. Guard检查模板
```dart
// 状态检查
if (currentState is! GoalsLoaded) {
  UIStatePerformanceMonitor.recordError('{feature}_toggle');
  print('【批次1灰度】{feature}切换被禁用：当前状态${currentState.runtimeType}');
  return;
}
```

#### 2. 开关控制模板
```dart
// 开关配置
bool _{feature}DisplayWriteThrough = false;

// 开关启用
await _featureToggles.setFeatureEnabled('{feature}DisplayWriteThrough', true);

// 紧急回滚
await _featureToggles.setFeatureEnabled('{feature}DisplayWriteThrough', false);
```

#### 3. 性能监控模板
```dart
// 监控开始
UIStatePerformanceMonitor.startMeasure('{feature}_toggle');
UIStatePerformanceMonitor.recordEvent('{feature}_toggle');

// 监控结束
UIStatePerformanceMonitor.endMeasure('{feature}_toggle');

// 错误记录
UIStatePerformanceMonitor.recordError('{feature}_toggle');
```

### 📊 验证策略模板

#### L1验证：基础组件
```dart
print('【L1验证】{Feature}Page.initState 开始');
print('【L1验证】_featureToggles: ${_featureToggles.runtimeType}');
print('【L1验证】context 可用: ${context != null}');
```

#### L2验证：开关系统
```dart
print('【L2验证】{feature}DisplayWriteThrough 初始: ${_featureToggles.{feature}DisplayWriteThrough}');
print('【L2验证】开关读取测试成功: ${_featureToggles.isFeatureEnabled('{feature}DisplayWriteThrough')}');
```

#### L3验证：BLoC系统
```dart
final bloc = context.read<GoalBloc>();
if (bloc.state is GoalsLoaded) {
  final state = bloc.state as GoalsLoaded;
  print('【L3验证】{feature} BLoC值: ${state.{feature}}');
  print('【L3验证】本地_{feature}值: $_{feature}');
}
```

#### L4验证：事件处理
```dart
print('【L4验证】_toggle{Feature} 被调用');
print('【L4验证】当前{feature}: ${currentState.{feature}}');
print('【L4验证】目标{feature}: ${!currentState.{feature}}');
print('【L4验证】✅ Toggle{Feature}Display事件已发送');
```

### 🎯 成功标准模板

#### 功能标准
- ✅ {feature}切换立即生效（< 50ms）
- ✅ 状态在页面重建后保持
- ✅ 非GoalsLoaded状态时按钮正确禁用
- ✅ BLoC状态与本地变量保持一致

#### 性能标准
- ✅ 平均响应时间 < 50ms
- ✅ 最大响应时间 < 100ms
- ✅ 错误率 < 1%
- ✅ 内存使用增长 < 2%

#### 质量标准
- ✅ 代码模式清晰，可复制到其他功能
- ✅ 护栏机制有效，异常时自动保护
- ✅ 监控指标完整，便于问题诊断
- ✅ 回滚机制验证通过

### 🧪 完善的验证策略

#### 每个扩展的验证要求
基于showTitle成功经验，每个新功能迁移都必须通过以下验证：

##### 1. 复用showTitle的测试用例模板
```dart
// 基础功能测试
- [ ] {feature}切换立即生效
- [ ] 状态在页面重建后保持
- [ ] 非GoalsLoaded状态时按钮正确禁用
- [ ] BLoC状态与本地变量保持一致

// 边界情况测试
- [ ] 快速连续点击处理
- [ ] 数据加载中的切换行为
- [ ] 网络异常时的切换行为
- [ ] 内存压力下的稳定性
```

##### 2. 验证与已迁移功能的兼容性
```dart
// 协同工作测试
- [ ] 与showTitle同时切换正常
- [ ] 与其他已迁移功能无冲突
- [ ] 状态同步机制协调工作
- [ ] 性能监控数据正常

// 交互测试
- [ ] 多个显示选项连续切换
- [ ] 视图切换时状态保持
- [ ] 应用重启后状态恢复
```

##### 3. 确保性能指标不下降
```dart
// 性能基准对比
- [ ] 响应时间不超过showTitle基准
- [ ] 内存使用增长在可接受范围
- [ ] CPU使用率无明显增加
- [ ] 电池消耗无异常增长

// 性能监控验证
- [ ] UIStatePerformanceMonitor正常工作
- [ ] 批处理系统稳定运行
- [ ] 强制直接发射机制有效
```

##### 4. 验证回滚机制有效
```dart
// 回滚测试
- [ ] 开关关闭后立即回退到传统模式
- [ ] 回滚过程无数据丢失
- [ ] 回滚后功能完全正常
- [ ] 可以重新启用灰度模式

// 紧急回滚验证
- [ ] 一键回滚机制测试
- [ ] 批量回滚所有功能
- [ ] 回滚后系统稳定性
```

### 🎯 质量门禁标准

#### 每个功能迁移的通过标准
```dart
// 必须通过的检查项
✅ 编译无错误和警告
✅ 所有L1-L4验证层通过
✅ 功能测试100%通过
✅ 性能指标达到或超过基准
✅ 兼容性测试无冲突
✅ 回滚机制验证通过
✅ 代码审查通过
✅ 文档更新完成
```

#### 批次整体验证标准
```dart
// 批次1完成的标准
✅ 所有UI状态写操作BLoC化
✅ 所有显示选项协同工作
✅ 整体性能无下降
✅ 用户体验无感知变化
✅ 系统稳定性良好
✅ 监控指标正常
✅ 回滚机制完整有效
```

### 🚀 应用指南

#### 1. 变量替换规则
- `{feature}` → 具体功能名（如：description, time, countdown）
- `{Feature}` → 首字母大写的功能名（如：Description, Time, Countdown）

#### 2. 实施顺序
1. 复制模板代码
2. 执行变量替换
3. 添加功能特定逻辑
4. 执行分层验证
5. 进行兼容性测试
6. 执行性能验证
7. 验证回滚机制
8. 进行全面测试

#### 3. 质量检查清单
- [ ] 编译无错误
- [ ] 所有验证层通过
- [ ] 性能指标达标
- [ ] 兼容性测试通过
- [ ] 回滚机制有效
- [ ] 文档更新完成

这个模板基于showTitle的成功经验，已经过实战验证，包含了完整的验证策略，可以确保每个功能迁移的质量和稳定性。
