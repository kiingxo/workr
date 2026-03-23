import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/worker.dart';

class BoardState {
  final List<Worker> workers;

  const BoardState({this.workers = const []});

  BoardState copyWith({List<Worker>? workers}) {
    return BoardState(workers: workers ?? this.workers);
  }
}

/// Holds all Workers on the board and updates their UI state.
///
/// MVP scope:
/// - Add Workers
/// - Update their positions on drag
/// - Simulate running/idle state for the "Run" button
class BoardController extends Notifier<BoardState> {
  @override
  BoardState build() => const BoardState();

  void deleteWorker({required String id}) {
    state = state.copyWith(
      workers: state.workers.where((w) => w.id != id).toList(growable: false),
    );
  }

  /// Adds a new Worker at a default offset.
  void addWorker({
    required String name,
    String? description,
  }) {
    final index = state.workers.length;
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    // Small stagger so new cards don't land perfectly on top of each other.
    final double x = 40 + (index * 34).toDouble();
    final double y = 40 + (index * 30).toDouble();

    final worker = Worker(
      id: id,
      name: name,
      description: description ?? 'Goal: run this worker',
      status: WorkerStatus.idle,
      x: x,
      y: y,
    );

    state = state.copyWith(workers: [...state.workers, worker]);
  }

  /// Updates a Worker's position (x/y) persisted in state.
  void updatePosition({required String id, required double x, required double y}) {
    state = state.copyWith(
      workers: state.workers
          .map((w) => w.id == id ? w.copyWith(x: x, y: y) : w)
          .toList(growable: false),
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
                ? w.copyWith(status: status, description: description ?? w.description)
                : w,
          )
          .toList(growable: false),
    );
  }

  Future<void> runWorker({required String id}) async {
    final matchingWorkers = state.workers.where((w) => w.id == id);
    final current = matchingWorkers.isEmpty ? null : matchingWorkers.first;
    if (current == null) return;
    if (current.status == WorkerStatus.running) return;

    updateStatus(id: id, status: WorkerStatus.running);

    // Simulate "AI worker" runtime without any backend logic.
    await Future<void>.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    updateStatus(
      id: id,
      status: WorkerStatus.idle,
      description: 'Last output: completed at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
    );
  }
}

final boardControllerProvider =
    NotifierProvider<BoardController, BoardState>(BoardController.new);

