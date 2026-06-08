import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:unrecorded_ui/unrecorded_ui.dart';

import '../../copy/feedback_copy.dart';
import '../../services/feedback_diagnostics.dart';
import '../../services/feedback_draft.dart';
import '../../services/feedback_launcher.dart';
import '../../services/feedback_mailto.dart';
import '../../services/scanner_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  FeedbackType _type = FeedbackType.bug;
  final _messageController = TextEditingController();
  final _emailController = TextEditingController();
  bool _includeDiagnostics = false;
  bool _submitting = false;
  String? _emailError;

  @override
  void dispose() {
    _messageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting && _messageController.text.trim().isNotEmpty;

  bool _isValidEmail(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(trimmed);
  }

  FeedbackDraft _buildDraft() {
    final email = _emailController.text.trim();
    return FeedbackDraft(
      type: _type,
      message: _messageController.text.trim(),
      contactEmail: email.isEmpty ? null : email,
      includeDiagnostics: _includeDiagnostics,
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!_isValidEmail(email)) {
      setState(() => _emailError = FeedbackCopy.invalidEmail);
      return;
    }
    setState(() {
      _emailError = null;
      _submitting = true;
    });

    final draft = _buildDraft();
    FeedbackDiagnostics? diagnostics;
    if (draft.includeDiagnostics) {
      final packageInfo = await PackageInfo.fromPlatform();
      final scanState = ref.read(scanControllerProvider);
      final scannerMode = ref.read(scannerConfigProvider)?.mode;
      diagnostics = await collectFeedbackDiagnostics(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
        scannerMode: scannerMode,
        scanStatus: scanState.status,
        protectionActive: scanState.protectionActive,
      );
    }

    final mailtoUri = buildFeedbackMailtoUri(draft, diagnostics: diagnostics);
    final submit = ref.read(feedbackSubmitFnProvider);
    final launched = await submitFeedbackUri(mailtoUri, submit: submit);

    if (!mounted) return;

    setState(() => _submitting = false);

    if (launched) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(FeedbackCopy.submitSuccess)),
      );
      return;
    }

    await _showFallbackDialog(draft, diagnostics: diagnostics);
  }

  Future<void> _showFallbackDialog(
    FeedbackDraft draft, {
    FeedbackDiagnostics? diagnostics,
  }) async {
    final githubUri = buildFeedbackGithubIssueUri(
      draft,
      diagnostics: diagnostics,
    );
    final submit = ref.read(feedbackSubmitFnProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(FeedbackCopy.fallbackTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(FeedbackCopy.fallbackBody),
              const SizedBox(height: 12),
              SelectableText(
                FeedbackCopy.feedbackEmail,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: FeedbackCopy.feedbackEmail),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(FeedbackCopy.emailCopied)),
                );
              }
            },
            child: const Text(FeedbackCopy.fallbackCopyEmail),
          ),
          TextButton(
            onPressed: () async {
              final opened = await submitFeedbackUri(githubUri, submit: submit);
              if (opened && context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text(FeedbackCopy.fallbackOpenGithub),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BackButton(onPressed: () => context.pop()),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: AppLogo(size: 26),
            ),
          ],
        ),
        leadingWidth: 96,
        title: const Text(FeedbackCopy.screenTitle),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          children: [
            Text(FeedbackCopy.intro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            const HelperText(text: FeedbackCopy.privacyNote),
            const SizedBox(height: 20),
            Text(FeedbackCopy.typeLabel, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownMenu<FeedbackType>(
              key: const Key('feedback_type_dropdown'),
              initialSelection: _type,
              expandedInsets: EdgeInsets.zero,
              dropdownMenuEntries: FeedbackType.values
                  .map(
                    (type) => DropdownMenuEntry(
                      value: type,
                      label: type.label,
                    ),
                  )
                  .toList(),
              onSelected: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('feedback_message_field'),
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: FeedbackCopy.messageLabel,
                helperText: FeedbackCopy.messageHelper,
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('feedback_email_field'),
              controller: _emailController,
              decoration: InputDecoration(
                labelText: FeedbackCopy.contactEmailLabel,
                helperText: FeedbackCopy.contactEmailHelper,
                errorText: _emailError,
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('feedback_diagnostics_switch'),
              contentPadding: EdgeInsets.zero,
              title: const Text(FeedbackCopy.diagnosticsTitle),
              subtitle: const Text(FeedbackCopy.diagnosticsSubtitle),
              value: _includeDiagnostics,
              onChanged: (value) => setState(() => _includeDiagnostics = value),
            ),
            const SizedBox(height: 24),
            PrimaryActionButton(
              key: const Key('feedback_submit_button'),
              label: FeedbackCopy.sendFeedbackButton,
              icon: const UnrecordedIcon(
                asset: UnrecordedIconAsset.share,
                size: 24,
                color: Colors.white,
              ),
              onPressed: _canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }
}
