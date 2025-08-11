import 'ui_batch_updater.dart';
import 'i_ui_batch_updater.dart';

/// 测试专用：立即执行回调的“批处理器”实现
class ImmediateUIBatchUpdater implements IUIBatchUpdater {
  @override
  void addUpdate(UIUpdateItem item) {
    item.updateCallback?.call();
  }

  @override
  void addUpdates(List<UIUpdateItem> items) {
    for (final item in items) {
      item.updateCallback?.call();
    }
  }

  @override
  void flush() {
    // no-op
  }

  @override
  UIBatchUpdateStats getStats() {
    return const UIBatchUpdateStats(
      totalUpdates: 0,
      batchedUpdates: 0,
      skippedUpdates: 0,
      batchRate: 0,
      skipRate: 0,
      averageProcessingTime: Duration.zero,
      pendingUpdates: 0,
    );
  }

  @override
  void dispose() {
    // no-op
  }
}

