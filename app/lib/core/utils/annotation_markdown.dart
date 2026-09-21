import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:markdown_quill/markdown_quill.dart';

/// Plain-text preview of an annotation body for list rows and share cards.
///
/// Uses the same Markdown → Quill pipeline as the editor so escaped syntax
/// (for example `\*`) reads the same as in [QuoteComposerSheet].
String annotationMarkdownPreview(String markdown) =>
    _annotationMarkdownPlain(markdown, collapseWhitespace: true);

/// Full plain-text body for detail screens, keeping paragraph breaks.
String annotationMarkdownPlain(String markdown) =>
    _annotationMarkdownPlain(markdown, collapseWhitespace: false);

md.Document _annotationMarkdownDocument() => md.Document(
  encodeHtml: false,
  extensionSet: md.ExtensionSet.gitHubFlavored,
  inlineSyntaxes: [_UnderlineSyntax()],
);

/// Markdown → Quill Delta for the annotation editor.
Delta annotationMarkdownToDelta(String markdown) => MarkdownToDelta(
  markdownDocument: _annotationMarkdownDocument(),
  customElementToInlineAttribute: {
    'u': _underlineAttrs,
    'ins': _underlineAttrs,
  },
).convert(markdown);

/// Quill Delta → Markdown for storage. Underline is `++text++`.
String annotationDeltaToMarkdown(Delta delta) => DeltaToMarkdown(
  customTextAttrsHandlers: {
    Attribute.underline.key: CustomAttributeHandler(
      beforeContent: (attribute, node, output) {
        if (node.previous?.style.containsKey(attribute.key) != true) {
          output.write('++');
        }
      },
      afterContent: (attribute, node, output) {
        if (node.next?.style.containsKey(attribute.key) != true) {
          output.write('++');
        }
      },
    ),
  },
).convert(delta);

/// Serializes a Quill document to trimmed Markdown for the API.
String annotationMarkdownFromDocument(Document document) =>
    annotationDeltaToMarkdown(document.toDelta()).trim();

List<Attribute<dynamic>> _underlineAttrs(md.Element _) => [Attribute.underline];

String _annotationMarkdownPlain(
  String markdown, {
  required bool collapseWhitespace,
}) {
  final text = markdown.trim();
  if (text.isEmpty) return '';

  final plain = Document.fromDelta(
    annotationMarkdownToDelta(text),
  ).toPlainText().trimRight();
  if (collapseWhitespace) {
    return plain.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
  return plain
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// `++text++` → `<u>`, requiring a two-plus delimiter run so a lone `+` stays
/// literal (and `1 + 1` is not underlined).
class _UnderlineSyntax extends md.DelimiterSyntax {
  _UnderlineSyntax()
    : super(
        r'\++',
        requiresDelimiterRun: true,
        allowIntraWord: true,
        startCharacter: 0x2B,
        tags: [md.DelimiterTag('u', 2)],
      );
}
