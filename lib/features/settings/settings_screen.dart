import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../board/board_controller.dart' show boardControllerProvider;
import '../board/data/workr_backend_api.dart';
import 'theme_mode_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isGoogleConnected = false;
  bool _isLoadingGoogle = true;
  bool _isConnectingGoogle = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshGoogleIntegration());
  }

  Future<void> _refreshGoogleIntegration() async {
    setState(() => _isLoadingGoogle = true);
    try {
      final connected = await ref
          .read(workrBackendApiProvider)
          .hasGoogleIntegration();
      if (!mounted) return;
      setState(() {
        _isGoogleConnected = connected;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isGoogleConnected = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingGoogle = false);
      }
    }
  }

  Future<void> _connectGoogle() async {
    setState(() => _isConnectingGoogle = true);
    try {
      if (_isGoogleConnected) {
        await ref.read(workrBackendApiProvider).disconnectGoogle();
        if (!mounted) return;
        setState(() => _isGoogleConnected = false);
      }

      final authUrl = await ref
          .read(workrBackendApiProvider)
          .googleOAuthStartUrl();
      final launched = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;

      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google OAuth URL')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Finish Google sign-in in browser, then tap "Check status".',
          ),
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google connect failed: $err')));
    } finally {
      if (mounted) {
        setState(() => _isConnectingGoogle = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(boardControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeControllerProvider);
    final themeModeController = ref.read(themeModeControllerProvider.notifier);
    final isSystemDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDarkMode =
        themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && isSystemDark);

    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Settings',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Configure your Workr board and preferences.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Material(
                color: colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appearance',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Dark mode',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          isDarkMode ? 'On' : 'Off',
                          style: theme.textTheme.bodySmall,
                        ),
                        value: isDarkMode,
                        onChanged: (enabled) {
                          themeModeController.setThemeMode(
                            enabled ? ThemeMode.dark : ThemeMode.light,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _isGoogleConnected
                                ? Icons.check_circle_rounded
                                : Icons.link_off_rounded,
                            size: 18,
                            color: _isGoogleConnected
                                ? Colors.green
                                : colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isLoadingGoogle
                                  ? 'Checking Google connection...'
                                  : _isGoogleConnected
                                  ? 'Google connected (Gmail ready)'
                                  : 'Google not connected',
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _isConnectingGoogle
                                ? null
                                : _connectGoogle,
                            icon: const Icon(Icons.mail_outline_rounded),
                            label: Text(
                              _isConnectingGoogle
                                  ? 'Connecting...'
                                  : _isGoogleConnected
                                  ? 'Reconnect Google'
                                  : 'Connect Google',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _refreshGoogleIntegration,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Check status'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Board snapshot',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                        label: 'Workers',
                        value: '${boardState.workers.length}',
                      ),
                      _InfoRow(
                        label: 'Running',
                        value:
                            '${boardState.workers.where((w) => w.status.name == 'running').length}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Future: per-worker settings, global preferences, and worker scheduling.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
