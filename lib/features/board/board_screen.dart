import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'board_controller.dart';
import 'widgets/worker_card.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardControllerProvider);
    final boardController = ref.read(boardControllerProvider.notifier);
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerLowest,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double base = max(constraints.maxWidth, constraints.maxHeight);
          // Keep the internal canvas reasonably sized so it feels "board-like"
          // rather than an infinite scroll with empty black areas.
          final double canvasSize = (base == 0 ? 420 : base) * 1.35;

          return Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: theme.colorScheme.surfaceContainerLowest,
                  child: InteractiveViewer(
                    // Lets users pan around the board.
                    panEnabled: true,
                    // Lets users zoom in/out with pinch gestures.
                    scaleEnabled: true,
                    minScale: 0.5,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(160),
                    constrained: false,
                    child: SizedBox(
                      width: canvasSize,
                      height: canvasSize,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _BoardBackground(size: canvasSize),
                          // Brand label that stays anchored while the canvas pans/zooms.
                          // (We place it inside the canvas stack so it matches the board vibe.)
                          const _WorkrCanvasMark(),
                          for (final worker in boardState.workers)
                            Positioned(
                              left: worker.x,
                              top: worker.y,
                              child: WorkerCard(
                                worker: worker,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WorkerDetailScreen(
                                        workerId: worker.id,
                                        workerName: worker.name,
                                      ),
                                    ),
                                  );
                                },
                                onOpenSettings: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Settings (placeholder)'),
                                        content: const Text(
                                          'Future: configure Worker behavior here.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Close'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onRun: () {
                                  unawaited(
                                    boardController.runWorker(id: worker.id),
                                  );
                                },
                                onDelete: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Delete worker?'),
                                        content: Text(
                                          'Delete "${worker.name}" from the board?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              boardController.deleteWorker(
                                                id: worker.id,
                                              );
                                            },
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onPositionChanged: (x, y) {
                                  // Persist drag position in Riverpod state.
                                  boardController.updatePosition(
                                    id: worker.id,
                                    x: x,
                                    y: y,
                                  );
                                },
                              ),
                            ),
                          if (boardState.workers.isEmpty)
                            const _EmptyBoardHint(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FloatingActionButton(
                    onPressed: () async {
                      final result =
                          await showDialog<_CreateWorkerDialogResult>(
                        context: context,
                        builder: (context) => const _CreateWorkerDialog(),
                      );
                      if (result == null) return;

                      boardController.addWorker(
                        name: result.name,
                        description: result.goal,
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BoardBackground extends StatelessWidget {
  final double size;

  const _BoardBackground({required this.size});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topLeft,
                radius: 1.1,
                colors: [
                  theme.colorScheme.primaryContainer.withAlpha(210),
                  theme.colorScheme.secondaryContainer.withAlpha(130),
                  theme.colorScheme.surfaceContainerLowest,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            size: Size(size, size),
            painter: _GridPainter(),
          ),
        ),
        // Subtle vignette so the edges feel "contained" instead of flat.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [
                  Colors.transparent,
                  Colors.black.withAlpha(35),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      // Keep grid super subtle (still visible on light gradients).
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;

    final nodePaint = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.fill;

    // Slightly larger grid for phone readability.
    const grid = 56.0;

    for (double x = 0; x <= size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y <= size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Add small "nodes" at intersections every other grid step.
    // This gives a digital/agent-board feel without being too busy.
    const nodeEvery = 2;
    for (int xi = 0; xi * grid <= size.width; xi++) {
      for (int yi = 0; yi * grid <= size.height; yi++) {
        if (xi % nodeEvery == 0 && yi % nodeEvery == 0) {
          final x = xi * grid;
          final y = yi * grid;
          canvas.drawCircle(Offset(x, y), 1.35, nodePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EmptyBoardHint extends StatelessWidget {
  const _EmptyBoardHint();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No Workers yet.\nTap + to create your first AI Worker.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black)
                      .withAlpha((0.75 * 255).round()),
                ),
          ),
        ),
      ),
    );
  }
}

class _WorkrCanvasMark extends StatelessWidget {
  const _WorkrCanvasMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      top: 26,
      left: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest.withAlpha(160),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: theme.colorScheme.primary.withAlpha(60),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Workr',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Workers',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder for future Worker detail / settings pages.
class WorkerDetailScreen extends StatelessWidget {
  final String workerId;
  final String workerName;

  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    required this.workerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(workerName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Worker detail placeholder\n\nid: $workerId',
            textAlign: TextAlign.center,
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

