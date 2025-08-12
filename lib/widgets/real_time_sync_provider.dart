import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/real_time_sync_service.dart';
import '../bloc/shared/shared_state_bloc.dart';
import '../bloc/goal/goal_bloc.dart';
import '../bloc/explore/explore_bloc.dart';

/// 实时同步提供者组件
///
/// 负责初始化和管理实时同步服务
class RealTimeSyncProvider extends StatefulWidget {
  final Widget child;
  final bool enableRealTimeSync;
  final VoidCallback? onSyncInitialized;
  final Function(String error)? onSyncError;

  const RealTimeSyncProvider({
    Key? key,
    required this.child,
    this.enableRealTimeSync = true,
    this.onSyncInitialized,
    this.onSyncError,
  }) : super(key: key);

  @override
  State<RealTimeSyncProvider> createState() => _RealTimeSyncProviderState();
}

class _RealTimeSyncProviderState extends State<RealTimeSyncProvider> {
  late RealTimeSyncService _syncService;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _syncService = RealTimeSyncService.instance;

    // 延迟初始化，确保BLoC已经准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSync();
    });
  }

  void _initializeSync() {
    try {
      final sharedStateBloc = context.read<SharedStateBloc>();
      final goalBloc = context.read<GoalBloc>();
      final exploreBloc = context.read<ExploreBloc>();

      _syncService.initialize(
        sharedStateBloc: sharedStateBloc,
        goalBloc: goalBloc,
        exploreBloc: exploreBloc,
      );

      _syncService.setRealTimeSyncEnabled(widget.enableRealTimeSync);

      setState(() {
        _isInitialized = true;
      });

      widget.onSyncInitialized?.call();

      if (mounted) {
        print('[RealTimeSyncProvider] 实时同步服务初始化完成');
      }
    } catch (e) {
      widget.onSyncError?.call('实时同步初始化失败: $e');
      print('[RealTimeSyncProvider] 初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _syncService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// 实时同步状态监控组件
class RealTimeSyncMonitor extends StatefulWidget {
  final Widget child;
  final bool showDebugInfo;
  final Duration updateInterval;

  const RealTimeSyncMonitor({
    Key? key,
    required this.child,
    this.showDebugInfo = false,
    this.updateInterval = const Duration(seconds: 1),
  }) : super(key: key);

  @override
  State<RealTimeSyncMonitor> createState() => _RealTimeSyncMonitorState();
}

class _RealTimeSyncMonitorState extends State<RealTimeSyncMonitor> {
  late RealTimeSyncService _syncService;
  SyncStatus? _syncStatus;
  Map<String, dynamic>? _performanceStats;

  @override
  void initState() {
    super.initState();
    _syncService = RealTimeSyncService.instance;

    if (widget.showDebugInfo) {
      _startMonitoring();
    }
  }

  void _startMonitoring() {
    Timer.periodic(widget.updateInterval, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _syncStatus = _syncService.getSyncStatus();
        _performanceStats = _syncService.getPerformanceStats();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showDebugInfo && _syncStatus != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 10,
            child: _buildDebugInfo(),
          ),
      ],
    );
  }

  Widget _buildDebugInfo() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '实时同步状态',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          _buildStatusItem(
              '状态', _syncStatus!.isRealTimeSyncEnabled ? '启用' : '禁用'),
          _buildStatusItem('队列', '${_syncStatus!.queueSize}'),
          _buildStatusItem('错误', '${_syncStatus!.consecutiveErrorCount}'),
          _buildStatusItem('操作', '${_syncStatus!.totalOperations}'),
          _buildStatusItem(
              '延迟', '${_syncStatus!.averageLatency.inMilliseconds}ms'),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

/// 实时同步控制面板
class RealTimeSyncControlPanel extends StatefulWidget {
  const RealTimeSyncControlPanel({Key? key}) : super(key: key);

  @override
  State<RealTimeSyncControlPanel> createState() =>
      _RealTimeSyncControlPanelState();
}

class _RealTimeSyncControlPanelState extends State<RealTimeSyncControlPanel> {
  late RealTimeSyncService _syncService;
  SyncStatus? _syncStatus;
  Map<String, dynamic>? _performanceStats;

  @override
  void initState() {
    super.initState();
    _syncService = RealTimeSyncService.instance;
    _updateStatus();
  }

  void _updateStatus() {
    setState(() {
      _syncStatus = _syncService.getSyncStatus();
      _performanceStats = _syncService.getPerformanceStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '实时同步控制',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _updateStatus,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_syncStatus != null) ...[
              _buildStatusSection(),
              const SizedBox(height: 16),
              _buildControlSection(),
              const SizedBox(height: 16),
              _buildPerformanceSection(),
            ] else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '状态信息',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        _buildInfoRow('初始化状态', _syncStatus!.isInitialized ? '已初始化' : '未初始化'),
        _buildInfoRow('实时同步', _syncStatus!.isRealTimeSyncEnabled ? '启用' : '禁用'),
        _buildInfoRow('队列大小', '${_syncStatus!.queueSize}'),
        _buildInfoRow('连续错误', '${_syncStatus!.consecutiveErrorCount}'),
        _buildInfoRow('总操作数', '${_syncStatus!.totalOperations}'),
        _buildInfoRow(
            '平均延迟', '${_syncStatus!.averageLatency.inMilliseconds}ms'),
        if (_syncStatus!.lastSyncTime != null)
          _buildInfoRow('最后同步', _formatDateTime(_syncStatus!.lastSyncTime!)),
      ],
    );
  }

  Widget _buildControlSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '控制操作',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () {
                _syncService.setRealTimeSyncEnabled(
                    !_syncStatus!.isRealTimeSyncEnabled);
                _updateStatus();
              },
              child: Text(_syncStatus!.isRealTimeSyncEnabled ? '禁用同步' : '启用同步'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                // 触发强制同步
                context.read<SharedStateBloc>().add(const RequestDataRefresh(
                      requestingPage: 'control_panel',
                      dataTypes: ['all'],
                    ));
                _updateStatus();
              },
              child: const Text('强制同步'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPerformanceSection() {
    if (_performanceStats == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '性能统计',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._performanceStats!.entries
            .where((e) => e.value is Map)
            .map((e) =>
                _buildPerformanceItem(e.key, e.value as Map<String, dynamic>))
            .toList(),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPerformanceItem(String operation, Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(operation),
          Text(
            '${stats['count']}次 / ${stats['avgTime']?.toStringAsFixed(1)}ms',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}
