# 批次3架构守护规则

## 🛡️ 架构守护的CI规则

为了保护批次3 GoalPage BLoC架构重构的成果，建议在CI/CD流程中添加以下检查规则：

### 1. 静态代码分析规则

#### 1.1 UI层依赖检查
```yaml
# 检查UI层是否有不受保护的DatabaseHelper直接调用
ui_database_dependency_check:
  script: |
    # 检查UI文件中的直接数据库调用
    if grep -r "_dbHelper\." lib/pages/ lib/views/ --include="*.dart" | grep -v "if.*\(goalCRUDWriteThrough\|dataLoadingViaBloc\|uiStateWriteThrough\)"; then
      echo "❌ 发现UI层有不受保护的DatabaseHelper直接调用"
      exit 1
    fi
    echo "✅ UI层DatabaseHelper依赖检查通过"
```

#### 1.2 BLoC事件使用检查
```yaml
# 确保UI层使用BLoC事件而不是直接数据库操作
bloc_event_usage_check:
  script: |
    # 检查是否使用了BLoC事件
    if ! grep -q "context.read<GoalBloc>().add(" lib/pages/goal_page.dart; then
      echo "❌ GoalPage未使用BLoC事件"
      exit 1
    fi
    echo "✅ BLoC事件使用检查通过"
```

#### 1.3 功能开关完整性检查
```yaml
# 检查功能开关的完整性
feature_toggle_check:
  script: |
    # 检查所有必需的功能开关
    toggles=("goalCRUDWriteThrough" "dataLoadingViaBloc" "uiStateWriteThrough")
    for toggle in "${toggles[@]}"; do
      if ! grep -q "$toggle" lib/utils/bloc_feature_toggles.dart; then
        echo "❌ 功能开关 $toggle 缺失"
        exit 1
      fi
    done
    echo "✅ 功能开关完整性检查通过"
```

### 2. 架构一致性检查

#### 2.1 数据流验证
```yaml
# 验证数据流的一致性：UI → BLoC → Repository → DB
data_flow_check:
  script: |
    # 检查GoalBloc是否使用Repository模式
    if ! grep -q "repository\." lib/bloc/goal/goal_bloc.dart; then
      echo "❌ GoalBloc未使用Repository模式"
      exit 1
    fi
    echo "✅ 数据流一致性检查通过"
```

#### 2.2 状态管理验证
```yaml
# 验证状态管理的单一数据源原则
state_management_check:
  script: |
    # 检查是否有BlocBuilder实现
    if ! grep -q "BlocBuilder<GoalBloc, GoalState>" lib/pages/goal_page.dart; then
      echo "❌ 缺少BlocBuilder实现"
      exit 1
    fi
    echo "✅ 状态管理检查通过"
```

### 3. 性能守护规则

#### 3.1 emit策略检查
```yaml
# 检查关键操作的emit策略
emit_strategy_check:
  script: |
    # 检查关键操作是否有性能优化注释
    operations=("ToggleGoalStatus" "SaveDate" "SaveImage")
    for op in "${operations[@]}"; do
      if ! grep -A5 "_on$op" lib/bloc/goal/goal_bloc.dart | grep -q "emit策略"; then
        echo "❌ $op 缺少emit策略说明"
        exit 1
      fi
    done
    echo "✅ emit策略检查通过"
```

#### 3.2 响应时间目标检查
```yaml
# 检查是否保持响应时间目标
response_time_check:
  script: |
    # 检查是否有响应时间目标注释
    if ! grep -q "响应时间<=100ms" lib/bloc/goal/goal_bloc.dart; then
      echo "❌ 缺少响应时间目标说明"
      exit 1
    fi
    echo "✅ 响应时间目标检查通过"
```

### 4. 质量保障规则

#### 4.1 错误处理检查
```yaml
# 检查错误处理的完整性
error_handling_check:
  script: |
    # 检查BLoC层错误处理
    if [ $(grep -c "try {" lib/bloc/goal/goal_bloc.dart) -lt 10 ]; then
      echo "❌ BLoC层错误处理不足"
      exit 1
    fi
    echo "✅ 错误处理检查通过"
```

#### 4.2 文档完整性检查
```yaml
# 检查关键文档是否存在
documentation_check:
  script: |
    docs=("batch3_completion_summary.md" "BATCH3_FINAL_COMPLETION_REPORT.md")
    for doc in "${docs[@]}"; do
      if [ ! -f "$doc" ]; then
        echo "❌ 文档 $doc 缺失"
        exit 1
      fi
    done
    echo "✅ 文档完整性检查通过"
```

### 5. 回归测试规则

#### 5.1 自动化验证脚本
```yaml
# 运行所有验证脚本
automated_verification:
  script: |
    scripts=("verify_phase2_implementation.dart" "verify_phase3_implementation.dart" 
             "verify_phase4_implementation.dart" "verify_phase5_implementation.dart")
    for script in "${scripts[@]}"; do
      if [ -f "$script" ]; then
        echo "运行 $script..."
        dart "$script" || exit 1
      fi
    done
    echo "✅ 自动化验证通过"
```

#### 5.2 功能回归测试
```yaml
# 运行功能回归测试
functional_regression:
  script: |
    if [ -f "functional_regression_test.dart" ]; then
      dart functional_regression_test.dart || exit 1
    fi
    echo "✅ 功能回归测试通过"
```

### 6. 部署前检查

#### 6.1 功能开关状态检查
```yaml
# 检查功能开关的默认状态
feature_toggle_default_check:
  script: |
    # 确保功能开关默认关闭（安全部署）
    if grep -q "= true" lib/utils/bloc_feature_toggles.dart; then
      echo "⚠️  警告：有功能开关默认开启，请确认是否安全"
    fi
    echo "✅ 功能开关状态检查完成"
```

#### 6.2 向后兼容性检查
```yaml
# 检查向后兼容性
backward_compatibility_check:
  script: |
    # 确保传统路径仍然存在
    if ! grep -q "_buildWithBlocListener" lib/pages/goal_page.dart; then
      echo "❌ 传统路径缺失，可能影响向后兼容性"
      exit 1
    fi
    echo "✅ 向后兼容性检查通过"
```

## 🚀 使用建议

### 集成到CI/CD流程

1. **Pre-commit hooks**: 在代码提交前运行基本检查
2. **Pull Request检查**: 在代码合并前运行完整验证
3. **部署前验证**: 在生产部署前运行所有检查
4. **定期审计**: 定期运行架构一致性检查

### 监控和告警

1. **性能监控**: 监控关键操作的响应时间
2. **错误率监控**: 监控BLoC错误状态的发生率
3. **架构偏离告警**: 当检测到架构违规时发送告警

### 维护建议

1. **定期更新规则**: 随着架构演进更新检查规则
2. **团队培训**: 确保团队了解架构守护规则
3. **文档维护**: 保持架构文档的及时更新

---

**注意**: 这些规则旨在保护批次3的架构成果，确保后续开发不会破坏已建立的BLoC架构模式。
