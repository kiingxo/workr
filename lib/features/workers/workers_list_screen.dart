import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../board/board_controller.dart';
import '../board/board_screen.dart' show WorkerDetailScreen;
import '../../models/worker.dart';

class WorkersListScreen extends ConsumerWidget {
  const WorkersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardControllerProvider);
    final boardController = ref.read(boardControllerProvider.notifier);

    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workers',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${boardState.workers.length} AI workers on your board',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(160),
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: boardState.workers.length,
                separatorBuilder: (context, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final worker = boardState.workers[index];
                  return _WorkerListTile(
                    worker: worker,
                    onOpen: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkerDetailScreen(
                            workerId: worker.id,
                            workerName: worker.name,
                          ),
                        ),
                      );
                    },
                    onRun: () async {
                      await boardController.runWorker(id: worker.id);
                    },
                    onDelete: () {
                      showDialog<void>(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Delete worker?'),
                            content: Text('Delete "${worker.name}"?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  boardController.deleteWorker(id: worker.id);
                                },
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // Quick add (same flow as the canvas's + button).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Worker'),
                  onPressed: () async {
                    final result = await showDialog<_CreateWorkerDialogResult>(
                      context: context,
                      builder: (context) => const _CreateWorkerDialog(),
                    );
                    if (result == null) return;

                    boardController.addWorker(
                      name: result.name,
                      description: result.goal,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerListTile extends StatelessWidget {
  final Worker worker;
  final VoidCallback onOpen;
  final VoidCallback onRun;
  final VoidCallback onDelete;

  const _WorkerListTile({
    required this.worker,
    required this.onOpen,
    required this.onRun,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusColor = switch (worker.status) {
      WorkerStatus.running => Colors.green,
      WorkerStatus.idle => Colors.grey,
      WorkerStatus.error => Colors.red,
    };

    return Material(
      color: theme.colorScheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _AiFaceAvatar(
                workerId: worker.id,
                status: worker.status,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatusPill(
                      emoji: switch (worker.status) {
                        WorkerStatus.running => '🟢',
                        WorkerStatus.idle => '⚪',
                        WorkerStatus.error => '🔴',
                      },
                      text: switch (worker.status) {
                        WorkerStatus.running => 'Running',
                        WorkerStatus.idle => 'Idle',
                        WorkerStatus.error => 'Error',
                      },
                      color: statusColor,
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    onPressed: onRun,
                    tooltip: 'Run',
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;

  const _StatusPill({
    required this.emoji,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.13 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withAlpha((0.45 * 255).round()),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _AiFaceAvatar extends StatelessWidget {
  final String workerId;
  final WorkerStatus status;

  const _AiFaceAvatar({
    required this.workerId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final hash = workerId.hashCode;
    final hue = (hash % 360 + 360) % 360;
    final glow = status == WorkerStatus.running;
    final faceColor = HSVColor.fromAHSV(
      1,
      hue.toDouble(),
      0.75,
      status == WorkerStatus.running ? 0.95 : 0.75,
    ).toColor();

    final eye = (hash % 2 == 0) ? '•' : '◦';
    final mouthType = hash % 3;
    final mouth = switch (mouthType) {
      0 => 'ᴗ',
      1 => '﹏',
      _ => '︶',
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: faceColor,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: faceColor.withAlpha((0.35 * 255).round()),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
        ],
        border: Border.all(
          color: faceColor.withAlpha((0.35 * 255).round()),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          '$eye$eye\n$mouth',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 0.95,
              ),
        ),
      ),
    );
  }
}

class _CreateWorkerDialogResult {
  final String name;
  final String goal;

  _CreateWorkerDialogResult({
    required this.name,
    required this.goal,
  });
}

class _CreateWorkerDialog extends StatefulWidget {
  const _CreateWorkerDialog();

  @override
  State<_CreateWorkerDialog> createState() => _CreateWorkerDialogState();
}

class _CreateWorkerDialogState extends State<_CreateWorkerDialog> {
  final _nameController = TextEditingController();
  final _goalController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Worker'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Worker name',
                hintText: 'e.g. Marketing Helper',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _goalController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Goal',
                hintText: 'e.g. Draft 5 ad headlines daily',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final goal = _goalController.text.trim();
            Navigator.of(context).pop(
              _CreateWorkerDialogResult(
                name: name.isEmpty ? 'New Worker' : name,
                goal: goal.isEmpty ? 'Goal: run this worker' : goal,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

