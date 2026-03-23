import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/worker.dart';
import 'board_controller.dart';
import 'data/workr_backend_api.dart';
import 'widgets/worker_card.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardState = ref.watch(boardControllerProvider);
    final boardController = ref.read(boardControllerProvider.notifier);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    ref.listen<BoardState>(boardControllerProvider, (previous, next) {
      final prevMap = previous?.inboxByWorkerId ?? const {};
      for (final entry in next.inboxByWorkerId.entries) {
        final before = prevMap[entry.key]?.unreadCount ?? 0;
        final after = entry.value.unreadCount;
        if (after > before) {
          String? workerName;
          for (final worker in next.workers) {
            if (worker.id == entry.key) {
              workerName = worker.name;
              break;
            }
          }
          final added = after - before;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                workerName == null
                    ? 'New email alert: +$added unread'
                    : '$workerName: +$added new unread email${added > 1 ? 's' : ''}',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    });

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
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
                  color: theme.scaffoldBackgroundColor,
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
                          _BoardBackground(
                            size: canvasSize,
                            isDark: theme.brightness == Brightness.dark,
                          ),
                          // Brand label that stays anchored while the canvas pans/zooms.
                          // (We place it inside the canvas stack so it matches the board vibe.)
                          const _WorkrCanvasMark(),
                          for (final worker in boardState.workers)
                            Positioned(
                              left: worker.x,
                              top: worker.y,
                              child: WorkerCard(
                                worker: worker,
                                unreadCount:
                                    boardState
                                        .inboxByWorkerId[worker.id]
                                        ?.unreadCount ??
                                    0,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WorkerDetailScreen(
                                        workerId: worker.id,
                                        workerName: worker.name,
                                        workerType: worker.type,
                                      ),
                                    ),
                                  );
                                },
                                onOpenSettings: () {
                                  showDialog<void>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text(
                                          'Settings (placeholder)',
                                        ),
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
                                  if (worker.type == AgentType.research) {
                                    unawaited(
                                      boardController.runWorker(id: worker.id),
                                    );
                                  } else {
                                    unawaited(
                                      boardController.toggleWorker(
                                        id: worker.id,
                                      ),
                                    );
                                  }
                                },
                                onOpenInbox: worker.type == AgentType.email
                                    ? () async {
                                        await boardController
                                            .refreshUnreadForWorker(
                                              worker.id,
                                              limit: 20,
                                            );
                                        if (!context.mounted) return;
                                        final inbox = ref
                                            .read(boardControllerProvider)
                                            .inboxByWorkerId[worker.id];
                                        await showModalBottomSheet<void>(
                                          context: context,
                                          isScrollControlled: true,
                                          backgroundColor: Colors.transparent,
                                          builder: (_) => _EmailInboxSheet(
                                            workerName: worker.name,
                                            workerId: worker.id,
                                            unreadCount:
                                                inbox?.unreadCount ?? 0,
                                            messages:
                                                inbox?.messages ?? const [],
                                            onRefresh: () => boardController
                                                .refreshUnreadForWorker(
                                                  worker.id,
                                                  limit: 20,
                                                ),
                                            onGenerateDraft: (messageId) => ref
                                                .read(workrBackendApiProvider)
                                                .generateReplyDraft(
                                                  workerId: worker.id,
                                                  messageId: messageId,
                                                ),
                                            onSendReply:
                                                (
                                                  messageId,
                                                  to,
                                                  subject,
                                                  body,
                                                ) => ref
                                                    .read(
                                                      workrBackendApiProvider,
                                                    )
                                                    .sendReply(
                                                      workerId: worker.id,
                                                      messageId: messageId,
                                                      to: to,
                                                      subject: subject,
                                                      body: body,
                                                    ),
                                          ),
                                        );
                                      }
                                    : null,
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
                                              unawaited(
                                                boardController.deleteWorker(
                                                  id: worker.id,
                                                ),
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
                  padding: const EdgeInsets.all(20),
                  child: FloatingActionButton(
                    onPressed: () async {
                      final result =
                          await showDialog<_CreateWorkerDialogResult>(
                            context: context,
                            builder: (context) => const _CreateWorkerDialog(),
                          );
                      if (result == null) return;

                      await boardController.addWorker(
                        name: result.name,
                        description: result.goal,
                        type: result.type,
                      );
                    },
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    elevation: 2,
                    highlightElevation: 4,
                    child: const Icon(Icons.add_rounded, size: 28),
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
  final bool isDark;

  const _BoardBackground({required this.size, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final canvasColor = isDark ? const Color(0xFF101010) : Colors.white;
    final vignetteColor = isDark
        ? Colors.white.withValues(alpha: 0.035)
        : Colors.black.withValues(alpha: 0.03);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(decoration: BoxDecoration(color: canvasColor)),
        ),
        Positioned.fill(
          child: CustomPaint(
            size: Size(size, size),
            painter: _GridPainter(isDark: isDark),
          ),
        ),
        // Subtle vignette so the edges feel "contained" instead of flat.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: [Colors.transparent, vignetteColor],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GridPainter extends CustomPainter {
  final bool isDark;

  const _GridPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      // Minimal grid - premium feel with slightly better visibility
      ..color = isDark ? const Color(0x20FFFFFF) : const Color(0x12000000)
      ..strokeWidth = 0.7;

    final minorGridPaint = Paint()
      // Lighter lines for minor grid
      ..color = isDark ? const Color(0x10FFFFFF) : const Color(0x06000000)
      ..strokeWidth = 0.5;

    final nodePaint = Paint()
      ..color = isDark ? const Color(0x28FFFFFF) : const Color(0x1A000000)
      ..style = PaintingStyle.fill;

    // Slightly larger grid for phone readability.
    const grid = 56.0;
    const minorGrid = grid / 4;

    // Draw minor grid (faint subdivisions)
    for (double x = 0; x <= size.width; x += minorGrid) {
      if (x % grid != 0) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), minorGridPaint);
      }
    }
    for (double y = 0; y <= size.height; y += minorGrid) {
      if (y % grid != 0) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), minorGridPaint);
      }
    }

    // Draw major grid
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
          canvas.drawCircle(Offset(x, y), 1.1, nodePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _EmptyBoardHint extends StatelessWidget {
  const _EmptyBoardHint();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned.fill(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.14),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Your board is empty',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create your first AI Worker to get started',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
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
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      top: 24,
      left: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colorScheme.onSurface.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              'Workr',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailInboxSheet extends StatefulWidget {
  const _EmailInboxSheet({
    required this.workerName,
    required this.workerId,
    required this.unreadCount,
    required this.messages,
    required this.onRefresh,
    required this.onGenerateDraft,
    required this.onSendReply,
  });

  final String workerName;
  final String workerId;
  final int unreadCount;
  final List<EmailInboxMessage> messages;
  final Future<void> Function() onRefresh;
  final Future<EmailReplyDraft> Function(String messageId) onGenerateDraft;
  final Future<void> Function(
    String messageId,
    String to,
    String subject,
    String body,
  )
  onSendReply;

  @override
  State<_EmailInboxSheet> createState() => _EmailInboxSheetState();
}

class _EmailInboxSheetState extends State<_EmailInboxSheet> {
  final Set<String> _busyReplyMessageIds = <String>{};
  bool _batchReplyBusy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.72,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.14),
                        colorScheme.primary.withValues(alpha: 0.04),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: colorScheme.outlineVariant.withValues(alpha: .5),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_rounded, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${widget.workerName} inbox',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _batchReplyBusy ? null : widget.onRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      FilledButton.tonal(
                        onPressed: _batchReplyBusy
                            ? null
                            : _openBatchReplyPreviews,
                        child: Text(
                          _batchReplyBusy ? 'Drafting...' : 'AI Draft 5',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade500,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${widget.unreadCount} unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: widget.messages.isEmpty
                      ? Center(
                          child: Text(
                            widget.unreadCount > 0
                                ? 'Found unread emails, but previews are still loading.\nTry refresh in a moment.'
                                : 'No unread emails right now',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: widget.messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final message = widget.messages[index];
                            final isReplyBusy = _busyReplyMessageIds.contains(
                              message.id,
                            );
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message.subject,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message.from,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                                  ),
                                  if (message.snippet.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      message.snippet,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                  if (message.received.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      message.received,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.52),
                                          ),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: FilledButton.tonalIcon(
                                      onPressed:
                                          (isReplyBusy || _batchReplyBusy)
                                          ? null
                                          : () => _openReplyComposer(message),
                                      icon: isReplyBusy
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.reply_rounded,
                                              size: 16,
                                            ),
                                      label: const Text('Craft Reply'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReplyComposer(EmailInboxMessage message) async {
    setState(() => _busyReplyMessageIds.add(message.id));
    try {
      final draft = await widget.onGenerateDraft(message.id);
      if (!mounted) return;

      final sent = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ReplyComposerSheet(
          draft: draft,
          onSend: (body) =>
              widget.onSendReply(message.id, draft.to, draft.subject, body),
        ),
      );
      if (sent == true && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Reply sent')));
        await widget.onRefresh();
      }
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reply flow failed: $err')));
    } finally {
      if (mounted) {
        setState(() => _busyReplyMessageIds.remove(message.id));
      }
    }
  }

  Future<void> _openBatchReplyPreviews() async {
    setState(() => _batchReplyBusy = true);
    try {
      final top = widget.messages.take(5).toList(growable: false);
      final drafts = <EmailReplyDraft>[];
      for (final message in top) {
        final draft = await widget.onGenerateDraft(message.id);
        drafts.add(draft);
      }
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _BatchDraftPreviewSheet(
          drafts: drafts,
          onSend: (draft, body) => widget.onSendReply(
            draft.messageId,
            draft.to,
            draft.subject,
            body,
          ),
        ),
      );
      await widget.onRefresh();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Batch draft failed: $err')));
    } finally {
      if (mounted) {
        setState(() => _batchReplyBusy = false);
      }
    }
  }
}

class _BatchDraftPreviewSheet extends StatefulWidget {
  const _BatchDraftPreviewSheet({required this.drafts, required this.onSend});

  final List<EmailReplyDraft> drafts;
  final Future<void> Function(EmailReplyDraft draft, String body) onSend;

  @override
  State<_BatchDraftPreviewSheet> createState() =>
      _BatchDraftPreviewSheetState();
}

class _BatchDraftPreviewSheetState extends State<_BatchDraftPreviewSheet> {
  final Set<String> _sending = <String>{};
  final Set<String> _sent = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded),
                      const SizedBox(width: 8),
                      Text(
                        'AI reply previews (last 5)',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.drafts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (itemContext, index) {
                      final draft = widget.drafts[index];
                      final isSending = _sending.contains(draft.messageId);
                      final isSent = _sent.contains(draft.messageId);
                      final controller = TextEditingController(
                        text: draft.body,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.35,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To: ${draft.to}\nSubject: ${draft.subject}',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              minLines: 3,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: (isSending || isSent)
                                    ? null
                                    : () async {
                                        setState(() {
                                          _sending.add(draft.messageId);
                                        });
                                        try {
                                          await widget.onSend(
                                            draft,
                                            controller.text.trim(),
                                          );
                                          if (!mounted) return;
                                          setState(() {
                                            _sent.add(draft.messageId);
                                          });
                                        } catch (err) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(
                                            this.context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Send failed: $err',
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (mounted) {
                                            setState(() {
                                              _sending.remove(draft.messageId);
                                            });
                                          }
                                        }
                                      },
                                icon: Icon(
                                  isSent
                                      ? Icons.check_circle_rounded
                                      : Icons.send_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  isSent
                                      ? 'Sent'
                                      : isSending
                                      ? 'Sending...'
                                      : 'Send',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReplyComposerSheet extends StatefulWidget {
  const _ReplyComposerSheet({required this.draft, required this.onSend});

  final EmailReplyDraft draft;
  final Future<void> Function(String body) onSend;

  @override
  State<_ReplyComposerSheet> createState() => _ReplyComposerSheetState();
}

class _ReplyComposerSheetState extends State<_ReplyComposerSheet> {
  late final TextEditingController _controller;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.draft.body);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review reply before sending',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To: ${widget.draft.to}\nSubject: ${widget.draft.subject}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  minLines: 6,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Edit reply...',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _sending ? null : _send,
                        child: Text(_sending ? 'Sending...' : 'Send Reply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Send failed: $err')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class WorkerDetailScreen extends ConsumerStatefulWidget {
  final String workerId;
  final String workerName;
  final AgentType workerType;

  const WorkerDetailScreen({
    super.key,
    required this.workerId,
    required this.workerName,
    required this.workerType,
  });

  @override
  ConsumerState<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends ConsumerState<WorkerDetailScreen> {
  final _queryController = TextEditingController();
  final _sourceController = TextEditingController();
  final _transitOriginController = TextEditingController();
  final _transitDestinationController = TextEditingController();
  final _transitTelegramController = TextEditingController();
  final _transitAlertMinsController = TextEditingController(text: '8');
  final _transitPollMinsController = TextEditingController(text: '2');
  bool _runningResearch = false;
  bool _creatingTasks = false;
  bool _loadingTransit = false;
  bool _savingTransit = false;
  bool _transitAutoRun = false;
  ResearchRunResult? _run;
  List<WorkerTask> _tasks = const [];
  final List<String> _sourceUrls = <String>[];
  final Set<String> _selectedCardIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.workerType == AgentType.research) {
      unawaited(_loadResearchData());
    } else if (widget.workerType == AgentType.transitMaps) {
      unawaited(_loadTransitConfig());
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    _sourceController.dispose();
    _transitOriginController.dispose();
    _transitDestinationController.dispose();
    _transitTelegramController.dispose();
    _transitAlertMinsController.dispose();
    _transitPollMinsController.dispose();
    super.dispose();
  }

  Future<void> _loadTransitConfig() async {
    setState(() => _loadingTransit = true);
    try {
      final config = await ref
          .read(workrBackendApiProvider)
          .getTransitConfig(widget.workerId);
      if (!mounted) return;
      setState(() {
        _transitOriginController.text = config.origin;
        _transitDestinationController.text = config.destination;
        _transitTelegramController.text = config.telegramChatId;
        _transitAlertMinsController.text = config.alertMinutesBefore.toString();
        _transitPollMinsController.text = config.pollIntervalMinutes.toString();
        _transitAutoRun = config.autoRunEnabled;
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load transit config: $err')),
      );
    } finally {
      if (mounted) setState(() => _loadingTransit = false);
    }
  }

  Future<bool> _saveTransitConfig() async {
    final destination = _transitDestinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Destination or postcode is required')),
      );
      return false;
    }
    final alertMinutes =
        int.tryParse(_transitAlertMinsController.text.trim()) ?? 8;
    final pollMinutes =
        int.tryParse(_transitPollMinsController.text.trim()) ?? 2;

    setState(() => _savingTransit = true);
    try {
      await ref
          .read(workrBackendApiProvider)
          .saveTransitConfig(
            workerId: widget.workerId,
            origin: _transitOriginController.text.trim(),
            destination: destination,
            alertMinutesBefore: alertMinutes,
            pollIntervalMinutes: pollMinutes,
            telegramChatId: _transitTelegramController.text.trim(),
          );
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Transit config saved')));
      return true;
    } catch (err) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $err')));
      return false;
    } finally {
      if (mounted) setState(() => _savingTransit = false);
    }
  }

  Future<void> _toggleTransitWatch() async {
    final saved = await _saveTransitConfig();
    if (!saved) return;
    final shouldEnable = !_transitAutoRun;
    try {
      final updated = await ref
          .read(workrBackendApiProvider)
          .setWorkerAutoRun(
            id: widget.workerId,
            enabled: shouldEnable,
            intervalMinutes:
                int.tryParse(_transitPollMinsController.text.trim()) ?? 2,
          );
      if (!mounted) return;
      setState(() => _transitAutoRun = updated.autoRunEnabled);
      await ref.read(boardControllerProvider.notifier).refreshWorkers();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldEnable ? 'Transit watch started' : 'Transit watch stopped',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not update watch: $err')));
    }
  }

  Future<void> _loadResearchData() async {
    final api = ref.read(workrBackendApiProvider);
    final latest = await api.getLatestResearchRun(widget.workerId);
    final tasks = await api.listWorkerTasks(widget.workerId);
    if (!mounted) return;
    setState(() {
      _run = latest;
      _tasks = tasks;
      _sourceUrls
        ..clear()
        ..addAll(latest?.sources ?? const []);
      _selectedCardIds
        ..clear()
        ..addAll((latest?.actionCards ?? const []).map((e) => e.id));
    });
  }

  Future<void> _runResearch() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;
    setState(() => _runningResearch = true);
    try {
      final run = await ref
          .read(workrBackendApiProvider)
          .runResearch(
            workerId: widget.workerId,
            query: query,
            sources: _sourceUrls,
          );
      if (!mounted) return;
      setState(() {
        _run = run;
        _sourceUrls
          ..clear()
          ..addAll(run.sources);
        _selectedCardIds
          ..clear()
          ..addAll(run.actionCards.map((e) => e.id));
      });
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Research failed: $err')));
    } finally {
      if (mounted) setState(() => _runningResearch = false);
    }
  }

  void _addSourceUrl() {
    final raw = _sourceController.text.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid URL')));
      return;
    }
    if (_sourceUrls.contains(raw)) {
      _sourceController.clear();
      return;
    }
    setState(() {
      _sourceUrls.add(raw);
      _sourceController.clear();
    });
  }

  Future<void> _createTasksFromCards() async {
    if (_run == null) return;
    setState(() => _creatingTasks = true);
    try {
      final created = await ref
          .read(workrBackendApiProvider)
          .createTasksFromLatestResearch(
            workerId: widget.workerId,
            selectedCardIds: _selectedCardIds.toList(growable: false),
          );
      if (!mounted) return;
      final all = await ref
          .read(workrBackendApiProvider)
          .listWorkerTasks(widget.workerId);
      if (!mounted) return;
      setState(() {
        _tasks = all;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created ${created.length} task(s)')),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Task creation failed: $err')));
    } finally {
      if (mounted) setState(() => _creatingTasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workerType == AgentType.transitMaps) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.workerName} • Transit Watch')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _transitDestinationController,
              decoration: const InputDecoration(
                labelText: 'Destination / postcode',
                hintText: 'e.g. SW1A 1AA or Canary Wharf',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _transitOriginController,
              decoration: const InputDecoration(
                labelText: 'Origin (optional)',
                hintText: 'Current Location',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _transitTelegramController,
              decoration: const InputDecoration(
                labelText: 'Telegram chat id',
                hintText: 'e.g. 123456789',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _transitAlertMinsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Alert before (mins)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _transitPollMinsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Check every (mins)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _savingTransit ? null : _saveTransitConfig,
                    icon: _savingTransit
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const Text('Save Config'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loadingTransit ? null : _toggleTransitWatch,
                    icon: Icon(
                      _transitAutoRun
                          ? Icons.stop_circle_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                    label: Text(_transitAutoRun ? 'Stop Watch' : 'Start Watch'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              ),
              child: Text(
                _transitAutoRun
                    ? 'Running in background. You will get a Telegram alert when the bus is close.'
                    : 'Set destination + Telegram chat id, then start watch.',
              ),
            ),
          ],
        ),
      );
    }

    if (widget.workerType != AgentType.research) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.workerName)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Worker detail for ${widget.workerType.displayName}\n\nComing next.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final cards = _run?.actionCards ?? const <ResearchActionCard>[];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.workerName} • Research')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _queryController,
            decoration: const InputDecoration(
              labelText: 'Research query',
              hintText: 'e.g. best onboarding strategy for fintech users',
              border: OutlineInputBorder(),
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sourceController,
                  decoration: const InputDecoration(
                    labelText: 'Add source URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addSourceUrl(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: _addSourceUrl,
                child: const Text('Add'),
              ),
            ],
          ),
          if (_sourceUrls.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final source in _sourceUrls)
                  InputChip(
                    label: SizedBox(
                      width: 220,
                      child: Text(source, overflow: TextOverflow.ellipsis),
                    ),
                    onDeleted: () {
                      setState(() => _sourceUrls.remove(source));
                    },
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _runningResearch ? null : _runResearch,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(_runningResearch ? 'Running...' : 'Run Research'),
          ),
          const SizedBox(height: 16),
          if (_run != null) ...[
            Text(
              'Summary',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.35,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_run!.summary),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Action plan cards',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _creatingTasks ? null : _createTasksFromCards,
                  child: Text(_creatingTasks ? 'Creating...' : 'Create Tasks'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final card in cards)
              CheckboxListTile(
                value: _selectedCardIds.contains(card.id),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedCardIds.add(card.id);
                    } else {
                      _selectedCardIds.remove(card.id);
                    }
                  });
                },
                title: Text(card.title),
                subtitle: Text(
                  '${card.details}\nOwner: ${card.owner} • Due: ${card.dueHint} • Priority: ${card.priority}',
                ),
                isThreeLine: true,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            const SizedBox(height: 18),
          ],
          Text(
            'Tasks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_tasks.isEmpty)
            const Text('No tasks yet')
          else
            for (final task in _tasks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(task.title),
                subtitle: Text('${task.status} • ${task.priority}'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
        ],
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
  final _descriptionController = TextEditingController();
  AgentType? _selectedType;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = AgentType.values;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              // Agent Type Selection
              Text(
                'Select Agent Type',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: types.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected = _selectedType == type;
                  final label = switch (type) {
                    AgentType.email => 'Email',
                    AgentType.socialContent => 'Social',
                    AgentType.financeOps => 'Finance',
                    AgentType.research => 'Research',
                    AgentType.taskWorkflow => 'Tasks',
                    AgentType.transitMaps => 'Transit',
                  };
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary.withValues(alpha: 0.14)
                            : colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type.icon,
                            size: 22,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface.withValues(alpha: 0.74),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface.withValues(
                                      alpha: 0.78,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_selectedType != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedType!.displayName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedType!.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.7),
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
                controller: _descriptionController,
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
                  final description = _descriptionController.text.trim();

                  Navigator.of(context).pop(
                    _CreateWorkerDialogResult(
                      name: name.isEmpty ? 'New Worker' : name,
                      goal: description.isEmpty
                          ? 'Automated task execution'
                          : description,
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
