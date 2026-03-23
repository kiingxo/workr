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
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workers',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${boardState.workers.length} AI workers on your board',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                      type: result.type,
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
    final statusColor = switch (worker.status) {
      WorkerStatus.running => Colors.green,
      WorkerStatus.idle => Colors.grey,
      WorkerStatus.error => Colors.red,
    };

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.black.withOpacity(0.06), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _AiFaceAvatar(workerId: worker.id, status: worker.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            worker.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black,
                                ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          worker.type.icon,
                          size: 16,
                          color: Colors.black.withOpacity(0.6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w400,
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
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: Colors.black.withOpacity(0.6),
                    ),
                    onPressed: onRun,
                    tooltip: 'Run',
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red.withOpacity(0.6),
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.2), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
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

  const _AiFaceAvatar({required this.workerId, required this.status});

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
  final AgentType type;

  _CreateWorkerDialogResult({
    required this.name,
    required this.goal,
    required this.type,
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
  AgentType? _selectedType;

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = AgentType.values;

    return AlertDialog(
      title: const Text('Create AI Worker'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 340,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Agent Type',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final type = types[index];
                    final isSelected = _selectedType == type;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.black
                                : Colors.black.withOpacity(0.15),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type.icon,
                              size: 28,
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type.displayName.split(' ')[0],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_selectedType != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedType!.displayName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedType!.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Worker name',
                  hintText: 'e.g. Marketing Helper',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _goalController,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g. Draft 5 ad headlines daily',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedType == null
              ? null
              : () {
                  final name = _nameController.text.trim();
                  final goal = _goalController.text.trim();
                  Navigator.of(context).pop(
                    _CreateWorkerDialogResult(
                      name: name.isEmpty ? 'New Worker' : name,
                      goal: goal.isEmpty ? 'Automated task execution' : goal,
                      type: _selectedType!,
                    ),
                  );
                },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
