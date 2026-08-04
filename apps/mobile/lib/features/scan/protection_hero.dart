import 'package:flutter/material.dart';
import 'package:unrecorded_core/unrecorded_core.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import 'main_screen_ui_state.dart';
import 'protection_accent.dart';

/// Bold status hero driven entirely by [MainScreenUiState].
class ProtectionHero extends StatelessWidget {
  const ProtectionHero({
    super.key,
    required this.state,
    this.onViewDetails,
    this.onDismiss,
  });

  final MainScreenUiState state;
  final VoidCallback? onViewDetails;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = state.accent.resolve(context);
    final tint = accent.withValues(alpha: 0.14);

    return Semantics(
      container: true,
      liveRegion: state.semanticLiveRegion,
      label: state.semanticLabel,
      child: Material(
        color: tint,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroIcon(
                    kind: state.heroKind,
                    accent: accent,
                    risk: state.riskLevel,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                state.heroTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (state.isDemoMode)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: _DemoChip(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.activityLine,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                        if (state.showLiveAlertActions &&
                            state.alertDeviceTitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            state.alertDeviceTitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (state.showLiveAlertActions) ...[
                const SizedBox(height: 12),
                Text(
                  AppCopy.notProofOfRecording,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Flexible(
                      child: TextButton(
                        onPressed: onViewDetails,
                        child: const Text('View details'),
                      ),
                    ),
                    Flexible(
                      child: TextButton(
                        onPressed: onDismiss,
                        child: const Text('Dismiss'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: AppCopy.demoModeBanner,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          'Demo',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({
    required this.kind,
    required this.accent,
    required this.risk,
  });

  final MainScreenHeroKind kind;
  final Color accent;
  final RiskLevel risk;

  @override
  Widget build(BuildContext context) {
    if (kind == MainScreenHeroKind.transition) {
      return SizedBox(
        width: 48,
        height: 48,
        child: CircularProgressIndicator(
          // Determinate value avoids an infinite ticker that breaks pumpAndSettle.
          value: 0.65,
          strokeWidth: 3,
          color: accent,
        ),
      );
    }

    switch (kind) {
      case MainScreenHeroKind.off:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.protectionOn,
          size: 48,
        );
      case MainScreenHeroKind.protecting:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.scanningActive,
          size: 48,
        );
      case MainScreenHeroKind.possibleRisk:
        if (risk == RiskLevel.medium) {
          return UnrecordedIcon(
            asset: UnrecordedIconAsset.riskMedium,
            size: 48,
            color: accent,
          );
        }
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.highRisk,
          size: 48,
        );
      case MainScreenHeroKind.actionNeeded:
        return const UnrecordedStatusIcon(
          asset: UnrecordedStatusAsset.permissionsNeeded,
          size: 48,
        );
      case MainScreenHeroKind.error:
        return UnrecordedIcon(
          asset: UnrecordedIconAsset.alert,
          size: 48,
          color: accent,
        );
      case MainScreenHeroKind.transition:
        return const SizedBox.shrink();
    }
  }
}
