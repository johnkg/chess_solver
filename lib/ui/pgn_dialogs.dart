import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/pgn.dart';

/// Shows [pgn] in a dialog with a Copy button.
Future<void> showPgnExport(BuildContext context, String pgn) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Export PGN'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: SelectableText(
            pgn,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        FilledButton.icon(
          icon: const Icon(Icons.copy),
          label: const Text('Copy'),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: pgn));
            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('PGN copied.')),
            );
          },
        ),
      ],
    ),
  );
}

/// Asks for PGN text and returns the parsed game, or null if cancelled. A
/// bad paste keeps the dialog open and says which move failed.
Future<PgnGame?> showPgnImport(BuildContext context) {
  return showDialog<PgnGame>(
    context: context,
    builder: (context) => const _ImportDialog(),
  );
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog();

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _text.text = data!.text!;
        _error = null;
      });
    }
  }

  void _load() {
    try {
      Navigator.pop(context, parsePgn(_text.text));
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    } on Object {
      setState(() => _error = 'That is not a valid PGN.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import PGN'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 6,
              maxLines: 10,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                hintText: '[White "..."]\n\n1. e4 e5 2. Nf3 ...',
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('Paste from clipboard'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _load, child: const Text('Open game')),
      ],
    );
  }
}
