import 'package:flutter/material.dart';
import '../core/freemium/freemium_service.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart' show isSpanishNotifier;

/// A "Save Scenario" button that pins the current calculator result.
///
/// - **Premium users**: shows a name-entry dialog before saving.
/// - **Free users**: saves immediately without a label (3 max pinned slots).
///
/// Bilingual EN/ES via [isSpanishNotifier].
class SaveScenarioButton extends StatefulWidget {
  /// Called when the user confirms the save. [label] is null for free users.
  final Future<void> Function(String? label) onSave;

  const SaveScenarioButton({super.key, required this.onSave});

  @override
  State<SaveScenarioButton> createState() => _SaveScenarioButtonState();
}

class _SaveScenarioButtonState extends State<SaveScenarioButton> {
  bool _saving = false;

  Future<void> _handleTap() async {
    final isEs = isSpanishNotifier.value;
    final s = isEs ? const AppStringsEs() : const AppStringsEn();
    String? label;

    if (freemiumService.hasFullAccess) {
      label = await _showNameDialog(s);
      if (label == null) return;
      if (label.trim().isEmpty) label = null;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(label);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            label != null && label.isNotEmpty
                ? s.scenarioSaved(label)
                : s.scenarioSavedNoLabel,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _showNameDialog(AppStrings s) {
    return showDialog<String>(
      context: context,
      builder: (_) => _SaveScenarioNameDialog(s: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEs = isSpanishNotifier.value;
    final s = isEs ? const AppStringsEs() : const AppStringsEn();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _saving ? null : _handleTap,
        icon: _saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bookmark_add_outlined, size: 18),
        label: Text(_saving ? s.saving : s.saveScenario),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}

class _SaveScenarioNameDialog extends StatefulWidget {
  final AppStrings s;
  const _SaveScenarioNameDialog({required this.s});

  @override
  State<_SaveScenarioNameDialog> createState() =>
      _SaveScenarioNameDialogState();
}

class _SaveScenarioNameDialogState extends State<_SaveScenarioNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(s.saveScenarioTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: s.scenarioNameHint,
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(s.save),
        ),
      ],
    );
  }
}
