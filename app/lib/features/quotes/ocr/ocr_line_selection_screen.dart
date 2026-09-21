import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/features/quotes/ocr/ocr_capture.dart';
import 'package:readendar/features/quotes/ocr/ocr_compose.dart';

/// The photographed page with the recognized lines overlaid: tap a line to
/// (de)select it, long-press and drag to sweep several, pinch to zoom.
/// Pops with the composed text, or null on cancel.
///
/// Coordinate mapping: the Stack is laid out at the image's intrinsic pixel
/// size inside a FittedBox, so OCR pixel-space bounding boxes are used
/// VERBATIM as positioned tap targets — Flutter's hit testing traverses the
/// scale transform, no manual math (and no EXIF drift by construction).
class OcrLineSelectionScreen extends StatefulWidget {
  const OcrLineSelectionScreen({required this.page, super.key});

  final OcrPage page;

  @override
  State<OcrLineSelectionScreen> createState() => _OcrLineSelectionScreenState();
}

class _OcrLineSelectionScreenState extends State<OcrLineSelectionScreen> {
  final Set<int> _selected = {};

  // Fat-finger tolerance around each line box, in image pixels (scaled with
  // the photo, so roughly constant on screen).
  double get _slop => widget.page.width * 0.012;

  void _toggle(int index) {
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _selectAt(Offset imagePoint) {
    for (final line in widget.page.lines) {
      if (line.rect.inflate(_slop).contains(imagePoint)) {
        if (_selected.add(line.index)) setState(() {});
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final c = context.colors;
    final page = widget.page;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l.quoteOcrTitle),
        actions: [
          if (_selected.isNotEmpty)
            RdIconButton(
              tooltip: l.quoteOcrClearSelection,
              icon: LucideIcons.eraser,
              onPressed: () => setState(_selected.clear),
            ),
          RdIconButton(
            tooltip: l.quoteOcrSelectAll,
            icon: LucideIcons.textSelect,
            onPressed: () => setState(
              () => _selected
                ..clear()
                ..addAll(page.lines.map((e) => e.index)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 6,
              child: Center(
                child: FittedBox(
                  child: SizedBox(
                    width: page.width,
                    height: page.height,
                    child: GestureDetector(
                      // Long-press + drag sweeps lines without fighting the
                      // InteractiveViewer pan gesture.
                      onLongPressStart: (d) => _selectAt(d.localPosition),
                      onLongPressMoveUpdate: (d) => _selectAt(d.localPosition),
                      child: Stack(
                        children: [
                          Image.file(
                            File(page.imagePath),
                            width: page.width,
                            height: page.height,
                            fit: BoxFit.fill,
                          ),
                          for (final line in page.lines)
                            Positioned.fromRect(
                              rect: line.rect.inflate(_slop),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _toggle(line.index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _selected.contains(line.index)
                                        ? c.accent.withValues(alpha: 0.35)
                                        : Colors.white.withValues(alpha: 0.06),
                                    border: Border.all(
                                      color: _selected.contains(line.index)
                                          ? c.accent
                                          : Colors.white.withValues(
                                              alpha: 0.35,
                                            ),
                                      width: page.width * 0.002 + 1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      page.width * 0.008,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? l.quoteOcrInstructions
                          : composeOcrSelection(page.lines, _selected),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  RdButton.primary(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                            composeOcrSelection(page.lines, _selected),
                          ),
                    icon: LucideIcons.check,
                    label: l.quoteOcrUseText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
