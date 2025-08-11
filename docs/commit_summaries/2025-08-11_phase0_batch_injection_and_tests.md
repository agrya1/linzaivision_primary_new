# Phase 0 GoalPage Verification – Injectable UI Batcher + Focused Tests

## Summary
This change unblocks reliable Phase 0 verification for GoalPage by decoupling UI batching from GoalBloc and providing a test-only immediate batcher. It eliminates flakiness caused by frame-scheduled emissions during tests, while keeping production performance optimizations intact.

## Key Changes
- Introduced IUIBatchUpdater (interface) to abstract UI batching behavior
- Implemented ImmediateUIBatchUpdater for tests (executes callbacks immediately)
- Made existing UIBatchUpdater implement IUIBatchUpdater
- GoalBloc now accepts an optional batchUpdater and a disableBatching flag
  - Production: default UIBatchUpdater (batched)
  - Tests: ImmediateUIBatchUpdater + disableBatching=true to emit synchronously
- Added focused integration tests for Phase 0: test/integration/goal_page_phase0_fix_test.dart
  - Switched from widget binding to pure BLoC behavior tests
  - Use stream waits with timeouts to avoid hanging

## Motivation
Previous tests hung because GoalsLoaded was emitted via a deferred UI batch, which relies on frame scheduling. In a test environment, this dispatch could be missed or delayed, causing persistent GoalLoading states and timeouts. By injecting an immediate batcher in tests, emissions become deterministic and observable without frame pumping.

## Impact
- Production: No functional change; batching remains optimized via UIBatchUpdater
- Testing: Stable, fast, and deterministic BLoC state assertions without widget pumps

## Files Touched
- lib/bloc/goal/goal_bloc.dart
- lib/bloc/transaction/i_ui_batch_updater.dart
- lib/bloc/transaction/immediate_ui_batch_updater.dart
- lib/bloc/transaction/ui_batch_updater.dart
- test/integration/goal_page_phase0_fix_test.dart

## How to Run
- Single file: `flutter test test/integration/goal_page_phase0_fix_test.dart -r expanded`
- All tests: `flutter test -r expanded`

## Next Steps
- Add Phase 1 (read-only refactor) focused tests
- Consider a logger-based debug layer for BLoC transitions (behind a flag)
- Ensure ImmediateUIBatchUpdater is only used in tests (e.g., via test-only DI wiring)

