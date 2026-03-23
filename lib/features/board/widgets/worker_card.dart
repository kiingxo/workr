import 'package:flutter/material.dart';

import '../../../models/worker.dart';

/// A draggable card representing a [Worker] on the board.
///
/// Drag behavior:
/// - Long press starts dragging.
/// - While the finger moves, we update the Worker's (x/y) in real-time.
/// - Position updates are persisted via the provided callback.
class WorkerCard extends StatefulWidget {
  final Worker worker;
  final VoidCallback onTap;
  final VoidCallback onRun;
  final VoidCallback onOpenSettings;
  final VoidCallback onDelete;
  final void Function(double x, double y) onPositionChanged;

  const WorkerCard({
    super.key,
    required this.worker,
    required this.onTap,
    required this.onRun,
    required this.onOpenSettings,
    required this.onDelete,
    required this.onPositionChanged,
  });

  @override
  State<WorkerCard> createState() => _WorkerCardState();
}

class _WorkerCardState extends State<WorkerCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  double _dragStartX = 0;
  double _dragStartY = 0;
  double _dragCurrentX = 0;
  double _dragCurrentY = 0;

  WorkerStatus get _status => widget.worker.status;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant WorkerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.worker.status != widget.worker.status) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    _pulseController.stop();
    if (_status == WorkerStatus.running) {
      // Repeat to create a subtle "running" glow/pulse.
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final statusEmoji = switch (widget.worker.status) {
      WorkerStatus.running => '🟢',
      WorkerStatus.idle => '⚪',
      WorkerStatus.error => '🔴',
    };

    final statusText = switch (widget.worker.status) {
      WorkerStatus.running => 'Running',
      WorkerStatus.idle => 'Idle',
      WorkerStatus.error => 'Error',
    };

    final statusColor = switch (widget.worker.status) {
      WorkerStatus.running => Colors.green,
      WorkerStatus.idle => Colors.grey,
      WorkerStatus.error => Colors.red,
    };

    final isRunning = widget.worker.status == WorkerStatus.running;

    return GestureDetector(
      // Drag behavior:
      // - Normal touch-drag moves the worker card.
      // - Long-press also moves it (more deliberate, matches the spec).
      //
      // We attach gestures to the card so it wins the gesture arena over the board pan.
      behavior: HitTestBehavior.opaque,
      onPanStart: (details) {
        _dragStartX = widget.worker.x;
        _dragStartY = widget.worker.y;
        _dragCurrentX = widget.worker.x;
        _dragCurrentY = widget.worker.y;
      },
      onPanUpdate: (details) {
        _dragCurrentX += details.delta.dx;
        _dragCurrentY += details.delta.dy;

        widget.onPositionChanged(
          _dragCurrentX.clamp(0.0, double.infinity),
          _dragCurrentY.clamp(0.0, double.infinity),
        );
      },
      onPanEnd: (_) {
        // Keep last positions (Riverpod has already persisted them).
      },
      onLongPressStart: (details) {
        _dragStartX = widget.worker.x;
        _dragStartY = widget.worker.y;
      },
      onLongPressMoveUpdate: (details) {
        // `offsetFromOrigin` is the movement delta since the long-press started,
        // in the widget's local coordinate system. This aligns with the board's
        // Positioned coordinates because the card lives inside the board's Stack.
        final nextX = _dragStartX + details.offsetFromOrigin.dx;
        final nextY = _dragStartY + details.offsetFromOrigin.dy;

        widget.onPositionChanged(
          nextX.clamp(0.0, double.infinity),
          nextY.clamp(0.0, double.infinity),
        );
      },
      child: AnimatedScale(
        scale: isRunning ? _pulseScale.value : 1.0,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 180,
          // Keep card height compact to reduce clutter on small screens.
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: statusColor.withAlpha(((isRunning ? 0.25 : 0.12) * 255).round()),
                blurRadius: isRunning ? 16 : 8,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: statusColor.withAlpha((0.25 * 255).round()),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status accent stripe (Workr-style "agent active" look).
                  Container(
                    height: 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withAlpha(220),
                          statusColor.withAlpha(70),
                        ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AiFace(
                        workerId: widget.worker.id,
                        status: widget.worker.status,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: widget.onTap,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.worker.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.worker.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                  color: (theme.textTheme.bodySmall?.color ?? Colors.black)
                                      .withAlpha((0.75 * 255).round()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.play_arrow_rounded, size: 20),
                            onPressed: widget.onRun,
                            tooltip: 'Run worker',
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.settings_outlined, size: 20),
                            onPressed: widget.onOpenSettings,
                            tooltip: 'Settings (placeholder)',
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            onPressed: widget.onDelete,
                            tooltip: 'Delete worker',
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _StatusPill(
                    emoji: statusEmoji,
                    text: statusText,
                    color: statusColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AiFace extends StatelessWidget {
  final String workerId;
  final WorkerStatus status;

  const _AiFace({
    required this.workerId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Deterministic color/expression based on workerId (no backend needed).
    final hash = workerId.hashCode;
    final hue = (hash % 360 + 360) % 360;
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

    final glow = status == WorkerStatus.running;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
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
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 0.95,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

