import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/worker.dart';
import '../board/board_controller.dart';
import '../board/data/workr_backend_api.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _loading = true;
  bool _running = false;
  List<WorkerTask> _tasks = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      await ref.read(boardControllerProvider.notifier).refreshWorkers();
      final tasks = await ref.read(workrBackendApiProvider).listTasks();
      if (!mounted) return;
      setState(() => _tasks = tasks);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $err')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assignTask(WorkerTask task, String workerId) async {
    try {
      await ref
          .read(workrBackendApiProvider)
          .assignTask(taskId: task.id, workerId: workerId);
      await _refresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Assign failed: $err')));
    }
  }

  Future<void> _runTask(WorkerTask task) async {
    setState(() => _running = true);
    try {
      await ref.read(workrBackendApiProvider).runTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task queued')));
      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _refresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Run failed: $err')));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _markDone(WorkerTask task) async {
    try {
      await ref
          .read(workrBackendApiProvider)
          .updateTaskStatus(taskId: task.id, status: 'done');
      await _refresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Status update failed: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final workers = ref.watch(boardControllerProvider).workers;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tasks',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_tasks.length} task(s) from research cards',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks yet.\nCreate tasks from your Research worker.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      itemCount: _tasks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return _TaskCard(
                          task: task,
                          workers: workers,
                          disabled: _running,
                          onAssign: (workerId) => _assignTask(task, workerId),
                          onRun: task.assignedWorkerId == null
                              ? null
                              : () => _runTask(task),
                          onMarkDone: task.status == 'done'
                              ? null
                              : () => _markDone(task),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.workers,
    required this.disabled,
    required this.onAssign,
    required this.onRun,
    required this.onMarkDone,
  });

  final WorkerTask task;
  final List<Worker> workers;
  final bool disabled;
  final ValueChanged<String> onAssign;
  final VoidCallback? onRun;
  final VoidCallback? onMarkDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final statusColor = switch (task.status) {
      'done' => Colors.green,
      'error' => Colors.red,
      'in_progress' => Colors.orange,
      _ => colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusBadge(label: task.status, color: statusColor),
            ],
          ),
          if (task.description.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(task.description, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedWorkerId(task, workers),
                  hint: const Text('Assign worker'),
                  isExpanded: true,
                  items: workers
                      .map(
                        (worker) => DropdownMenuItem<String>(
                          value: worker.id,
                          child: Text(
                            worker.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: disabled
                      ? null
                      : (value) {
                          if (value == null) return;
                          onAssign(value);
                        },
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: disabled ? null : onRun,
                icon: const Icon(Icons.play_arrow_rounded, size: 16),
                label: const Text('Run'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Priority: ${task.priority}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: disabled ? null : onMarkDone,
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Mark done'),
              ),
            ],
          ),
          if (task.lastResultSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                task.lastResultSummary,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String? _selectedWorkerId(WorkerTask task, List<Worker> workers) {
  final id = task.assignedWorkerId;
  if (id == null || id.isEmpty) return null;
  for (final worker in workers) {
    if (worker.id == id) return id;
  }
  return null;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
