import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/event_icon.dart';
import 'package:readendar/core/widgets/rd_date_picker.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/features/plan/domain/plan_models.dart';

/// Uniform vertical rhythm for the wizard form.
const double kPlanWizardFieldGap = 14;
const double kPlanWizardSectionGap = 24;

const int kPlanWizardStepCount = 3;

/// Multi-step plan form: goal → agenda → options. Edits a draft only; the
/// parent applies it on Continue (last step), then shows the Events preview as
/// the next linear step.
class PlanWizardForm extends StatelessWidget {
  const PlanWizardForm({
    required this.step,
    required this.draft,
    required this.totalCtrl,
    required this.startUnitCtrl,
    required this.perDayCtrl,
    required this.onDraftChanged,
    required this.onUnitChanged,
    required this.onModeChanged,
    this.onPickAnchorEvent,
    super.key,
  });

  final int step;
  final PlanInputs draft;
  final TextEditingController totalCtrl;
  final TextEditingController startUnitCtrl;
  final TextEditingController perDayCtrl;
  final ValueChanged<PlanInputs> onDraftChanged;
  final ValueChanged<PlanUnit> onUnitChanged;
  final ValueChanged<PlanMode> onModeChanged;
  final VoidCallback? onPickAnchorEvent;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.planWizardStepOf(step + 1, kPlanWizardStepCount),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.colors.fg3,
          ),
        ),
        const SizedBox(height: 8),
        PlanWizardStepDots(step: step, total: kPlanWizardStepCount),
        const SizedBox(height: kPlanWizardFieldGap),
        switch (step) {
          0 => _GoalStep(draft: draft, onModeChanged: onModeChanged),
          1 => _AgendaStep(
            draft: draft,
            totalCtrl: totalCtrl,
            startUnitCtrl: startUnitCtrl,
            perDayCtrl: perDayCtrl,
            onDraftChanged: onDraftChanged,
            onUnitChanged: onUnitChanged,
            onPickAnchorEvent: onPickAnchorEvent,
          ),
          _ => _OptionsStep(
            draft: draft,
            onDraftChanged: onDraftChanged,
          ),
        },
      ],
    );
  }
}

/// Compact 3-segment progress under the step label.
class PlanWizardStepDots extends StatelessWidget {
  const PlanWizardStepDots({
    required this.step,
    required this.total,
    super.key,
  });

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: AppL10n.of(context).planWizardStepOf(step + 1, total),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == step ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: i <= step ? c.accent : c.line,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalStep extends StatelessWidget {
  const _GoalStep({required this.draft, required this.onModeChanged});

  final PlanInputs draft;
  final ValueChanged<PlanMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.planWizardGoalTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: kPlanWizardSectionGap),
        _ModeChoiceCard(
          selected: draft.mode == PlanMode.pace,
          title: l.planModePace,
          subtitle: l.planModePaceSubtitle,
          onTap: () {
            if (draft.mode != PlanMode.pace) {
              unawaited(RdHaptics.selection());
            }
            onModeChanged(PlanMode.pace);
          },
        ),
        const SizedBox(height: kPlanWizardFieldGap),
        _ModeChoiceCard(
          selected: draft.mode == PlanMode.deadline,
          title: l.planModeDeadline,
          subtitle: l.planModeDeadlineSubtitle,
          onTap: () {
            if (draft.mode != PlanMode.deadline) {
              unawaited(RdHaptics.selection());
            }
            onModeChanged(PlanMode.deadline);
          },
        ),
        const SizedBox(height: kPlanWizardFieldGap),
        _ModeChoiceCard(
          selected: draft.mode == PlanMode.beforeEvent,
          title: l.planModeBeforeEvent,
          subtitle: l.planModeBeforeEventSubtitle,
          onTap: () {
            if (draft.mode != PlanMode.beforeEvent) {
              unawaited(RdHaptics.selection());
            }
            onModeChanged(PlanMode.beforeEvent);
          },
        ),
      ],
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  const _ModeChoiceCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? c.accentSoftBg : c.surface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              // Fixed 2px so selection does not shift layout.
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: 2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected ? c.accentSoftFg : c.fg1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 13, color: c.fg3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 22,
                  color: selected ? c.accent : c.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgendaStep extends StatelessWidget {
  const _AgendaStep({
    required this.draft,
    required this.totalCtrl,
    required this.startUnitCtrl,
    required this.perDayCtrl,
    required this.onDraftChanged,
    required this.onUnitChanged,
    this.onPickAnchorEvent,
  });

  final PlanInputs draft;
  final TextEditingController totalCtrl;
  final TextEditingController startUnitCtrl;
  final TextEditingController perDayCtrl;
  final ValueChanged<PlanInputs> onDraftChanged;
  final ValueChanged<PlanUnit> onUnitChanged;
  final VoidCallback? onPickAnchorEvent;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final isCh = draft.unit == PlanUnit.chapters;
    final ml = MaterialLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Book first: unit choice reseeds totals / already-read / pace.
        PlanSectionLabel(l.planSectionBook),
        Row(
          children: [
            Expanded(
              child: _UnitBlock(
                selected: draft.unit == PlanUnit.pages,
                label: l.planUnitPages,
                icon: LucideIcons.fileText,
                onTap: () {
                  if (draft.unit == PlanUnit.pages) return;
                  unawaited(RdHaptics.selection());
                  onUnitChanged(PlanUnit.pages);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _UnitBlock(
                selected: draft.unit == PlanUnit.chapters,
                label: l.planUnitChapters,
                icon: LucideIcons.bookmark,
                onTap: () {
                  if (draft.unit == PlanUnit.chapters) return;
                  unawaited(RdHaptics.selection());
                  onUnitChanged(PlanUnit.chapters);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: kPlanWizardFieldGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlanNumField(
                controller: startUnitCtrl,
                label: isCh
                    ? l.planAlreadyReadChapters
                    : l.planAlreadyReadPages,
                onChanged: (v) =>
                    onDraftChanged(draft.copyWith(startUnit: v ?? 0)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PlanNumField(
                controller: totalCtrl,
                label: isCh ? l.planTotalChapters : l.planTotalPages,
                required: true,
                onChanged: (v) => onDraftChanged(draft.copyWith(total: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: kPlanWizardSectionGap),
        PlanSectionLabel(l.planSectionSchedule),
        if (draft.mode == PlanMode.pace) ...[
          PlanDateField(
            label: l.planStart,
            required: true,
            value: draft.startDate,
            onPick: (d) => onDraftChanged(draft.copyWith(startDate: d)),
          ),
          const SizedBox(height: kPlanWizardFieldGap),
          PlanNumField(
            controller: perDayCtrl,
            label: l.planPace,
            required: true,
            suffix: isCh ? l.planPerDayChapters : l.planPerDayPages,
            onChanged: (v) => onDraftChanged(draft.copyWith(perDay: v)),
          ),
        ] else if (draft.mode == PlanMode.beforeEvent) ...[
          PlanDateField(
            label: l.planStart,
            required: true,
            value: draft.startDate,
            onPick: (d) => onDraftChanged(draft.copyWith(startDate: d)),
          ),
          const SizedBox(height: kPlanWizardFieldGap),
          RdFormSelectField(
            label: l.planAnchorEvent,
            required: true,
            valueText: () {
              final end = draft.endDate;
              if (end == null) return '';
              final date = ml.formatShortDate(end);
              final title = draft.anchorEventTitle?.trim();
              if (title == null || title.isEmpty) return date;
              return '$title · $date';
            }(),
            hint: l.planPickEventCta,
            onTap: onPickAnchorEvent,
          ),
        ] else ...[
          PlanDateField(
            label: l.planStart,
            required: true,
            value: draft.startDate,
            onPick: (d) => onDraftChanged(draft.copyWith(startDate: d)),
          ),
          const SizedBox(height: kPlanWizardFieldGap),
          PlanDateField(
            label: l.planDeadline,
            required: true,
            value: draft.endDate,
            onPick: (d) => onDraftChanged(draft.copyWith(endDate: d)),
          ),
        ],
        const SizedBox(height: kPlanWizardSectionGap),
        PlanSectionLabel(l.planReadingDays),
        PlanWeekdayChips(
          excluded: draft.excludedWeekdays,
          onToggle: (wd) {
            unawaited(RdHaptics.selection());
            final next = {...draft.excludedWeekdays};
            next.contains(wd) ? next.remove(wd) : next.add(wd);
            onDraftChanged(draft.copyWith(excludedWeekdays: next));
          },
        ),
      ],
    );
  }
}

class _UnitBlock extends StatelessWidget {
  const _UnitBlock({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? c.accentSoftBg : c.surface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? c.accentSoftFg : c.fg3,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: selected ? c.accentSoftFg : c.fg1,
                    ),
                  ),
                ),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 18,
                  color: selected ? c.accent : c.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionsStep extends StatelessWidget {
  const _OptionsStep({
    required this.draft,
    required this.onDraftChanged,
  });

  final PlanInputs draft;
  final ValueChanged<PlanInputs> onDraftChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final helpStyle = TextStyle(fontSize: 12.5, color: context.colors.fg3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PlanSectionLabel(l.planSectionBookends),
        _ToggleBlock(
          selected: draft.includeStart,
          leading: const EventIcon(type: EventType.start, size: 18),
          label: l.planIncludeStart,
          onTap: () {
            unawaited(RdHaptics.selection());
            onDraftChanged(draft.copyWith(includeStart: !draft.includeStart));
          },
        ),
        const SizedBox(height: 10),
        _ToggleBlock(
          selected: draft.includeFinish,
          leading: const EventIcon(type: EventType.finish, size: 18),
          label: draft.mode.isDeadlineLike
              ? l.planIncludeDeadline
              : l.planIncludeFinish,
          onTap: () {
            unawaited(RdHaptics.selection());
            onDraftChanged(draft.copyWith(includeFinish: !draft.includeFinish));
          },
        ),
        // Reminders sit apart from bookends: same step, different concern.
        const SizedBox(height: kPlanWizardSectionGap),
        _ToggleBlock(
          selected: draft.remindersOn,
          leading: const Icon(LucideIcons.bell, size: 18),
          label: l.planReminders,
          onTap: () {
            unawaited(RdHaptics.selection());
            onDraftChanged(draft.copyWith(remindersOn: !draft.remindersOn));
          },
        ),
        const SizedBox(height: 8),
        Text(l.planRemindersHelp, style: helpStyle),
      ],
    );
  }
}

/// Selectable option block (replaces green switches).
class _ToggleBlock extends StatelessWidget {
  const _ToggleBlock({
    required this.selected,
    required this.leading,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final Widget leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? c.accentSoftBg : c.surface1,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? c.accent : c.line,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: selected ? c.accentSoftFg : c.fg1,
                    ),
                  ),
                ),
                Icon(
                  selected ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 20,
                  color: selected ? c.accent : c.line,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PlanSectionLabel extends StatelessWidget {
  const PlanSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: context.colors.fg3,
        ),
      ),
    );
  }
}

class PlanNumField extends StatelessWidget {
  const PlanNumField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
    this.helper,
    this.required = false,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<int?> onChanged;
  final String? suffix;
  final String? helper;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return RdTextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: RdFormFieldLabel.decoration(
        context,
        labelText: label,
        required: required,
        decoration: InputDecoration(
          suffixText: suffix,
          helperText: helper,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
      ),
      onChanged: (s) => onChanged(s.trim().isEmpty ? null : int.tryParse(s)),
    );
  }
}

class PlanDateField extends StatelessWidget {
  const PlanDateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.required = false,
    super.key,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final display = value == null
        ? ''
        : MaterialLocalizations.of(context).formatShortDate(value!);
    return RdFormSelectField(
      label: label,
      required: required,
      valueText: display,
      hint: l.planPickDate,
      leading: const Icon(LucideIcons.calendar, size: 18),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showRdDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) {
          unawaited(RdHaptics.selection());
          onPick(DateTime(picked.year, picked.month, picked.day));
        }
      },
    );
  }
}

class PlanWeekdayChips extends StatelessWidget {
  const PlanWeekdayChips({
    required this.excluded,
    required this.onToggle,
    super.key,
  });
  final Set<int> excluded;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final narrow = MaterialLocalizations.of(context).narrowWeekdays;
    final locale = Localizations.localeOf(context).toString();
    String fullName(int wd) =>
        DateFormat.EEEE(locale).format(DateTime(2024, 1, wd));
    const order = [1, 2, 3, 4, 5, 6, 7];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final wd in order)
          MergeSemantics(
            child: Semantics(
              selected: !excluded.contains(wd),
              label: fullName(wd),
              hint: l.planWeekdayToggleHint,
              child: _DayChip(
                label: narrow[wd % 7],
                active: !excluded.contains(wd),
                onTap: () => onToggle(wd),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? context.colors.accent : null,
                border: Border.all(
                  color: active ? context.colors.accent : context.colors.line,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? context.colors.fgOnAccent
                      : context.colors.fg3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
