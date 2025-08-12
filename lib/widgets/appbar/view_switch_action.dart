import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_bloc.dart';
import 'package:linzaivision_primary/bloc/goal/goal_state.dart';
import 'package:linzaivision_primary/bloc/goal/goal_event.dart';

/// A minimal, testable AppBar action which switches viewMode via GoalBloc.
/// - No assets dependency (uses plain Icon).
/// - Relies only on GoalBloc state (GoalsLoaded) to decide color and next view.
class ViewSwitchAction extends StatelessWidget {
  const ViewSwitchAction({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GoalBloc, GoalState>(
      buildWhen: (prev, curr) {
        if (prev is GoalsLoaded && curr is GoalsLoaded) {
          return prev.viewMode != curr.viewMode;
        }
        return prev.runtimeType != curr.runtimeType;
      },
      builder: (context, state) {
        if (state is! GoalsLoaded) {
          return const SizedBox.shrink();
        }
        final color = state.viewMode == 0 ? Colors.white : Colors.black;
        return IconButton(
          icon: const Icon(Icons.swap_horiz),
          color: color,
          onPressed: () {
            final nextView = (state.viewMode + 1) % 3;
            context.read<GoalBloc>().add(ToggleViewMode(nextView));
          },
          tooltip: '切换视图',
        );
      },
    );
  }
}

