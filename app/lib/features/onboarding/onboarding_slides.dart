import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/features/onboarding/onboarding_slide.dart';
import 'package:readendar/features/onboarding/widgets/onboarding_heroes.dart';

/// The ordered first-run tour: a brand welcome, then the headline features a new
/// reader should meet at a glance: bring your library, plan your reads, see the
/// calendar, capture your quotes, and a closing "and so much more" recap
/// (roulette, widgets, stats, reading chapter, reminders)
/// that hints at the depth beyond the tour before bridging into the rest of
/// onboarding.
List<OnboardingSlide> buildOnboardingSlides(AppL10n l) => [
  OnboardingSlide(
    accent: ReadendarTokens.periwinkle500,
    icon: LucideIcons.bookMarked,
    title: l.tourWelcomeTitle,
    subtitle: l.tourWelcomeSubtitle,
    heroBuilder: (e) =>
        WelcomeHero(entrance: e, accent: ReadendarTokens.periwinkle500),
  ),
  OnboardingSlide(
    accent: ReadendarTokens.wine400,
    icon: LucideIcons.libraryBig,
    title: l.tourLibraryTitle,
    subtitle: l.tourLibrarySubtitle,
    heroBuilder: (e) =>
        LibraryHero(entrance: e, accent: ReadendarTokens.wine400),
  ),
  OnboardingSlide(
    accent: ReadendarTokens.teal500,
    icon: LucideIcons.calendarRange,
    title: l.tourPlannerTitle,
    subtitle: l.tourPlannerSubtitle,
    heroBuilder: (e) =>
        PlannerHero(entrance: e, accent: ReadendarTokens.teal500),
  ),
  OnboardingSlide(
    accent: ReadendarTokens.sage500,
    icon: LucideIcons.calendar,
    title: l.tourCalendarTitle,
    subtitle: l.tourCalendarSubtitle,
    heroBuilder: (e) =>
        CalendarHero(entrance: e, accent: ReadendarTokens.sage500),
  ),
  OnboardingSlide(
    accent: ReadendarTokens.periwinkle600,
    icon: LucideIcons.quote,
    title: l.tourQuotesTitle,
    subtitle: l.tourQuotesSubtitle,
    heroBuilder: (e) =>
        QuotesHero(entrance: e, accent: ReadendarTokens.periwinkle600),
  ),
  OnboardingSlide(
    accent: ReadendarTokens.periwinkle500,
    icon: LucideIcons.sparkles,
    title: l.tourMoreTitle,
    subtitle: l.tourMoreSubtitle,
    heroBuilder: (e) =>
        MoreHero(entrance: e, accent: ReadendarTokens.periwinkle500),
  ),
];
