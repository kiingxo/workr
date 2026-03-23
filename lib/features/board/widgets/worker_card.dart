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
          width: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isRunning ? 0.12 : 0.06),
                blurRadius: isRunning ? 16 : 8,
                offset: Offset(0, isRunning ? 8 : 4),
              ),
            ],
            border: Border.all(
              color: Colors.black.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with AI face and name
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AiFace(
                            workerId: widget.worker.id,
                            status: widget.worker.status,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.worker.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.worker.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            widget.worker.type.icon,
                            size: 16,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Status pill
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _StatusPill(
                    emoji: statusEmoji,
                    text: statusText,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 10),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.play_arrow_rounded,
                          onPressed: widget.onRun,
                          tooltip: 'Run',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.settings_outlined,
                          onPressed: widget.onOpenSettings,
                          tooltip: 'Settings',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.delete_outline_rounded,
                          isDestructive: true,
                          onPressed: widget.onDelete,
                          tooltip: 'Delete',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
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
      0.65,
      status == WorkerStatus.running ? 0.88 : 0.80,
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
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          if (glow)
            BoxShadow(
              color: faceColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
        border: Border.all(
          color: Colors.black.withOpacity(0.08),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          '$eye$eye\n$mouth',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool isDestructive;

  const _ActionButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDestructive
                  ? Colors.red.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDestructive
                ? Colors.red.shade600
                : Colors.black.withOpacity(0.7),
          ),
        ),
      ),
    );
  }
}
