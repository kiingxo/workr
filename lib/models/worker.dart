enum WorkerStatus {
  running,
  idle,
  error,
}

/// A "Worker" on the board.
///
/// Note: The MVP intentionally avoids any AI/backend logic; this is purely UI state.
class Worker {
  final String id;
  final String name;
  final String description;
  final WorkerStatus status;
  final double x;
  final double y;

  const Worker({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.x,
    required this.y,
  });

  Worker copyWith({
    String? id,
    String? name,
    String? description,
    WorkerStatus? status,
    double? x,
    double? y,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

