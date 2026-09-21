import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/theme_catalog.dart';

String readendarThemeLabel(AppL10n l, ReadendarThemeId id) => switch (id) {
  ReadendarThemeId.original => l.themeOriginal,
  ReadendarThemeId.jade => l.themeJade,
  ReadendarThemeId.celestial => l.themeCelestial,
  ReadendarThemeId.ocean => l.themeOcean,
  ReadendarThemeId.noir => l.themeNoir,
  ReadendarThemeId.sapphire => l.themeSapphire,
  ReadendarThemeId.velvet => l.themeVelvet,
  ReadendarThemeId.aurora => l.themeAurora,
  ReadendarThemeId.arcade => l.themeArcade,
  ReadendarThemeId.pop => l.themePop,
  ReadendarThemeId.ethereal => l.themeEthereal,
  ReadendarThemeId.stormbound => l.themeStormbound,
  ReadendarThemeId.evercourt => l.themeEvercourt,
  ReadendarThemeId.neonMoon => l.themeNeonMoon,
  ReadendarThemeId.trail => l.themeTrail,
  ReadendarThemeId.serpents => l.themeSerpents,
  ReadendarThemeId.thornCrown => l.themeThornCrown,
  ReadendarThemeId.iridescent => l.themeIridescent,
  ReadendarThemeId.lastLight => l.themeLastLight,
};
