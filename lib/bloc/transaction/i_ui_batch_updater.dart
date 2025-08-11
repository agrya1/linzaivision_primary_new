import 'ui_batch_updater.dart';

/// 抽象 UI 批量更新器，便于在测试中注入立即执行实现
abstract class IUIBatchUpdater {
  void addUpdate(UIUpdateItem item);
  void addUpdates(List<UIUpdateItem> items);
  void flush();
  UIBatchUpdateStats getStats();
  void dispose();
}

