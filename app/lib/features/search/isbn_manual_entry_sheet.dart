import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

const isbnManualEntryFieldKey = Key('isbnManualEntryField');

/// Typed ISBN fallback from the barcode scanner. Pops a normalized ISBN-13,
/// or null when the sheet is dismissed.
Future<String?> showIsbnManualEntrySheet(BuildContext context) {
  return showRdModalSheet<String>(
    context: context,
    builder: (_) => const IsbnManualEntrySheet(),
  );
}

class IsbnManualEntrySheet extends StatefulWidget {
  const IsbnManualEntrySheet({super.key});

  @override
  State<IsbnManualEntrySheet> createState() => _IsbnManualEntrySheetState();
}

class _IsbnManualEntrySheetState extends State<IsbnManualEntrySheet> {
  late final TextEditingController _isbn;
  String? _error;

  @override
  void initState() {
    super.initState();
    _isbn = TextEditingController();
  }

  @override
  void dispose() {
    _isbn.dispose();
    super.dispose();
  }

  void _submit() {
    final l = AppL10n.of(context);
    final raw = _isbn.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = l.errFieldRequired);
      return;
    }
    final isbn = normalizeScannedIsbn(raw);
    if (isbn == null) {
      setState(() => _error = l.scanIsbnManualInvalid);
      return;
    }
    Navigator.of(context).pop(isbn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ReadendarTokens.sp5,
        ReadendarTokens.sp4,
        ReadendarTokens.sp5,
        ReadendarTokens.sp4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.scanIsbnManualEntry,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: ReadendarTokens.sp4),
          RdTextField(
            key: isbnManualEntryFieldKey,
            controller: _isbn,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: RdFormFieldLabel.decoration(
              context,
              labelText: l.metaIsbn,
              required: true,
              decoration: InputDecoration(
                hintText: l.scanIsbnManualHint,
                errorText: _error,
              ),
            ),
          ),
          const SizedBox(height: ReadendarTokens.sp4),
          RdButton.primary(
            onPressed: _submit,
            icon: LucideIcons.search,
            label: l.actionSearch,
            expand: true,
          ),
        ],
      ),
    );
  }
}
