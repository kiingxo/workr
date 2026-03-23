import 'package:flutter/material.dart';

enum WorkerStatus {
  running,
  idle,
  error,
}

enum AgentType {
  email,
  socialContent,
  financeOps,
  research,
  taskWorkflow,
}

extension AgentTypeX on AgentType {
  String get displayName {
    return switch (this) {
      AgentType.email => 'Email Automation',
      AgentType.socialContent => 'Social & Content',
      AgentType.financeOps => 'Finance & Ops',
      AgentType.research => 'Research & Actions',
      AgentType.taskWorkflow => 'Task Automation',
    };
  }

  String get description {
    return switch (this) {
      AgentType.email => 'Reads emails, summarizes, files, drafts replies',
      AgentType.socialContent => 'Generates, schedules, and posts content',
      AgentType.financeOps => 'Tracks spending, alerts, and automates tasks',
      AgentType.research => 'Pulls data and exports structured results',
      AgentType.taskWorkflow => 'Connects apps and executes workflows',
    };
  }

  IconData get icon {
    return switch (this) {
      AgentType.email => Icons.mail_rounded,
      AgentType.socialContent => Icons.share_rounded,
      AgentType.financeOps => Icons.wallet_rounded,
      AgentType.research => Icons.search_rounded,
      AgentType.taskWorkflow => Icons.checklist_rounded,
    };
  }
}

/// A "Worker" on the board.
///
/// Note: The MVP intentionally avoids any AI/backend logic; this is purely UI state.
class Worker {
  final String id;
  final String name;
  final String description;
  final AgentType type;
  final WorkerStatus status;
  final double x;
  final double y;

  const Worker({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.x,
    required this.y,
  });

  Worker copyWith({
    String? id,
    String? name,
    String? description,
    AgentType? type,
    WorkerStatus? status,
    double? x,
    double? y,
  }) {
    return Worker(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }
}

