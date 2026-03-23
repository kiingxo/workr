import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/worker.dart';
import 'data/workr_backend_api.dart';

class BoardState {
  final List<Worker> workers;
  final Map<String, EmailInboxSnapshot> inboxByWorkerId;

  const BoardState({this.workers = const [], this.inboxByWorkerId = const {}});

  BoardState copyWith({
    List<Worker>? workers,
    Map<String, EmailInboxSnapshot>? inboxByWorkerId,
  }) {
    return BoardState(
      workers: workers ?? this.workers,
      inboxByWorkerId: inboxByWorkerId ?? this.inboxByWorkerId,
    );
  }
}

/// Holds all Workers on the board and updates their UI state.
///
/// MVP scope:
/// - Add Workers
/// - Update their positions on drag
/// - Simulate running/idle state for the "Run" button
class BoardController extends Notifier<BoardState> {
  StreamSubscription<WorkerStatusEvent>? _eventsSub;
  bool _bootstrapped = false;

  @override
  BoardState build() {
    if (!_bootstrapped) {
      _bootstrapped = true;
      unawaited(_bootstrap());
    }
    ref.onDispose(() {
      _eventsSub?.cancel();
      ref.read(workrBackendApiProvider).dispose();
    });
    return const BoardState();
  }

  Future<void> _bootstrap() async {
    try {
      await refreshWorkers();
      _subscribeToWorkerEvents();
    } catch (_) {
      // Keep the app usable even if backend is temporarily unavailable.
    }
  }

  Future<void> refreshWorkers() async {
    final api = ref.read(workrBackendApiProvider);
    final workers = await api.listWorkers();
    state = state.copyWith(workers: workers);
    unawaited(_refreshUnreadBadges(workers));
  }

  Future<void> deleteWorker({required String id}) async {
    final previous = state.workers;
    state = state.copyWith(
      workers: state.workers.where((w) => w.id != id).toList(growable: false),
      inboxByWorkerId: {
        for (final entry in state.inboxByWorkerId.entries)
          if (entry.key != id) entry.key: entry.value,
      },
    );
    try {
      await ref.read(workrBackendApiProvider).deleteWorker(id);
      await refreshWorkers();
    } catch (_) {
      state = state.copyWith(workers: previous);
    }
  }

  /// Adds a new Worker at a default offset.
  Future<void> addWorker({
    required String name,
    String? description,
    required AgentType type,
  }) async {
    final index = state.workers.length;

    // Small stagger so new cards don't land perfectly on top of each other.
    final double x = 40 + (index * 34).toDouble();
    final double y = 40 + (index * 30).toDouble();

    final worker = await ref
        .read(workrBackendApiProvider)
        .createWorker(
          name: name,
          description: description,
          type: type,
          x: x,
          y: y,
        );

    state = state.copyWith(workers: [worker, ...state.workers]);
  }

  void _subscribeToWorkerEvents() {
    if (_eventsSub != null) return;

    _eventsSub = ref
        .read(workrBackendApiProvider)
        .workerEvents()
        .listen(
          (event) {
            final worker = _workerById(event.workerId);
            final isRecurringAutoMode =
                (worker?.type == AgentType.email ||
                    worker?.type == AgentType.transitMaps) &&
                (worker?.autoRunEnabled ?? false);
            if (isRecurringAutoMode) {
              updateStatus(
                id: event.workerId,
                status: WorkerStatus.running,
                description: event.message ?? worker?.description,
              );
              return;
            }
            updateStatus(
              id: event.workerId,
              status: event.status,
              description: event.message,
            );
            if (worker?.type == AgentType.email &&
                event.status != WorkerStatus.running) {
              unawaited(refreshUnreadForWorker(event.workerId));
            }
          },
          onError: (_) async {
            await _eventsSub?.cancel();
            _eventsSub = null;
            await Future<void>.delayed(const Duration(seconds: 2));
            _subscribeToWorkerEvents();
          },
        );
  }

  /// Updates a Worker's position (x/y) persisted in state.
  void updatePosition({
    required String id,
    required double x,
    required double y,
  }) {
    state = state.copyWith(
      workers: state.workers
          .map((w) => w.id == id ? w.copyWith(x: x, y: y) : w)
          .toList(growable: false),
    );

    unawaited(
      ref.read(workrBackendApiProvider).updateWorker(id: id, x: x, y: y),
    );
  }

  /// Updates a Worker's status (running/idle/error).
  void updateStatus({
    required String id,
    required WorkerStatus status,
    String? description,
  }) {
    state = state.copyWith(
      workers: state.workers
          .map(
            (w) => w.id == id
                ? w.copyWith(
                    status: status,
                    description: description ?? w.description,
                  )
                : w,
          )
          .toList(growable: false),
    );
  }

  Future<void> runWorker({required String id}) async {
    final current = _workerById(id);
    if (current == null) return;
    if (current.type == AgentType.email ||
        current.type == AgentType.transitMaps) {
      await _setRecurringAutoRun(id, enabled: true);
      return;
    }
    if (current.status == WorkerStatus.running) return;

    updateStatus(id: id, status: WorkerStatus.running);
    await ref.read(workrBackendApiProvider).runWorker(id);
    unawaited(_pollWorkerResult(id));
  }

  Future<void> _pollWorkerResult(String id) async {
    final api = ref.read(workrBackendApiProvider);
    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      try {
        final result = await api.getWorkerExecutionResult(id);
        if (result.status == WorkerStatus.running) {
          continue;
        }
        final worker = _workerById(id);
        final isRecurringAutoMode =
            (worker?.type == AgentType.email ||
                worker?.type == AgentType.transitMaps) &&
            (worker?.autoRunEnabled ?? false);
        updateStatus(
          id: id,
          status: isRecurringAutoMode ? WorkerStatus.running : result.status,
          description: result.message,
        );
        if (worker?.type == AgentType.email) {
          unawaited(refreshUnreadForWorker(id));
        }
        return;
      } catch (_) {
        // Keep polling; SSE may still deliver the final state.
      }
    }
  }

  void stopWorker({required String id}) {
    final current = _workerById(id);
    if (current == null) return;

    if ((current.type == AgentType.email ||
            current.type == AgentType.transitMaps) &&
        current.autoRunEnabled) {
      unawaited(_setRecurringAutoRun(id, enabled: false));
      return;
    }
    if (current.status != WorkerStatus.running) return;

    updateStatus(
      id: id,
      status: WorkerStatus.idle,
      description: 'Stopped by user',
    );
  }

  Future<void> toggleWorker({required String id}) async {
    final current = _workerById(id);
    if (current == null) return;

    if (current.type == AgentType.research) {
      await runWorker(id: id);
      return;
    }

    if (current.type == AgentType.email ||
        current.type == AgentType.transitMaps) {
      if (current.autoRunEnabled) {
        await _setRecurringAutoRun(id, enabled: false);
      } else {
        await _setRecurringAutoRun(id, enabled: true);
      }
      return;
    }

    if (current.status == WorkerStatus.running) {
      stopWorker(id: id);
    } else {
      await runWorker(id: id);
    }
  }

  Worker? _workerById(String id) {
    for (final worker in state.workers) {
      if (worker.id == id) return worker;
    }
    return null;
  }

  Future<void> _setRecurringAutoRun(String id, {required bool enabled}) async {
    final previous = _workerById(id);
    if (previous == null) return;
    final isTransit = previous.type == AgentType.transitMaps;

    updateWorkerState(
      id: id,
      status: enabled ? WorkerStatus.running : WorkerStatus.idle,
      autoRunEnabled: enabled,
      description: enabled
          ? (isTransit
                ? 'Watching bus times in the background'
                : 'Auto-checking Gmail every hour')
          : (isTransit ? 'Transit watch stopped' : 'Email auto-check stopped'),
    );

    try {
      final updated = await ref
          .read(workrBackendApiProvider)
          .setWorkerAutoRun(
            id: id,
            enabled: enabled,
            intervalMinutes: isTransit ? 2 : 60,
          );
      updateWorkerState(
        id: id,
        status: updated.status,
        autoRunEnabled: updated.autoRunEnabled,
        description: updated.description,
      );
      if (enabled) {
        unawaited(_pollWorkerResult(id));
      }
    } catch (_) {
      updateWorkerState(
        id: id,
        status: previous.status,
        autoRunEnabled: previous.autoRunEnabled,
        description: previous.description,
      );
    }
  }

  void updateWorkerState({
    required String id,
    required WorkerStatus status,
    required bool autoRunEnabled,
    String? description,
  }) {
    state = state.copyWith(
      workers: state.workers
          .map(
            (w) => w.id == id
                ? w.copyWith(
                    status: status,
                    autoRunEnabled: autoRunEnabled,
                    description: description ?? w.description,
                  )
                : w,
          )
          .toList(growable: false),
    );
  }

  Future<void> refreshUnreadForWorker(String id, {int limit = 20}) async {
    final worker = _workerById(id);
    if (worker == null || worker.type != AgentType.email) return;
    try {
      final inbox = await ref
          .read(workrBackendApiProvider)
          .getUnreadEmails(workerId: id, limit: limit);
      state = state.copyWith(
        inboxByWorkerId: {...state.inboxByWorkerId, id: inbox},
      );
    } catch (_) {
      // Ignore transient backend/google errors; badge updates on next poll/run.
    }
  }

  Future<void> _refreshUnreadBadges(List<Worker> workers) async {
    final emailWorkers = workers.where((w) => w.type == AgentType.email);
    for (final worker in emailWorkers) {
      await refreshUnreadForWorker(worker.id, limit: 10);
    }
  }
}

final boardControllerProvider = NotifierProvider<BoardController, BoardState>(
  BoardController.new,
);
