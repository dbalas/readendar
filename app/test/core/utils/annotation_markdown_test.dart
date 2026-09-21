import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/annotation_markdown.dart';

void main() {
  test('annotationMarkdownPreview strips markdown escapes like the editor', () {
    expect(annotationMarkdownPreview(r'\*not bold\*'), '*not bold*');
    expect(
      annotationMarkdownPreview('**bold** and \\*literal\\*'),
      'bold and *literal*',
    );
  });

  test('annotationMarkdownPreview collapses whitespace for list rows', () {
    expect(
      annotationMarkdownPreview('**Hello**\n\nworld\n- item'),
      'Hello world item',
    );
  });

  test('annotationMarkdownPlain keeps line breaks for full display', () {
    expect(
      annotationMarkdownPlain('**Hello**\n\nworld\n\nmore'),
      'Hello\nworld\nmore',
    );
  });

  test('underline survives the editor Markdown round-trip', () {
    final saved = annotationMarkdownFromDocument(
      Document.fromDelta(
        Delta()
          ..insert('hello', Attribute.underline.toJson())
          ..insert('\n'),
      ),
    );
    expect(saved, contains('++hello++'));
    expect(saved, isNot(contains('**')));

    final reloaded = annotationMarkdownToDelta(saved);
    expect(
      reloaded.toList().any(
        (op) => op.data == 'hello' && op.attributes?['underline'] == true,
      ),
      isTrue,
    );
    expect(
      annotationMarkdownFromDocument(Document.fromDelta(reloaded)),
      contains('++hello++'),
    );
  });

  test('underline can nest with bold without leaking markers', () {
    final saved = annotationMarkdownFromDocument(
      Document.fromDelta(
        Delta()
          ..insert('hello', {
            ...Attribute.bold.toJson(),
            ...Attribute.underline.toJson(),
          })
          ..insert('\n'),
      ),
    );
    expect(saved, contains('++hello++'));
    expect(saved, contains('**'));

    final reloaded = annotationMarkdownToDelta(saved).toList();
    expect(
      reloaded.any(
        (op) =>
            op.data == 'hello' &&
            op.attributes?['underline'] == true &&
            op.attributes?['bold'] == true,
      ),
      isTrue,
    );
  });

  test('preview strips underline markers', () {
    expect(annotationMarkdownPreview('see ++this++ word'), 'see this word');
  });

  test('double-underscore stays bold, not underline', () {
    final ops = annotationMarkdownToDelta('__hello__').toList();
    expect(
      ops.any((op) => op.data == 'hello' && op.attributes?['bold'] == true),
      isTrue,
    );
    expect(
      ops.any((op) => op.attributes?['underline'] == true),
      isFalse,
    );
  });

  group('toolbar formats survive Markdown round-trip', () {
    test('bold', () {
      expect(
        _hasInline(_roundTrip(_inline('hello', Attribute.bold)), 'hello', 'bold', true),
        isTrue,
      );
    });

    test('italic', () {
      expect(
        _hasInline(
          _roundTrip(_inline('hello', Attribute.italic)),
          'hello',
          'italic',
          true,
        ),
        isTrue,
      );
    });

    test('strike-through', () {
      expect(
        _hasInline(
          _roundTrip(_inline('hello', Attribute.strikeThrough)),
          'hello',
          'strike',
          true,
        ),
        isTrue,
      );
    });

    test('link', () {
      const href = 'https://readendar.app';
      expect(
        _hasInline(
          _roundTrip(_inline('hello', LinkAttribute(href))),
          'hello',
          'link',
          href,
        ),
        isTrue,
      );
    });

    test('heading 1', () {
      expect(_hasLine(_roundTrip(_block('Title', Attribute.h1)), 'header', 1), isTrue);
    });

    test('heading 2', () {
      expect(_hasLine(_roundTrip(_block('Title', Attribute.h2)), 'header', 2), isTrue);
    });

    test('heading 3', () {
      expect(_hasLine(_roundTrip(_block('Title', Attribute.h3)), 'header', 3), isTrue);
    });

    test('bullet list', () {
      expect(_hasLine(_roundTrip(_block('item', Attribute.ul)), 'list', 'bullet'), isTrue);
    });

    test('ordered list', () {
      expect(
        _hasLine(_roundTrip(_block('item', Attribute.ol)), 'list', 'ordered'),
        isTrue,
      );
    });

    test('block quote', () {
      expect(
        _hasLine(_roundTrip(_block('quote', Attribute.blockQuote)), 'blockquote', true),
        isTrue,
      );
    });
  });
}

Delta _inline(String text, Attribute<dynamic> attr) =>
    Delta()
      ..insert(text, attr.toJson())
      ..insert('\n');

Delta _block(String text, Attribute<dynamic> attr) =>
    Delta()
      ..insert(text)
      ..insert('\n', attr.toJson());

Delta _roundTrip(Delta input) => annotationMarkdownToDelta(
  annotationMarkdownFromDocument(Document.fromDelta(input)),
);

bool _hasInline(Delta delta, String text, String key, Object? value) =>
    delta.toList().any(
      (op) => op.data == text && op.attributes?[key] == value,
    );

bool _hasLine(Delta delta, String key, Object? value) => delta.toList().any((op) {
  final data = op.data;
  if (data is! String || !data.contains('\n')) return false;
  return op.attributes?[key] == value;
});

