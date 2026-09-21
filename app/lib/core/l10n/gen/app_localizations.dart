import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('es')];

  /// Small badge marking a feature as in testing.
  ///
  /// In es, this message translates to:
  /// **'BETA'**
  String get betaBadge;

  /// No description provided for @reviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Reseña'**
  String get reviewTitle;

  /// No description provided for @reviewHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe una reseña…'**
  String get reviewHint;

  /// No description provided for @finishWithoutReview.
  ///
  /// In es, this message translates to:
  /// **'Terminar sin reseña'**
  String get finishWithoutReview;

  /// No description provided for @bookSectionExpand.
  ///
  /// In es, this message translates to:
  /// **'Mostrar libros'**
  String get bookSectionExpand;

  /// No description provided for @bookSectionCollapse.
  ///
  /// In es, this message translates to:
  /// **'Ocultar libros'**
  String get bookSectionCollapse;

  /// No description provided for @loadMore.
  ///
  /// In es, this message translates to:
  /// **'Cargar más'**
  String get loadMore;

  /// No description provided for @pushPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Activa los permisos de notificación para recibir avisos.'**
  String get pushPermissionDenied;

  /// No description provided for @pushTokenUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudo preparar el aviso de notificación.'**
  String get pushTokenUnavailable;

  /// No description provided for @bannerEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Personalizar banner'**
  String get bannerEditTitle;

  /// No description provided for @imageCropTitle.
  ///
  /// In es, this message translates to:
  /// **'Recortar imagen'**
  String get imageCropTitle;

  /// No description provided for @bannerCustomize.
  ///
  /// In es, this message translates to:
  /// **'Personalizar banner'**
  String get bannerCustomize;

  /// No description provided for @bannerSectionColors.
  ///
  /// In es, this message translates to:
  /// **'Colores y fondos'**
  String get bannerSectionColors;

  /// No description provided for @bannerSectionImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get bannerSectionImage;

  /// No description provided for @bannerChoosePhoto.
  ///
  /// In es, this message translates to:
  /// **'Elegir foto'**
  String get bannerChoosePhoto;

  /// No description provided for @bannerRemovePhoto.
  ///
  /// In es, this message translates to:
  /// **'Quitar foto'**
  String get bannerRemovePhoto;

  /// No description provided for @bannerReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get bannerReset;

  /// No description provided for @bannerPresetA11y.
  ///
  /// In es, this message translates to:
  /// **'Fondo {index}'**
  String bannerPresetA11y(int index);

  /// Application name
  ///
  /// In es, this message translates to:
  /// **'Readendar'**
  String get appName;

  /// No description provided for @tourSkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get tourSkip;

  /// No description provided for @tourNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente'**
  String get tourNext;

  /// No description provided for @tourGetStarted.
  ///
  /// In es, this message translates to:
  /// **'Empezar'**
  String get tourGetStarted;

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido a Readendar'**
  String get tourWelcomeTitle;

  /// No description provided for @tourWelcomeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tu vida lectora, perfectamente organizada.'**
  String get tourWelcomeSubtitle;

  /// No description provided for @tourCalendarTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu calendario de lectura'**
  String get tourCalendarTitle;

  /// No description provided for @tourCalendarSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Ve cada inicio, hito y fecha límite de un vistazo.'**
  String get tourCalendarSubtitle;

  /// No description provided for @tourPlannerTitle.
  ///
  /// In es, this message translates to:
  /// **'Planifica tus lecturas'**
  String get tourPlannerTitle;

  /// No description provided for @tourPlannerSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Nuestro asistente te crea un plan de lectura a tu ritmo, para cualquier libro.'**
  String get tourPlannerSubtitle;

  /// No description provided for @tourLibraryTitle.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca'**
  String get tourLibraryTitle;

  /// No description provided for @tourLibrarySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Importa tu biblioteca desde tus aplicaciones de lectura en segundos.'**
  String get tourLibrarySubtitle;

  /// No description provided for @tourQuotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Guarda cada línea y cada nota que no quieres olvidar'**
  String get tourQuotesTitle;

  /// No description provided for @tourQuotesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Notas, citas, teoría y preguntas. Escríbelas, díctalas o hazles una foto, y compártelas a tu manera.'**
  String get tourQuotesSubtitle;

  /// No description provided for @tourMoreTitle.
  ///
  /// In es, this message translates to:
  /// **'Y mucho más'**
  String get tourMoreTitle;

  /// No description provided for @tourMoreSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Widgets, estadísticas, ruleta, tu capítulo lector y recordatorios. Todo está aquí.'**
  String get tourMoreSubtitle;

  /// No description provided for @tourMoreRoulette.
  ///
  /// In es, this message translates to:
  /// **'Ruleta de lectura'**
  String get tourMoreRoulette;

  /// No description provided for @tourMoreWidgets.
  ///
  /// In es, this message translates to:
  /// **'Widgets'**
  String get tourMoreWidgets;

  /// No description provided for @tourMoreStats.
  ///
  /// In es, this message translates to:
  /// **'Estadísticas'**
  String get tourMoreStats;

  /// No description provided for @navHome.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get navHome;

  /// No description provided for @navLibrary.
  ///
  /// In es, this message translates to:
  /// **'Libros'**
  String get navLibrary;

  /// No description provided for @navCalendar.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get navCalendar;

  /// No description provided for @navYou.
  ///
  /// In es, this message translates to:
  /// **'Perfil'**
  String get navYou;

  /// Add-book form banner title when offering an upcoming release calendar event.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento de Lanzamiento'**
  String get exploreCatalogMatchOfferRelease;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @greetingMorning.
  ///
  /// In es, this message translates to:
  /// **'Buenos días, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In es, this message translates to:
  /// **'Buenas tardes, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In es, this message translates to:
  /// **'Buenas noches, {name}'**
  String greetingEvening(String name);

  /// No description provided for @sectionToday.
  ///
  /// In es, this message translates to:
  /// **'Hoy'**
  String get sectionToday;

  /// No description provided for @sectionReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo'**
  String get sectionReading;

  /// No description provided for @sectionEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get sectionEvents;

  /// No description provided for @sectionSynopsis.
  ///
  /// In es, this message translates to:
  /// **'Sinopsis'**
  String get sectionSynopsis;

  /// No description provided for @ratingLabel.
  ///
  /// In es, this message translates to:
  /// **'Valoración'**
  String get ratingLabel;

  /// No description provided for @ratingUnrated.
  ///
  /// In es, this message translates to:
  /// **'Sin valorar'**
  String get ratingUnrated;

  /// No description provided for @ratingClear.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get ratingClear;

  /// No description provided for @notesEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar notas'**
  String get notesEditTitle;

  /// No description provided for @notesHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe tus notas privadas…'**
  String get notesHint;

  /// No description provided for @notesPrivateHint.
  ///
  /// In es, this message translates to:
  /// **'Solo tú puedes ver esto.'**
  String get notesPrivateHint;

  /// No description provided for @emptyToday.
  ///
  /// In es, this message translates to:
  /// **'Día tranquilo. Sin eventos.'**
  String get emptyToday;

  /// No description provided for @emptyEvents.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay eventos para este libro. Añade un hito, una fecha límite o un fin de lectura.'**
  String get emptyEvents;

  /// No description provided for @homeMetricPending.
  ///
  /// In es, this message translates to:
  /// **'Pendientes'**
  String get homeMetricPending;

  /// No description provided for @homeMetricWanted.
  ///
  /// In es, this message translates to:
  /// **'Deseados'**
  String get homeMetricWanted;

  /// No description provided for @homeNoReading.
  ///
  /// In es, this message translates to:
  /// **'Aún no estás leyendo ninguno'**
  String get homeNoReading;

  /// No description provided for @homeStartReading.
  ///
  /// In es, this message translates to:
  /// **'Empezar a leer'**
  String get homeStartReading;

  /// No description provided for @homeTodayLabel.
  ///
  /// In es, this message translates to:
  /// **'hoy'**
  String get homeTodayLabel;

  /// No description provided for @homeTomorrowLabel.
  ///
  /// In es, this message translates to:
  /// **'mañana'**
  String get homeTomorrowLabel;

  /// No description provided for @homeInDays.
  ///
  /// In es, this message translates to:
  /// **'en {days} días'**
  String homeInDays(int days);

  /// No description provided for @libraryEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu biblioteca está vacía. Añade tu primer libro para empezar.'**
  String get libraryEmptyMessage;

  /// No description provided for @quickAddBook.
  ///
  /// In es, this message translates to:
  /// **'Añadir libro'**
  String get quickAddBook;

  /// No description provided for @statusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get statusPending;

  /// No description provided for @statusWanted.
  ///
  /// In es, this message translates to:
  /// **'Deseado'**
  String get statusWanted;

  /// No description provided for @statusReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo'**
  String get statusReading;

  /// No description provided for @statusRead.
  ///
  /// In es, this message translates to:
  /// **'Leído'**
  String get statusRead;

  /// No description provided for @statusAbandoned.
  ///
  /// In es, this message translates to:
  /// **'Abandonado'**
  String get statusAbandoned;

  /// No description provided for @statusLabel.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get statusLabel;

  /// No description provided for @statusHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de estados'**
  String get statusHistoryTitle;

  /// No description provided for @statusHistoryView.
  ///
  /// In es, this message translates to:
  /// **'Ver historial de estados'**
  String get statusHistoryView;

  /// No description provided for @statusHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay cambios de estado registrados.'**
  String get statusHistoryEmpty;

  /// No description provided for @statusHistoryDeletedAccount.
  ///
  /// In es, this message translates to:
  /// **'Cuenta eliminada'**
  String get statusHistoryDeletedAccount;

  /// No description provided for @statusHistoryBaseline.
  ///
  /// In es, this message translates to:
  /// **'Estado registrado al activar el historial'**
  String get statusHistoryBaseline;

  /// No description provided for @statusHistoryDateUpdated.
  ///
  /// In es, this message translates to:
  /// **'Fecha del estado actualizada'**
  String get statusHistoryDateUpdated;

  /// No description provided for @eventTypeStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get eventTypeStart;

  /// No description provided for @eventTypeFinish.
  ///
  /// In es, this message translates to:
  /// **'Fin'**
  String get eventTypeFinish;

  /// No description provided for @eventTypeAbandoned.
  ///
  /// In es, this message translates to:
  /// **'Abandono'**
  String get eventTypeAbandoned;

  /// No description provided for @eventTypeChapterMilestone.
  ///
  /// In es, this message translates to:
  /// **'Hito de capítulo'**
  String get eventTypeChapterMilestone;

  /// No description provided for @eventTypePageMilestone.
  ///
  /// In es, this message translates to:
  /// **'Hito de página'**
  String get eventTypePageMilestone;

  /// No description provided for @eventTypeDeadline.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite'**
  String get eventTypeDeadline;

  /// No description provided for @eventTypeBookReturn.
  ///
  /// In es, this message translates to:
  /// **'Devolución de libro'**
  String get eventTypeBookReturn;

  /// No description provided for @eventTypeRelease.
  ///
  /// In es, this message translates to:
  /// **'Lanzamiento'**
  String get eventTypeRelease;

  /// No description provided for @actionEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get actionDelete;

  /// No description provided for @actionCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get actionSave;

  /// No description provided for @actionConfirm.
  ///
  /// In es, this message translates to:
  /// **'Confirmar'**
  String get actionConfirm;

  /// No description provided for @actionMarkCompleted.
  ///
  /// In es, this message translates to:
  /// **'¡Completar!'**
  String get actionMarkCompleted;

  /// No description provided for @actionMarkUncompleted.
  ///
  /// In es, this message translates to:
  /// **'Reabrir'**
  String get actionMarkUncompleted;

  /// No description provided for @actionAddBook.
  ///
  /// In es, this message translates to:
  /// **'Añadir libro'**
  String get actionAddBook;

  /// No description provided for @actionAddEvent.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento'**
  String get actionAddEvent;

  /// No description provided for @actionUpdateProgress.
  ///
  /// In es, this message translates to:
  /// **'Actualizar progreso'**
  String get actionUpdateProgress;

  /// No description provided for @progressUpdatedToast.
  ///
  /// In es, this message translates to:
  /// **'Progreso actualizado'**
  String get progressUpdatedToast;

  /// No description provided for @actionNotNow.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get actionNotNow;

  /// No description provided for @actionShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get actionShare;

  /// No description provided for @bookShareMessage.
  ///
  /// In es, this message translates to:
  /// **'Mira {title} en Readendar: {url}'**
  String bookShareMessage(String title, String url);

  /// No description provided for @bookShareUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este libro no se puede compartir ahora'**
  String get bookShareUnavailable;

  /// No description provided for @actionReread.
  ///
  /// In es, this message translates to:
  /// **'Relectura'**
  String get actionReread;

  /// No description provided for @actionSeeMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más'**
  String get actionSeeMore;

  /// No description provided for @actionApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get actionApply;

  /// No description provided for @actionReset.
  ///
  /// In es, this message translates to:
  /// **'Restablecer'**
  String get actionReset;

  /// No description provided for @reminderAtTime.
  ///
  /// In es, this message translates to:
  /// **'En el momento del evento'**
  String get reminderAtTime;

  /// No description provided for @reminderMinutesPlural.
  ///
  /// In es, this message translates to:
  /// **'{n} min'**
  String reminderMinutesPlural(int n);

  /// No description provided for @reminderHoursPlural.
  ///
  /// In es, this message translates to:
  /// **'{n} h'**
  String reminderHoursPlural(int n);

  /// No description provided for @reminderDaysPlural.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{{n} día} other{{n} días}}'**
  String reminderDaysPlural(int n);

  /// No description provided for @reminderWeeksPlural.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{{n} semana} other{{n} semanas}}'**
  String reminderWeeksPlural(int n);

  /// No description provided for @sourceCamera.
  ///
  /// In es, this message translates to:
  /// **'Cámara'**
  String get sourceCamera;

  /// No description provided for @sourceGallery.
  ///
  /// In es, this message translates to:
  /// **'Galería'**
  String get sourceGallery;

  /// No description provided for @profileDisplayName.
  ///
  /// In es, this message translates to:
  /// **'Nombre visible'**
  String get profileDisplayName;

  /// Settings nav row + screen title for app behavior preferences
  ///
  /// In es, this message translates to:
  /// **'Comportamiento'**
  String get settingsAppBehaviorTitle;

  /// Short Settings row description for the app behavior screen
  ///
  /// In es, this message translates to:
  /// **'Automatizaciones y preferencias de la app'**
  String get settingsAppBehaviorSubtitle;

  /// Intro copy at the top of the app behavior settings screen
  ///
  /// In es, this message translates to:
  /// **'Opciones que cambian cómo se comporta Readendar al gestionar tu actividad.'**
  String get settingsAppBehaviorIntro;

  /// Settings switch: auto-create start/finish calendar events on status change
  ///
  /// In es, this message translates to:
  /// **'Eventos al cambiar estado'**
  String get settingsAutoStatusEventsTitle;

  /// First bullet: auto-create start event; **bold** key words
  ///
  /// In es, this message translates to:
  /// **'Evento de **inicio** al pasar a **Leyendo**.'**
  String get settingsAutoStatusEventsBulletStart;

  /// Second bullet: auto-create finish event; **bold** key words
  ///
  /// In es, this message translates to:
  /// **'Evento de **fin** al marcar como **Leído**.'**
  String get settingsAutoStatusEventsBulletFinish;

  /// No description provided for @profileAppearance.
  ///
  /// In es, this message translates to:
  /// **'Apariencia'**
  String get profileAppearance;

  /// No description provided for @profileNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get profileNotifications;

  /// No description provided for @profileEditAction.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditAction;

  /// No description provided for @profileEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar perfil'**
  String get profileEditTitle;

  /// No description provided for @profileTimezone.
  ///
  /// In es, this message translates to:
  /// **'Zona horaria'**
  String get profileTimezone;

  /// No description provided for @profileChooseTimezone.
  ///
  /// In es, this message translates to:
  /// **'Elegir zona horaria'**
  String get profileChooseTimezone;

  /// No description provided for @profileSearchTimezone.
  ///
  /// In es, this message translates to:
  /// **'Buscar zona horaria'**
  String get profileSearchTimezone;

  /// No description provided for @onboardingConsentLabel.
  ///
  /// In es, this message translates to:
  /// **'Acepto los términos de uso y confirmo que he leído la política de privacidad.'**
  String get onboardingConsentLabel;

  /// No description provided for @termsUpdateTitle.
  ///
  /// In es, this message translates to:
  /// **'Términos actualizados'**
  String get termsUpdateTitle;

  /// No description provided for @termsUpdateDescription.
  ///
  /// In es, this message translates to:
  /// **'Revisa los términos y la política de privacidad vigentes antes de continuar.'**
  String get termsUpdateDescription;

  /// No description provided for @termsUpdateAccept.
  ///
  /// In es, this message translates to:
  /// **'Aceptar y continuar'**
  String get termsUpdateAccept;

  /// No description provided for @legalTerms.
  ///
  /// In es, this message translates to:
  /// **'Términos de uso'**
  String get legalTerms;

  /// No description provided for @profileSaved.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados'**
  String get profileSaved;

  /// No description provided for @profileExportData.
  ///
  /// In es, this message translates to:
  /// **'Descargar mis datos'**
  String get profileExportData;

  /// No description provided for @profileExportHint.
  ///
  /// In es, this message translates to:
  /// **'Copia local de tus libros, eventos, notas y portadas.'**
  String get profileExportHint;

  /// No description provided for @profileExportInProgress.
  ///
  /// In es, this message translates to:
  /// **'Preparando tus datos…'**
  String get profileExportInProgress;

  /// No description provided for @profileExportTitle.
  ///
  /// In es, this message translates to:
  /// **'Exportación de datos de Readendar'**
  String get profileExportTitle;

  /// No description provided for @profilePrivacy.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get profilePrivacy;

  /// No description provided for @actionRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get actionRetry;

  /// No description provided for @actionSearch.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get actionSearch;

  /// No description provided for @actionClear.
  ///
  /// In es, this message translates to:
  /// **'Borrar'**
  String get actionClear;

  /// No description provided for @actionClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get actionClose;

  /// No description provided for @a11yCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get a11yCompleted;

  /// No description provided for @offlineBanner.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión: se muestran datos guardados'**
  String get offlineBanner;

  /// No description provided for @onboardingTitle.
  ///
  /// In es, this message translates to:
  /// **'Configura el perfil de lectura'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Nombre y zona horaria para tu biblioteca.'**
  String get onboardingSubtitle;

  /// No description provided for @onboardingSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar y empezar'**
  String get onboardingSave;

  /// No description provided for @appearanceLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get appearanceDark;

  /// No description provided for @appearanceSystem.
  ///
  /// In es, this message translates to:
  /// **'Sistema'**
  String get appearanceSystem;

  /// No description provided for @filtersTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filtersTitle;

  /// No description provided for @filterStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get filterStatus;

  /// No description provided for @filterDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get filterDate;

  /// No description provided for @filterEventType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de evento'**
  String get filterEventType;

  /// No description provided for @filterCompletion.
  ///
  /// In es, this message translates to:
  /// **'Finalización'**
  String get filterCompletion;

  /// No description provided for @filterCompletedOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo con finalización'**
  String get filterCompletedOnly;

  /// No description provided for @filterUncompletedOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo pendientes'**
  String get filterUncompletedOnly;

  /// No description provided for @filterSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en esta página'**
  String get filterSearchHint;

  /// No description provided for @filtersClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get filtersClear;

  /// No description provided for @calendarEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Eventos del mes'**
  String get calendarEventsTitle;

  /// No description provided for @calendarWeekEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Eventos de la semana'**
  String get calendarWeekEventsTitle;

  /// No description provided for @calendarMonthNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos este mes'**
  String get calendarMonthNoEvents;

  /// No description provided for @calendarWeekNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos esta semana'**
  String get calendarWeekNoEvents;

  /// No description provided for @calendarDayNoEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos este día'**
  String get calendarDayNoEvents;

  /// No description provided for @calendarViewMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get calendarViewMonth;

  /// No description provided for @calendarViewWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get calendarViewWeek;

  /// No description provided for @calendarViewDay.
  ///
  /// In es, this message translates to:
  /// **'Día'**
  String get calendarViewDay;

  /// No description provided for @calendarShowMap.
  ///
  /// In es, this message translates to:
  /// **'Ver calendario'**
  String get calendarShowMap;

  /// No description provided for @calendarShowList.
  ///
  /// In es, this message translates to:
  /// **'Ver lista'**
  String get calendarShowList;

  /// No description provided for @errorGeneric.
  ///
  /// In es, this message translates to:
  /// **'Algo ha ido mal. Inténtalo de nuevo.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión. Revisa la red.'**
  String get errorNetwork;

  /// No description provided for @errorUnauthorized.
  ///
  /// In es, this message translates to:
  /// **'Tu sesión ha expirado.'**
  String get errorUnauthorized;

  /// No description provided for @errorValidation.
  ///
  /// In es, this message translates to:
  /// **'Revisa los datos introducidos.'**
  String get errorValidation;

  /// No description provided for @errorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiadas peticiones. Espera un momento.'**
  String get errorRateLimited;

  /// No description provided for @errorRateLimitedSeconds.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{Demasiados intentos de acceso. Inténtalo de nuevo en 1 segundo.} other{Demasiados intentos de acceso. Inténtalo de nuevo en {n} segundos.}}'**
  String errorRateLimitedSeconds(int n);

  /// No description provided for @errorRateLimitedMinutes.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{Demasiados intentos de acceso. Inténtalo de nuevo en 1 minuto.} other{Demasiados intentos de acceso. Inténtalo de nuevo en {n} minutos.}}'**
  String errorRateLimitedMinutes(int n);

  /// No description provided for @errFieldRequired.
  ///
  /// In es, this message translates to:
  /// **'Campo requerido.'**
  String get errFieldRequired;

  /// No description provided for @errInvalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Introduce un correo válido.'**
  String get errInvalidEmail;

  /// No description provided for @authSignInTitle.
  ///
  /// In es, this message translates to:
  /// **'Accede o regístrate'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Escribe el correo y enviaremos un código. Si no hay cuenta, se creará al verificarlo.'**
  String get authSignInSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo electrónico'**
  String get authEmail;

  /// No description provided for @authEmailHint.
  ///
  /// In es, this message translates to:
  /// **'hola@correo.com'**
  String get authEmailHint;

  /// No description provided for @authSubmitSignIn.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get authSubmitSignIn;

  /// No description provided for @authMagicLinkSent.
  ///
  /// In es, this message translates to:
  /// **'Hemos enviado un código a {email}.'**
  String authMagicLinkSent(String email);

  /// No description provided for @authMagicLinkInstructions.
  ///
  /// In es, this message translates to:
  /// **'Escribe el código del correo o abre el enlace desde este dispositivo.'**
  String get authMagicLinkInstructions;

  /// No description provided for @authCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código'**
  String get authCodeTitle;

  /// No description provided for @authCodeSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Usa el código enviado a {email}.'**
  String authCodeSubtitle(String email);

  /// No description provided for @authCode.
  ///
  /// In es, this message translates to:
  /// **'Código'**
  String get authCode;

  /// No description provided for @authCodeHint.
  ///
  /// In es, this message translates to:
  /// **'ABC234XY'**
  String get authCodeHint;

  /// No description provided for @authCodeRequired.
  ///
  /// In es, this message translates to:
  /// **'Introduce el código.'**
  String get authCodeRequired;

  /// No description provided for @authVerifyCode.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get authVerifyCode;

  /// No description provided for @authChangeEmail.
  ///
  /// In es, this message translates to:
  /// **'Cambiar correo'**
  String get authChangeEmail;

  /// No description provided for @authResendCode.
  ///
  /// In es, this message translates to:
  /// **'Reenviar código'**
  String get authResendCode;

  /// No description provided for @authResendCodeCountdown.
  ///
  /// In es, this message translates to:
  /// **'Reenviar en {seconds}s'**
  String authResendCodeCountdown(int seconds);

  /// No description provided for @authWaitCountdown.
  ///
  /// In es, this message translates to:
  /// **'Espera {time}'**
  String authWaitCountdown(String time);

  /// No description provided for @authPasswordlessNote.
  ///
  /// In es, this message translates to:
  /// **'El mismo código sirve para entrar o crear la cuenta, según el correo.'**
  String get authPasswordlessNote;

  /// No description provided for @authDevCodeTitle.
  ///
  /// In es, this message translates to:
  /// **'Modo dev: código devuelto por el backend.'**
  String get authDevCodeTitle;

  /// No description provided for @authDevCodeAction.
  ///
  /// In es, this message translates to:
  /// **'Continuar con este código'**
  String get authDevCodeAction;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authSignInWithApple.
  ///
  /// In es, this message translates to:
  /// **'Continuar con Apple'**
  String get authSignInWithApple;

  /// No description provided for @magicLinkInvalid.
  ///
  /// In es, this message translates to:
  /// **'El enlace de acceso no es válido o ha caducado. Solicita uno nuevo aquí.'**
  String get magicLinkInvalid;

  /// No description provided for @loading.
  ///
  /// In es, this message translates to:
  /// **'Cargando…'**
  String get loading;

  /// No description provided for @retry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get retry;

  /// No description provided for @copied.
  ///
  /// In es, this message translates to:
  /// **'En el portapapeles.'**
  String get copied;

  /// No description provided for @searchTitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar libros'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por título o autor'**
  String get searchHint;

  /// No description provided for @searchEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe un título o autor para buscar.'**
  String get searchEmptyHint;

  /// No description provided for @searchNoResults.
  ///
  /// In es, this message translates to:
  /// **'Sin resultados.'**
  String get searchNoResults;

  /// No description provided for @searchSearching.
  ///
  /// In es, this message translates to:
  /// **'Buscando libros…'**
  String get searchSearching;

  /// No description provided for @searchCreateManually.
  ///
  /// In es, this message translates to:
  /// **'Añadir manualmente'**
  String get searchCreateManually;

  /// No description provided for @searchScanIsbn.
  ///
  /// In es, this message translates to:
  /// **'Escanear ISBN'**
  String get searchScanIsbn;

  /// No description provided for @scanIsbnTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escanear ISBN'**
  String get scanIsbnTooltip;

  /// No description provided for @scanIsbnTitle.
  ///
  /// In es, this message translates to:
  /// **'Escanear código'**
  String get scanIsbnTitle;

  /// No description provided for @scanIsbnInstruction.
  ///
  /// In es, this message translates to:
  /// **'Apunta la cámara al código de barras del libro'**
  String get scanIsbnInstruction;

  /// No description provided for @scanIsbnTorch.
  ///
  /// In es, this message translates to:
  /// **'Flash'**
  String get scanIsbnTorch;

  /// No description provided for @scanIsbnManualEntry.
  ///
  /// In es, this message translates to:
  /// **'Introducir ISBN manualmente'**
  String get scanIsbnManualEntry;

  /// No description provided for @scanIsbnNotABook.
  ///
  /// In es, this message translates to:
  /// **'Ese no es un código de barras de libro'**
  String get scanIsbnNotABook;

  /// No description provided for @scanIsbnManualHint.
  ///
  /// In es, this message translates to:
  /// **'978…'**
  String get scanIsbnManualHint;

  /// No description provided for @scanIsbnManualInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un ISBN válido.'**
  String get scanIsbnManualInvalid;

  /// No description provided for @scanPermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Se necesita acceso a la cámara'**
  String get scanPermissionTitle;

  /// No description provided for @scanPermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Readendar necesita acceso a la cámara para escanear códigos de barras de libros. Puedes activarlo en Ajustes.'**
  String get scanPermissionBody;

  /// No description provided for @scanPermissionOpenSettings.
  ///
  /// In es, this message translates to:
  /// **'Abrir ajustes'**
  String get scanPermissionOpenSettings;

  /// No description provided for @cameraPermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Readendar necesita acceso a la cámara para hacer una foto. Puedes activarlo en Ajustes.'**
  String get cameraPermissionBody;

  /// No description provided for @photosPermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Se necesita acceso a las fotos'**
  String get photosPermissionTitle;

  /// No description provided for @photosPermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Readendar necesita acceso a tus fotos para buscar libros en una imagen. Puedes activarlo en Ajustes.'**
  String get photosPermissionBody;

  /// No description provided for @bookDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle'**
  String get bookDetailTitle;

  /// No description provided for @bookEditInfo.
  ///
  /// In es, this message translates to:
  /// **'Editar libro'**
  String get bookEditInfo;

  /// No description provided for @bookConfirmDelete.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este libro de la biblioteca?'**
  String get bookConfirmDelete;

  /// No description provided for @bookDeleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'Libro eliminado de tu biblioteca'**
  String get bookDeleteSuccess;

  /// No description provided for @rereadConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres releerlo?'**
  String get rereadConfirmTitle;

  /// No description provided for @rereadConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Añadiremos una copia nueva a Pendientes con la misma información del libro. Empezarás de cero: el progreso y los eventos se quedan en el original.'**
  String get rereadConfirmBody;

  /// No description provided for @bookTitleRequired.
  ///
  /// In es, this message translates to:
  /// **'Añade un título.'**
  String get bookTitleRequired;

  /// No description provided for @bookAuthorsRequired.
  ///
  /// In es, this message translates to:
  /// **'Añade al menos un autor.'**
  String get bookAuthorsRequired;

  /// No description provided for @bookPagesInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un número de páginas válido.'**
  String get bookPagesInvalid;

  /// No description provided for @bookOptionalHint.
  ///
  /// In es, this message translates to:
  /// **'Opcional'**
  String get bookOptionalHint;

  /// No description provided for @rereadSuccess.
  ///
  /// In es, this message translates to:
  /// **'Relectura: «{title}»'**
  String rereadSuccess(String title);

  /// No description provided for @metaTitle.
  ///
  /// In es, this message translates to:
  /// **'Título'**
  String get metaTitle;

  /// No description provided for @metaAuthors.
  ///
  /// In es, this message translates to:
  /// **'Autor'**
  String get metaAuthors;

  /// No description provided for @metaAuthorsHint.
  ///
  /// In es, this message translates to:
  /// **'Separar nombres con comas'**
  String get metaAuthorsHint;

  /// No description provided for @metaIsbn.
  ///
  /// In es, this message translates to:
  /// **'ISBN'**
  String get metaIsbn;

  /// No description provided for @metaPublisher.
  ///
  /// In es, this message translates to:
  /// **'Editorial'**
  String get metaPublisher;

  /// No description provided for @metaLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma'**
  String get metaLanguage;

  /// No description provided for @bookLanguageName.
  ///
  /// In es, this message translates to:
  /// **'{language, select, es{Español} ca{Catalán} en{Inglés} fr{Francés} de{Alemán} it{Italiano} pt{Portugués} nl{Neerlandés} pl{Polaco} tr{Turco} sv{Sueco} da{Danés} nb{Noruego bokmål} fi{Finés} eu{Euskera} gl{Gallego} ru{Ruso} uk{Ucraniano} be{Bielorruso} cs{Checo} sk{Eslovaco} hu{Húngaro} ro{Rumano} bg{Búlgaro} hr{Croata} sr{Serbio} sl{Esloveno} mk{Macedonio} sq{Albanés} et{Estonio} lt{Lituano} lv{Letón} el{Griego} la{Latín} is{Islandés} ga{Irlandés} cy{Galés} ja{Japonés} zh{Chino} ko{Coreano} ar{Árabe} he{Hebreo} hi{Hindi} bn{Bengalí} ur{Urdu} fa{Persa} th{Tailandés} vi{Vietnamita} id{Indonesio} ms{Malayo} ta{Tamil} tl{Filipino} sw{Suajili} af{Afrikáans} eo{Esperanto} ka{Georgiano} hy{Armenio} mn{Mongol} other{{language}}}'**
  String bookLanguageName(String language);

  /// No description provided for @metaFormat.
  ///
  /// In es, this message translates to:
  /// **'Formato'**
  String get metaFormat;

  /// No description provided for @bookFormatPhysical.
  ///
  /// In es, this message translates to:
  /// **'Físico'**
  String get bookFormatPhysical;

  /// No description provided for @bookFormatEbook.
  ///
  /// In es, this message translates to:
  /// **'Ebook'**
  String get bookFormatEbook;

  /// No description provided for @bookFormatAudiobook.
  ///
  /// In es, this message translates to:
  /// **'Audiolibro'**
  String get bookFormatAudiobook;

  /// No description provided for @bookFormatOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get bookFormatOther;

  /// No description provided for @metaCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get metaCategories;

  /// No description provided for @metaEdition.
  ///
  /// In es, this message translates to:
  /// **'Edición'**
  String get metaEdition;

  /// No description provided for @metaBinding.
  ///
  /// In es, this message translates to:
  /// **'Encuadernación'**
  String get metaBinding;

  /// No description provided for @bookBindingName.
  ///
  /// In es, this message translates to:
  /// **'{binding, select, hardcover{Tapa dura} paperback{Tapa blanda} massMarket{Bolsillo} tradePaperback{Rústica} boardBook{Libro de cartón} library{Encuadernación de biblioteca} turtleback{Turtleback} spiral{Espiral} leather{Piel} imitationLeather{Piel sintética} flexibound{Flexible} looseLeaf{Hojas sueltas} unbound{Sin encuadernar} comic{Cómic} kindle{Kindle} ebook{Ebook} audiobook{Audiolibro} unknownBinding{Encuadernación desconocida} other{{binding}}}'**
  String bookBindingName(String binding);

  /// No description provided for @metaDimensions.
  ///
  /// In es, this message translates to:
  /// **'Dimensiones'**
  String get metaDimensions;

  /// No description provided for @metaMsrp.
  ///
  /// In es, this message translates to:
  /// **'Precio de lista'**
  String get metaMsrp;

  /// No description provided for @metaMsrpCurrency.
  ///
  /// In es, this message translates to:
  /// **'Moneda'**
  String get metaMsrpCurrency;

  /// No description provided for @sectionExcerpt.
  ///
  /// In es, this message translates to:
  /// **'Fragmento'**
  String get sectionExcerpt;

  /// No description provided for @metaPages.
  ///
  /// In es, this message translates to:
  /// **'Páginas'**
  String get metaPages;

  /// No description provided for @metaChapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos'**
  String get metaChapters;

  /// No description provided for @metaPagesTotal.
  ///
  /// In es, this message translates to:
  /// **'Páginas totales'**
  String get metaPagesTotal;

  /// No description provided for @metaChaptersTotal.
  ///
  /// In es, this message translates to:
  /// **'Capítulos totales'**
  String get metaChaptersTotal;

  /// No description provided for @metaSynopsis.
  ///
  /// In es, this message translates to:
  /// **'Sinopsis'**
  String get metaSynopsis;

  /// No description provided for @progressCurrentPageLabel.
  ///
  /// In es, this message translates to:
  /// **'Página actual'**
  String get progressCurrentPageLabel;

  /// No description provided for @progressCurrentLabel.
  ///
  /// In es, this message translates to:
  /// **'Progreso actual'**
  String get progressCurrentLabel;

  /// No description provided for @bookSectionDetails.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get bookSectionDetails;

  /// No description provided for @bookSectionTracking.
  ///
  /// In es, this message translates to:
  /// **'Seguimiento'**
  String get bookSectionTracking;

  /// No description provided for @bookSectionMore.
  ///
  /// In es, this message translates to:
  /// **'Detalles'**
  String get bookSectionMore;

  /// No description provided for @progressTitle.
  ///
  /// In es, this message translates to:
  /// **'Progreso'**
  String get progressTitle;

  /// No description provided for @progressNoData.
  ///
  /// In es, this message translates to:
  /// **'Sin progreso registrado'**
  String get progressNoData;

  /// No description provided for @progressPercentageLabel.
  ///
  /// In es, this message translates to:
  /// **'%'**
  String get progressPercentageLabel;

  /// No description provided for @progressPercentageInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un porcentaje entre 0 y 100.'**
  String get progressPercentageInvalid;

  /// No description provided for @progressChapterLabel.
  ///
  /// In es, this message translates to:
  /// **'Capítulo'**
  String get progressChapterLabel;

  /// No description provided for @progressChapterValue.
  ///
  /// In es, this message translates to:
  /// **'Cap. {chapter}'**
  String progressChapterValue(int chapter);

  /// No description provided for @chapterArbitraryHint.
  ///
  /// In es, this message translates to:
  /// **'El capítulo es independiente: no se sincroniza con páginas ni porcentaje.'**
  String get chapterArbitraryHint;

  /// No description provided for @chapterDoneTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Capítulo completado!'**
  String get chapterDoneTitle;

  /// No description provided for @chapterDonePagePrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Quieres actualizar tu página de progreso?'**
  String get chapterDonePagePrompt;

  /// No description provided for @chapterDoneDontShowAgain.
  ///
  /// In es, this message translates to:
  /// **'No volver a mostrar para este libro'**
  String get chapterDoneDontShowAgain;

  /// No description provided for @eventCreateTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevo evento'**
  String get eventCreateTitle;

  /// No description provided for @eventEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar evento'**
  String get eventEditTitle;

  /// No description provided for @eventSectionDetails.
  ///
  /// In es, this message translates to:
  /// **'General'**
  String get eventSectionDetails;

  /// No description provided for @eventSectionSchedule.
  ///
  /// In es, this message translates to:
  /// **'Programación'**
  String get eventSectionSchedule;

  /// No description provided for @eventTypeLabel.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get eventTypeLabel;

  /// No description provided for @eventBookLabel.
  ///
  /// In es, this message translates to:
  /// **'Libro'**
  String get eventBookLabel;

  /// No description provided for @eventBookPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un libro'**
  String get eventBookPlaceholder;

  /// No description provided for @eventBookOptionalPlaceholder.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un libro (opcional)'**
  String get eventBookOptionalPlaceholder;

  /// No description provided for @eventDescriptionLabel.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get eventDescriptionLabel;

  /// No description provided for @eventTargetPageLabel.
  ///
  /// In es, this message translates to:
  /// **'Página objetivo'**
  String get eventTargetPageLabel;

  /// No description provided for @eventTargetPageRequired.
  ///
  /// In es, this message translates to:
  /// **'Añade una página objetivo.'**
  String get eventTargetPageRequired;

  /// No description provided for @eventTargetPageInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce una página válida.'**
  String get eventTargetPageInvalid;

  /// No description provided for @eventTargetChapterLabel.
  ///
  /// In es, this message translates to:
  /// **'Capítulo objetivo'**
  String get eventTargetChapterLabel;

  /// No description provided for @eventTargetChapterRequired.
  ///
  /// In es, this message translates to:
  /// **'Añade un capítulo objetivo.'**
  String get eventTargetChapterRequired;

  /// No description provided for @eventTargetChapterInvalid.
  ///
  /// In es, this message translates to:
  /// **'Introduce un capítulo válido.'**
  String get eventTargetChapterInvalid;

  /// No description provided for @eventAllDayLabel.
  ///
  /// In es, this message translates to:
  /// **'Todo el día'**
  String get eventAllDayLabel;

  /// No description provided for @eventBookRequired.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un libro.'**
  String get eventBookRequired;

  /// No description provided for @eventReminderLabel.
  ///
  /// In es, this message translates to:
  /// **'Recordatorio'**
  String get eventReminderLabel;

  /// No description provided for @reminderOff.
  ///
  /// In es, this message translates to:
  /// **'Sin recordatorio'**
  String get reminderOff;

  /// No description provided for @eventReminderOffsetLabel.
  ///
  /// In es, this message translates to:
  /// **'Tiempo antes'**
  String get eventReminderOffsetLabel;

  /// No description provided for @eventMute.
  ///
  /// In es, this message translates to:
  /// **'Silenciar'**
  String get eventMute;

  /// No description provided for @eventUnmute.
  ///
  /// In es, this message translates to:
  /// **'Reactivar'**
  String get eventUnmute;

  /// No description provided for @eventConfirmDelete.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este evento?'**
  String get eventConfirmDelete;

  /// No description provided for @eventDeleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'Evento eliminado'**
  String get eventDeleteSuccess;

  /// No description provided for @imagePendingUpload.
  ///
  /// In es, this message translates to:
  /// **'La imagen se subirá al guardar.'**
  String get imagePendingUpload;

  /// No description provided for @coverSearchOption.
  ///
  /// In es, this message translates to:
  /// **'Buscar portadas en línea'**
  String get coverSearchOption;

  /// No description provided for @coverUploadOption.
  ///
  /// In es, this message translates to:
  /// **'Subir una foto'**
  String get coverUploadOption;

  /// No description provided for @notifSettingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get notifSettingsTitle;

  /// No description provided for @notifGlobalLabel.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones activas'**
  String get notifGlobalLabel;

  /// No description provided for @notifGlobalSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desactiva para silenciar todos los recordatorios.'**
  String get notifGlobalSubtitle;

  /// No description provided for @notifDefaultOffsetLabel.
  ///
  /// In es, this message translates to:
  /// **'Tiempo por defecto'**
  String get notifDefaultOffsetLabel;

  /// No description provided for @notifAllDayHourLabel.
  ///
  /// In es, this message translates to:
  /// **'Hora para eventos de día completo'**
  String get notifAllDayHourLabel;

  /// No description provided for @notifAllDayHourValue.
  ///
  /// In es, this message translates to:
  /// **'A las {hour}'**
  String notifAllDayHourValue(String hour);

  /// No description provided for @notifPermissionHint.
  ///
  /// In es, this message translates to:
  /// **'Te pediremos permiso de notificaciones la primera vez que crees un recordatorio.'**
  String get notifPermissionHint;

  /// No description provided for @notifBgTitle.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios con la app cerrada'**
  String get notifBgTitle;

  /// No description provided for @notifBgIntro.
  ///
  /// In es, this message translates to:
  /// **'Para que los avisos lleguen aunque cierres Readendar, concede estos permisos del sistema.'**
  String get notifBgIntro;

  /// No description provided for @notifBgEnableNotifs.
  ///
  /// In es, this message translates to:
  /// **'Activar notificaciones'**
  String get notifBgEnableNotifs;

  /// No description provided for @notifBgExactAlarms.
  ///
  /// In es, this message translates to:
  /// **'Permitir alarmas exactas'**
  String get notifBgExactAlarms;

  /// No description provided for @notifBgBattery.
  ///
  /// In es, this message translates to:
  /// **'Optimización de batería'**
  String get notifBgBattery;

  /// No description provided for @notifBgBatteryHint.
  ///
  /// In es, this message translates to:
  /// **'Si tu móvil tiene ahorro de batería agresivo, excluye Readendar para que los recordatorios lleguen puntuales.'**
  String get notifBgBatteryHint;

  /// No description provided for @notificationChannelName.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios de Readendar'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios de eventos de lectura'**
  String get notificationChannelDescription;

  /// No description provided for @notifTitleStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar a leer'**
  String get notifTitleStart;

  /// No description provided for @notifTitleFinish.
  ///
  /// In es, this message translates to:
  /// **'Terminar el libro'**
  String get notifTitleFinish;

  /// No description provided for @notifTitleAbandon.
  ///
  /// In es, this message translates to:
  /// **'Abandonar la lectura'**
  String get notifTitleAbandon;

  /// No description provided for @notifTitleReachChapter.
  ///
  /// In es, this message translates to:
  /// **'Llegar al capítulo {n}'**
  String notifTitleReachChapter(int n);

  /// No description provided for @notifTitleReachPage.
  ///
  /// In es, this message translates to:
  /// **'Llegar a la página {n}'**
  String notifTitleReachPage(int n);

  /// No description provided for @notifTitleDeadline.
  ///
  /// In es, this message translates to:
  /// **'Fecha límite de lectura'**
  String get notifTitleDeadline;

  /// No description provided for @notifTitleReturn.
  ///
  /// In es, this message translates to:
  /// **'Devolver el libro'**
  String get notifTitleReturn;

  /// No description provided for @notifTitleRelease.
  ///
  /// In es, this message translates to:
  /// **'Lanzamiento de libro'**
  String get notifTitleRelease;

  /// No description provided for @notifBodyDeadlineTarget.
  ///
  /// In es, this message translates to:
  /// **'hasta la pág. {n}'**
  String notifBodyDeadlineTarget(int n);

  /// No description provided for @notifActionComplete.
  ///
  /// In es, this message translates to:
  /// **'Completar'**
  String get notifActionComplete;

  /// No description provided for @notifActionSnooze1h.
  ///
  /// In es, this message translates to:
  /// **'Posponer 1 h'**
  String get notifActionSnooze1h;

  /// No description provided for @notifActionSnoozeTonight.
  ///
  /// In es, this message translates to:
  /// **'Esta noche'**
  String get notifActionSnoozeTonight;

  /// No description provided for @notifActionCompletedSnack.
  ///
  /// In es, this message translates to:
  /// **'{n, plural, one{1 recordatorio completado} other{{n} recordatorios completados}}'**
  String notifActionCompletedSnack(int n);

  /// No description provided for @shareTitle.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca pública'**
  String get shareTitle;

  /// No description provided for @profileDebugTools.
  ///
  /// In es, this message translates to:
  /// **'Herramientas de depuración'**
  String get profileDebugTools;

  /// No description provided for @feedbackTitle.
  ///
  /// In es, this message translates to:
  /// **'Enviar comentarios'**
  String get feedbackTitle;

  /// No description provided for @feedbackProfileHint.
  ///
  /// In es, this message translates to:
  /// **'Informa de un error o comparte una idea'**
  String get feedbackProfileHint;

  /// No description provided for @feedbackBadge.
  ///
  /// In es, this message translates to:
  /// **'Te escuchamos'**
  String get feedbackBadge;

  /// No description provided for @feedbackIntro.
  ///
  /// In es, this message translates to:
  /// **'¿Has encontrado un error o tienes una idea? Escribe el mensaje y Enviar abre tu correo hacia hello@readendar.com.'**
  String get feedbackIntro;

  /// No description provided for @feedbackKindBug.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get feedbackKindBug;

  /// No description provided for @feedbackKindIdea.
  ///
  /// In es, this message translates to:
  /// **'Idea'**
  String get feedbackKindIdea;

  /// No description provided for @feedbackKindOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get feedbackKindOther;

  /// No description provided for @feedbackMessageLabel.
  ///
  /// In es, this message translates to:
  /// **'Tu mensaje'**
  String get feedbackMessageLabel;

  /// No description provided for @feedbackMessageHint.
  ///
  /// In es, this message translates to:
  /// **'Cuéntanoslo con tus palabras: qué ha pasado, qué esperabas o qué echas en falta. Cuanto más detalle nos des, mejor podremos ayudarte.'**
  String get feedbackMessageHint;

  /// No description provided for @feedbackMessageRequired.
  ///
  /// In es, this message translates to:
  /// **'Escribe un mensaje primero.'**
  String get feedbackMessageRequired;

  /// No description provided for @feedbackMessageTooShort.
  ///
  /// In es, this message translates to:
  /// **'El mensaje debe tener al menos 10 caracteres.'**
  String get feedbackMessageTooShort;

  /// No description provided for @feedbackDiagnosticsNote.
  ///
  /// In es, this message translates to:
  /// **'Incluiremos la versión de la app y algunos datos del dispositivo en el correo.'**
  String get feedbackDiagnosticsNote;

  /// No description provided for @feedbackSubmit.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get feedbackSubmit;

  /// No description provided for @feedbackMailOpenFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el correo. Escríbenos a hello@readendar.com.'**
  String get feedbackMailOpenFailed;

  /// No description provided for @feedbackThanksTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias!'**
  String get feedbackThanksTitle;

  /// No description provided for @feedbackThanksBody.
  ///
  /// In es, this message translates to:
  /// **'Si envías el correo, lo leeremos. Gracias por ayudar a mejorar Readendar.'**
  String get feedbackThanksBody;

  /// No description provided for @feedbackThanksDone.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get feedbackThanksDone;

  /// No description provided for @debugTitle.
  ///
  /// In es, this message translates to:
  /// **'Herramientas de depuración'**
  String get debugTitle;

  /// No description provided for @debugOpenOnboardingAction.
  ///
  /// In es, this message translates to:
  /// **'Ver onboarding'**
  String get debugOpenOnboardingAction;

  /// No description provided for @debugOpenOnboardingHint.
  ///
  /// In es, this message translates to:
  /// **'Abre el carrusel de bienvenida para previsualizarlo.'**
  String get debugOpenOnboardingHint;

  /// No description provided for @debugWarning.
  ///
  /// In es, this message translates to:
  /// **'Acciones destructivas solo para compilaciones de depuración. No se puede deshacer.'**
  String get debugWarning;

  /// No description provided for @debugDeleteAllEventsAction.
  ///
  /// In es, this message translates to:
  /// **'Borrar todos los eventos'**
  String get debugDeleteAllEventsAction;

  /// No description provided for @debugDeleteAllEventsHint.
  ///
  /// In es, this message translates to:
  /// **'Elimina todos los eventos de tu calendario.'**
  String get debugDeleteAllEventsHint;

  /// No description provided for @debugDeleteAllBooksAction.
  ///
  /// In es, this message translates to:
  /// **'Borrar todos los libros'**
  String get debugDeleteAllBooksAction;

  /// No description provided for @debugDeleteAllBooksHint.
  ///
  /// In es, this message translates to:
  /// **'Elimina todos los libros y sus eventos relacionados.'**
  String get debugDeleteAllBooksHint;

  /// No description provided for @debugConfirmEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todos los eventos?'**
  String get debugConfirmEventsTitle;

  /// No description provided for @debugConfirmEventsBody.
  ///
  /// In es, this message translates to:
  /// **'Esto elimina permanentemente todos tus eventos. No se puede deshacer.'**
  String get debugConfirmEventsBody;

  /// No description provided for @debugConfirmBooksTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Borrar todos los libros?'**
  String get debugConfirmBooksTitle;

  /// No description provided for @debugConfirmBooksBody.
  ///
  /// In es, this message translates to:
  /// **'Esto elimina permanentemente todos los libros y sus eventos. No se puede deshacer.'**
  String get debugConfirmBooksBody;

  /// No description provided for @debugDeletedEvents.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} evento borrado} other{{count} eventos borrados}}'**
  String debugDeletedEvents(int count);

  /// No description provided for @debugDeletedBooks.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} libro borrado} other{{count} libros borrados}}'**
  String debugDeletedBooks(int count);

  /// No description provided for @debugSeedLocalAction.
  ///
  /// In es, this message translates to:
  /// **'Cargar datos de prueba'**
  String get debugSeedLocalAction;

  /// No description provided for @debugSeedLocalHint.
  ///
  /// In es, this message translates to:
  /// **'Vacía la base de datos local y la rellena con libros, valoraciones, anotaciones, progresos y eventos de todos los tipos.'**
  String get debugSeedLocalHint;

  /// No description provided for @debugSeedLocalConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Sustituir los datos locales?'**
  String get debugSeedLocalConfirmTitle;

  /// No description provided for @debugSeedLocalConfirmBody.
  ///
  /// In es, this message translates to:
  /// **'Se borra lo que haya en el dispositivo y se carga un conjunto de prueba. No se puede deshacer.'**
  String get debugSeedLocalConfirmBody;

  /// No description provided for @debugSeedLocalSuccess.
  ///
  /// In es, this message translates to:
  /// **'Datos de prueba listos: {books} libros y {events} eventos.'**
  String debugSeedLocalSuccess(int books, int events);

  /// No description provided for @debugRestoreCloudImportAction.
  ///
  /// In es, this message translates to:
  /// **'Restaurar token de importación'**
  String get debugRestoreCloudImportAction;

  /// No description provided for @debugRestoreCloudImportHint.
  ///
  /// In es, this message translates to:
  /// **'Temporal. Pide un JWT de la cuenta de importación de depuración al backend local y vuelve a mostrar el aviso y la tarjeta de descargar datos.'**
  String get debugRestoreCloudImportHint;

  /// No description provided for @debugRestoreCloudImportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Token restaurado. Se muestra el aviso de descarga.'**
  String get debugRestoreCloudImportSuccess;

  /// No description provided for @debugRestoreCloudImportMissing.
  ///
  /// In es, this message translates to:
  /// **'No se ha podido emitir el token. Reinicia el API local en modo dev.'**
  String get debugRestoreCloudImportMissing;

  /// No description provided for @debugNotifPreviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Vista previa de notificaciones'**
  String get debugNotifPreviewTitle;

  /// No description provided for @debugNotifPreviewIntro.
  ///
  /// In es, this message translates to:
  /// **'Toca un tipo para lanzarlo ahora y míralo en la bandeja del sistema o la pantalla de bloqueo.'**
  String get debugNotifPreviewIntro;

  /// No description provided for @debugNotifPreviewFireAll.
  ///
  /// In es, this message translates to:
  /// **'Enviar todas'**
  String get debugNotifPreviewFireAll;

  /// No description provided for @debugNotifPreviewSent.
  ///
  /// In es, this message translates to:
  /// **'Enviada a la bandeja'**
  String get debugNotifPreviewSent;

  /// No description provided for @debugScheduledRemindersAction.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios programados'**
  String get debugScheduledRemindersAction;

  /// No description provided for @debugScheduledRemindersHint.
  ///
  /// In es, this message translates to:
  /// **'Lista los recordatorios en cola para los próximos 2 días y lanza cualquiera ahora.'**
  String get debugScheduledRemindersHint;

  /// No description provided for @debugScheduledRemindersTitle.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios programados'**
  String get debugScheduledRemindersTitle;

  /// No description provided for @debugScheduledRemindersIntro.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios en cola para los próximos 2 días. Toca uno para lanzar su notificación exacta ahora.'**
  String get debugScheduledRemindersIntro;

  /// No description provided for @debugScheduledRemindersEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay recordatorios en los próximos 2 días.'**
  String get debugScheduledRemindersEmpty;

  /// No description provided for @debugScheduledRemindersNoBook.
  ///
  /// In es, this message translates to:
  /// **'Sin libro'**
  String get debugScheduledRemindersNoBook;

  /// No description provided for @celebrationTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Lo has terminado!'**
  String get celebrationTitle;

  /// No description provided for @celebrationRoulette.
  ///
  /// In es, this message translates to:
  /// **'Ruleta de lectura'**
  String get celebrationRoulette;

  /// No description provided for @celebrationShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get celebrationShare;

  /// No description provided for @celebrationRatePrompt.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo lo valorarías?'**
  String get celebrationRatePrompt;

  /// No description provided for @celebrationShareMessage.
  ///
  /// In es, this message translates to:
  /// **'¡Acabo de terminar de leer «{title}» en Readendar 📚\nhttps://readendar.com'**
  String celebrationShareMessage(String title);

  /// No description provided for @celebrationDaysMetric.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Terminado en menos de un día} one{Terminado en 1 día} other{Terminado en {count} días}}'**
  String celebrationDaysMetric(int count);

  /// No description provided for @celebrationPagesMetric.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 página leída} other{{count} páginas leídas}}'**
  String celebrationPagesMetric(int count);

  /// No description provided for @celebrationSessionsMetric.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 sesión de lectura} other{{count} sesiones de lectura}}'**
  String celebrationSessionsMetric(int count);

  /// No description provided for @homeActionAddBook.
  ///
  /// In es, this message translates to:
  /// **'Añadir\nlibro'**
  String get homeActionAddBook;

  /// No description provided for @homeActionAddEvent.
  ///
  /// In es, this message translates to:
  /// **'Añadir\nevento'**
  String get homeActionAddEvent;

  /// No description provided for @homeActionRoulette.
  ///
  /// In es, this message translates to:
  /// **'Ruleta\nlibros'**
  String get homeActionRoulette;

  /// No description provided for @rouletteEntry.
  ///
  /// In es, this message translates to:
  /// **'Ruleta de libros'**
  String get rouletteEntry;

  /// No description provided for @rouletteTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Gira la ruleta!'**
  String get rouletteTitle;

  /// No description provided for @rouletteEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Añade libros en Leyendo, Pendiente o Deseado y la ruleta elegirá tu próxima lectura.'**
  String get rouletteEmptyMessage;

  /// Empty roulette when eligible books exist but no shelf badges are selected.
  ///
  /// In es, this message translates to:
  /// **'Activa Leyendo, Pendiente o Deseado para incluir libros en la ruleta.'**
  String get rouletteEmptyFilteredMessage;

  /// No description provided for @rouletteAddBooks.
  ///
  /// In es, this message translates to:
  /// **'Añadir libros'**
  String get rouletteAddBooks;

  /// No description provided for @rouletteSingleMessage.
  ///
  /// In es, this message translates to:
  /// **'«{title}» es tu único libro en la ruleta. Añade más o activa más estanterías para girar.'**
  String rouletteSingleMessage(String title);

  /// No description provided for @rouletteAddMore.
  ///
  /// In es, this message translates to:
  /// **'Añadir más libros'**
  String get rouletteAddMore;

  /// No description provided for @rouletteSwipeHint.
  ///
  /// In es, this message translates to:
  /// **'Desliza para girar'**
  String get rouletteSwipeHint;

  /// No description provided for @rouletteWinnerLabel.
  ///
  /// In es, this message translates to:
  /// **'Tu próxima lectura'**
  String get rouletteWinnerLabel;

  /// No description provided for @rouletteOpenBook.
  ///
  /// In es, this message translates to:
  /// **'Abrir libro'**
  String get rouletteOpenBook;

  /// No description provided for @rouletteSpinAgain.
  ///
  /// In es, this message translates to:
  /// **'Girar de nuevo'**
  String get rouletteSpinAgain;

  /// No description provided for @profileImportData.
  ///
  /// In es, this message translates to:
  /// **'Importar datos'**
  String get profileImportData;

  /// No description provided for @profileImportSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca desde otras aplicaciones'**
  String get profileImportSubtitle;

  /// No description provided for @profileSectionTools.
  ///
  /// In es, this message translates to:
  /// **'Datos y widgets'**
  String get profileSectionTools;

  /// No description provided for @libraryEmptyImport.
  ///
  /// In es, this message translates to:
  /// **'Importar datos'**
  String get libraryEmptyImport;

  /// No description provided for @importDataTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar datos'**
  String get importDataTitle;

  /// No description provided for @importChooseSource.
  ///
  /// In es, this message translates to:
  /// **'¿De dónde viene tu biblioteca?'**
  String get importChooseSource;

  /// No description provided for @importGoodreadsSourceName.
  ///
  /// In es, this message translates to:
  /// **'Goodreads'**
  String get importGoodreadsSourceName;

  /// No description provided for @importBookmorySourceName.
  ///
  /// In es, this message translates to:
  /// **'Bookmory'**
  String get importBookmorySourceName;

  /// No description provided for @importStoryGraphSourceName.
  ///
  /// In es, this message translates to:
  /// **'StoryGraph'**
  String get importStoryGraphSourceName;

  /// No description provided for @importBabelioSourceName.
  ///
  /// In es, this message translates to:
  /// **'Babelio'**
  String get importBabelioSourceName;

  /// No description provided for @importGoodreadsSourceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona el CSV exportado'**
  String get importGoodreadsSourceSubtitle;

  /// No description provided for @importBookmorySourceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un archivo Excel de Bookmory'**
  String get importBookmorySourceSubtitle;

  /// No description provided for @importStoryGraphSourceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un CSV'**
  String get importStoryGraphSourceSubtitle;

  /// No description provided for @importBabelioSourceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Exporta tu biblioteca y selecciona el CSV'**
  String get importBabelioSourceSubtitle;

  /// No description provided for @bookmoryImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar de Bookmory'**
  String get bookmoryImportTitle;

  /// No description provided for @bookmoryImportHeadline.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca de Bookmory'**
  String get bookmoryImportHeadline;

  /// No description provided for @bookmoryImportBody.
  ///
  /// In es, this message translates to:
  /// **'Usa la exportación Excel de Bookmory para añadir tus libros, estados, valoraciones y notas privadas.'**
  String get bookmoryImportBody;

  /// No description provided for @bookmoryImportStep1.
  ///
  /// In es, this message translates to:
  /// **'En Bookmory, abre Mi página → Exportar y elige Excel (xlsx). Activa «Incluir notas» si quieres importarlas.'**
  String get bookmoryImportStep1;

  /// No description provided for @bookmoryImportStep2.
  ///
  /// In es, this message translates to:
  /// **'Pulsa Exportar y selecciona aquí el archivo descargado.'**
  String get bookmoryImportStep2;

  /// No description provided for @bookmoryImportPickFile.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar archivo Excel'**
  String get bookmoryImportPickFile;

  /// No description provided for @bookmoryImportInvalidFile.
  ///
  /// In es, this message translates to:
  /// **'Esto no parece una exportación Excel válida de Bookmory.'**
  String get bookmoryImportInvalidFile;

  /// No description provided for @storygraphImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar de StoryGraph'**
  String get storygraphImportTitle;

  /// No description provided for @storygraphImportHeadline.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca de StoryGraph'**
  String get storygraphImportHeadline;

  /// No description provided for @storygraphImportBody.
  ///
  /// In es, this message translates to:
  /// **'Usa la exportación CSV de StoryGraph para añadir tus libros, estados, formatos, valoraciones y reseñas.'**
  String get storygraphImportBody;

  /// No description provided for @storygraphImportStep1.
  ///
  /// In es, this message translates to:
  /// **'En la app de StoryGraph, abre Perfil, toca el menú de arriba a la derecha (☰) y elige Manage Account.'**
  String get storygraphImportStep1;

  /// No description provided for @storygraphImportStep2.
  ///
  /// In es, this message translates to:
  /// **'En Manage Your Data, toca Export StoryGraph Library y Generate Export. Cuando StoryGraph te envíe un correo, descarga el CSV y selecciónalo aquí.'**
  String get storygraphImportStep2;

  /// No description provided for @storygraphImportPickFile.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar CSV de StoryGraph'**
  String get storygraphImportPickFile;

  /// No description provided for @storygraphImportInvalidFile.
  ///
  /// In es, this message translates to:
  /// **'Esto no parece una exportación CSV válida de StoryGraph.'**
  String get storygraphImportInvalidFile;

  /// No description provided for @storygraphImportOpenExport.
  ///
  /// In es, this message translates to:
  /// **'Abrir exportación de StoryGraph'**
  String get storygraphImportOpenExport;

  /// No description provided for @storygraphImportOpenError.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido abrir StoryGraph. Sigue los pasos en la app de StoryGraph.'**
  String get storygraphImportOpenError;

  /// No description provided for @babelioImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar de Babelio'**
  String get babelioImportTitle;

  /// No description provided for @babelioImportHeadline.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca de Babelio'**
  String get babelioImportHeadline;

  /// No description provided for @babelioImportBody.
  ///
  /// In es, this message translates to:
  /// **'Usa la exportación CSV de Babelio para añadir tus libros, estados y valoraciones.'**
  String get babelioImportBody;

  /// No description provided for @babelioImportStep1.
  ///
  /// In es, this message translates to:
  /// **'Abre la exportación de Babelio e inicia sesión si te lo pide.'**
  String get babelioImportStep1;

  /// No description provided for @babelioImportStep2.
  ///
  /// In es, this message translates to:
  /// **'Completa la verificación, descarga tu biblioteca con el primer botón y selecciona aquí el CSV.'**
  String get babelioImportStep2;

  /// No description provided for @babelioImportPickFile.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar CSV de Babelio'**
  String get babelioImportPickFile;

  /// No description provided for @babelioImportInvalidFile.
  ///
  /// In es, this message translates to:
  /// **'Esto no parece una exportación CSV válida de Babelio.'**
  String get babelioImportInvalidFile;

  /// No description provided for @babelioImportOpenExport.
  ///
  /// In es, this message translates to:
  /// **'Abrir exportación de Babelio'**
  String get babelioImportOpenExport;

  /// No description provided for @babelioImportOpenError.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido abrir Babelio. Prueba a exportar desde el navegador.'**
  String get babelioImportOpenError;

  /// No description provided for @importSkippedAuthorNote.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se ha omitido 1 fila sin autor} other{Se han omitido {count} filas sin autor}}'**
  String importSkippedAuthorNote(num count);

  /// No description provided for @importTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar de Goodreads'**
  String get importTitle;

  /// No description provided for @importIntroHeadline.
  ///
  /// In es, this message translates to:
  /// **'Trae tu biblioteca de Goodreads'**
  String get importIntroHeadline;

  /// No description provided for @importIntroBody.
  ///
  /// In es, this message translates to:
  /// **'Exporta tus libros desde Goodreads y los añadimos a tu biblioteca con sus portadas.'**
  String get importIntroBody;

  /// No description provided for @importIntroStep1.
  ///
  /// In es, this message translates to:
  /// **'En un ordenador, abre Goodreads → My Books → Import and export.'**
  String get importIntroStep1;

  /// No description provided for @importIntroStep2.
  ///
  /// In es, this message translates to:
  /// **'Haz clic en «Export Library» y descarga el archivo CSV.'**
  String get importIntroStep2;

  /// No description provided for @importIntroStep3.
  ///
  /// In es, this message translates to:
  /// **'Envíate el archivo al móvil y selecciónalo aquí.'**
  String get importIntroStep3;

  /// No description provided for @importPickFile.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar archivo CSV'**
  String get importPickFile;

  /// No description provided for @importInvalidFile.
  ///
  /// In es, this message translates to:
  /// **'Esto no parece un export de Goodreads.'**
  String get importInvalidFile;

  /// No description provided for @importEmptyFile.
  ///
  /// In es, this message translates to:
  /// **'No encontramos libros en el archivo.'**
  String get importEmptyFile;

  /// No description provided for @importFileTooLarge.
  ///
  /// In es, this message translates to:
  /// **'Ese archivo es demasiado grande (máx. 10 MB).'**
  String get importFileTooLarge;

  /// No description provided for @importBadEncoding.
  ///
  /// In es, this message translates to:
  /// **'No pudimos leer la codificación de texto del archivo. Vuelve a exportarlo como CSV en UTF-8 e inténtalo de nuevo.'**
  String get importBadEncoding;

  /// No description provided for @importConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisar importación'**
  String get importConfirmTitle;

  /// No description provided for @importDuplicateInLibrary.
  ///
  /// In es, this message translates to:
  /// **'Ya la tienes'**
  String get importDuplicateInLibrary;

  /// No description provided for @importFound.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Hemos encontrado 1 libro} other{Hemos encontrado {count} libros}}'**
  String importFound(int count);

  /// No description provided for @importDuplicatesNote.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se omitió 1 duplicado del archivo} other{Se omitieron {count} duplicados del archivo}}'**
  String importDuplicatesNote(int count);

  /// No description provided for @importSkippedNote.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se omitió 1 fila sin título} other{Se omitieron {count} filas sin título}}'**
  String importSkippedNote(int count);

  /// No description provided for @importUnmatchedNotes.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{No se pudieron asociar las notas de 1 libro} other{No se pudieron asociar las notas de {count} libros}}'**
  String importUnmatchedNotes(int count);

  /// No description provided for @importTruncatedNote.
  ///
  /// In es, this message translates to:
  /// **'Solo se importarán los primeros {max} libros.'**
  String importTruncatedNote(int max);

  /// No description provided for @importStart.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Importar 1 libro} other{Importar {count} libros}}'**
  String importStart(int count);

  /// No description provided for @importProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Importando'**
  String get importProgressTitle;

  /// No description provided for @importProgressLabel.
  ///
  /// In es, this message translates to:
  /// **'{done} de {total}'**
  String importProgressLabel(int done, int total);

  /// No description provided for @importCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get importCancel;

  /// No description provided for @importCancelling.
  ///
  /// In es, this message translates to:
  /// **'Cancelando…'**
  String get importCancelling;

  /// No description provided for @importProgressSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Añadiendo tus libros…'**
  String get importProgressSubtitle;

  /// No description provided for @importCompleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Importación completada!'**
  String get importCompleteTitle;

  /// No description provided for @importCancelledTitle.
  ///
  /// In es, this message translates to:
  /// **'Importación cancelada'**
  String get importCancelledTitle;

  /// No description provided for @importCompleteSubtitle.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No se añadió ningún libro} one{Se añadió 1 libro a tu biblioteca} other{Se añadieron {count} libros a tu biblioteca}}'**
  String importCompleteSubtitle(int count);

  /// No description provided for @importStatAdded.
  ///
  /// In es, this message translates to:
  /// **'Añadidos'**
  String get importStatAdded;

  /// No description provided for @importStatNoCover.
  ///
  /// In es, this message translates to:
  /// **'Sin portada'**
  String get importStatNoCover;

  /// No description provided for @importStatFailed.
  ///
  /// In es, this message translates to:
  /// **'Con error'**
  String get importStatFailed;

  /// No description provided for @importMetadataNote.
  ///
  /// In es, this message translates to:
  /// **'Revisa los libros y estados antes de importar. No se importan las fechas, sesiones ni tiempo de lectura.'**
  String get importMetadataNote;

  /// No description provided for @importRoundedRatingsNote.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se redondeó 1 valoración de StoryGraph a la media estrella más cercana porque Readendar usa medias estrellas.} other{Se redondearon {count} valoraciones de StoryGraph a la media estrella más cercana porque Readendar usa medias estrellas.}}'**
  String importRoundedRatingsNote(int count);

  /// No description provided for @importRetryFailed.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Reintentar 1 libro} other{Reintentar {count} libros}}'**
  String importRetryFailed(num count);

  /// No description provided for @importImproveCovers.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Añadir 1 portada} other{Añadir {count} portadas}}'**
  String importImproveCovers(int count);

  /// No description provided for @importGoToLibrary.
  ///
  /// In es, this message translates to:
  /// **'Ver biblioteca'**
  String get importGoToLibrary;

  /// No description provided for @importImproveTitle.
  ///
  /// In es, this message translates to:
  /// **'Añadir portadas'**
  String get importImproveTitle;

  /// No description provided for @importDone.
  ///
  /// In es, this message translates to:
  /// **'Hecho'**
  String get importDone;

  /// No description provided for @importImproveHint.
  ///
  /// In es, this message translates to:
  /// **'Estos libros se importaron sin portada. Búscalos para añadirles una.'**
  String get importImproveHint;

  /// No description provided for @importAllCoversDone.
  ///
  /// In es, this message translates to:
  /// **'¡Todas las portadas listas!'**
  String get importAllCoversDone;

  /// No description provided for @importCoverUpdated.
  ///
  /// In es, this message translates to:
  /// **'Portada actualizada'**
  String get importCoverUpdated;

  /// No description provided for @importImproveSearchTitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar portada'**
  String get importImproveSearchTitle;

  /// No description provided for @importImproveSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Título o autor'**
  String get importImproveSearchHint;

  /// No description provided for @statusEmptyReading.
  ///
  /// In es, this message translates to:
  /// **'Aún no estás leyendo nada.\n¡Escoge tu próximo libro!'**
  String get statusEmptyReading;

  /// No description provided for @statusEmptyPending.
  ///
  /// In es, this message translates to:
  /// **'Tu lista de pendientes está vacía.\n¡Añade libros que quieras leer!'**
  String get statusEmptyPending;

  /// No description provided for @statusEmptyWanted.
  ///
  /// In es, this message translates to:
  /// **'Tu lista de deseados está vacía.\n¡Añade libros que quieras conseguir!'**
  String get statusEmptyWanted;

  /// No description provided for @statusEmptyRead.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has terminado ningún libro.'**
  String get statusEmptyRead;

  /// No description provided for @statusEmptyAbandoned.
  ///
  /// In es, this message translates to:
  /// **'No has abandonado ningún libro.\n¡Sigue así!'**
  String get statusEmptyAbandoned;

  /// No description provided for @statusEmptyGoToLibrary.
  ///
  /// In es, this message translates to:
  /// **'Ir a la biblioteca'**
  String get statusEmptyGoToLibrary;

  /// No description provided for @planButton.
  ///
  /// In es, this message translates to:
  /// **'Planificar lectura'**
  String get planButton;

  /// No description provided for @planTitle.
  ///
  /// In es, this message translates to:
  /// **'Planificar'**
  String get planTitle;

  /// No description provided for @planReplanTitle.
  ///
  /// In es, this message translates to:
  /// **'Replanificar'**
  String get planReplanTitle;

  /// No description provided for @planReplanCta.
  ///
  /// In es, this message translates to:
  /// **'Replanificar'**
  String get planReplanCta;

  /// No description provided for @planReplanFromStart.
  ///
  /// In es, this message translates to:
  /// **'Cambiar opciones'**
  String get planReplanFromStart;

  /// No description provided for @planReplanNothing.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos pendientes para replanificar.'**
  String get planReplanNothing;

  /// No description provided for @planProgressAheadTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Está actualizado tu progreso de lectura?'**
  String get planProgressAheadTitle;

  /// No description provided for @planProgressAheadMessage.
  ///
  /// In es, this message translates to:
  /// **'Tu progreso registrado es {currentPage}. Actualízalo para que el nuevo plan empiece donde estás de verdad.'**
  String planProgressAheadMessage(int currentPage);

  /// No description provided for @planProgressAheadAction.
  ///
  /// In es, this message translates to:
  /// **'Actualizar progreso'**
  String get planProgressAheadAction;

  /// No description provided for @planModePace.
  ///
  /// In es, this message translates to:
  /// **'Meta diaria'**
  String get planModePace;

  /// No description provided for @planModeDeadline.
  ///
  /// In es, this message translates to:
  /// **'Terminar en una fecha'**
  String get planModeDeadline;

  /// No description provided for @planUnitPages.
  ///
  /// In es, this message translates to:
  /// **'Páginas'**
  String get planUnitPages;

  /// No description provided for @planUnitChapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos'**
  String get planUnitChapters;

  /// No description provided for @planStart.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get planStart;

  /// No description provided for @planDeadline.
  ///
  /// In es, this message translates to:
  /// **'Fecha fin'**
  String get planDeadline;

  /// No description provided for @planPace.
  ///
  /// In es, this message translates to:
  /// **'Ritmo'**
  String get planPace;

  /// No description provided for @planPerDayPages.
  ///
  /// In es, this message translates to:
  /// **'pág/día'**
  String get planPerDayPages;

  /// No description provided for @planPerDayChapters.
  ///
  /// In es, this message translates to:
  /// **'cap/día'**
  String get planPerDayChapters;

  /// No description provided for @planTotalPages.
  ///
  /// In es, this message translates to:
  /// **'Total de páginas'**
  String get planTotalPages;

  /// No description provided for @planTotalChapters.
  ///
  /// In es, this message translates to:
  /// **'Total de capítulos'**
  String get planTotalChapters;

  /// No description provided for @planReadingDays.
  ///
  /// In es, this message translates to:
  /// **'Días de lectura'**
  String get planReadingDays;

  /// No description provided for @planReminders.
  ///
  /// In es, this message translates to:
  /// **'Recordatorios'**
  String get planReminders;

  /// No description provided for @planRemindersHelp.
  ///
  /// In es, this message translates to:
  /// **'Usa la hora de recordatorio predeterminada de Ajustes.'**
  String get planRemindersHelp;

  /// No description provided for @planReset.
  ///
  /// In es, this message translates to:
  /// **'Reiniciar'**
  String get planReset;

  /// No description provided for @planNeedChapters.
  ///
  /// In es, this message translates to:
  /// **'Introduce el total de capítulos para ver tu plan.'**
  String get planNeedChapters;

  /// No description provided for @planNeedPages.
  ///
  /// In es, this message translates to:
  /// **'Añade el número de páginas del libro para planificar.'**
  String get planNeedPages;

  /// No description provided for @planAdjustHint.
  ///
  /// In es, this message translates to:
  /// **'Ajusta los criterios para ver tu plan.'**
  String get planAdjustHint;

  /// No description provided for @planIssueNothingToRead.
  ///
  /// In es, this message translates to:
  /// **'Ya has alcanzado el total: no queda nada por planificar.'**
  String get planIssueNothingToRead;

  /// No description provided for @planIssueInvalidPace.
  ///
  /// In es, this message translates to:
  /// **'Introduce un ritmo de al menos 1 por día.'**
  String get planIssueInvalidPace;

  /// No description provided for @planIssueInvalidRange.
  ///
  /// In es, this message translates to:
  /// **'La fecha límite debe ser igual o posterior a la de inicio.'**
  String get planIssueInvalidRange;

  /// No description provided for @planIssueNoReadingDays.
  ///
  /// In es, this message translates to:
  /// **'Has excluido todos los días de lectura.'**
  String get planIssueNoReadingDays;

  /// No description provided for @planStartInPast.
  ///
  /// In es, this message translates to:
  /// **'La fecha de inicio es anterior a hoy.'**
  String get planStartInPast;

  /// No description provided for @planPaceAggressive.
  ///
  /// In es, this message translates to:
  /// **'Es un ritmo exigente.'**
  String get planPaceAggressive;

  /// No description provided for @planWeekdayToggleHint.
  ///
  /// In es, this message translates to:
  /// **'Toca para incluir o excluir este día.'**
  String get planWeekdayToggleHint;

  /// No description provided for @planCalendarTapHint.
  ///
  /// In es, this message translates to:
  /// **'Toca un día para excluirlo o restaurarlo.'**
  String get planCalendarTapHint;

  /// No description provided for @planDerivedFinish.
  ///
  /// In es, this message translates to:
  /// **'Terminas ≈ {date} · {days, plural, one{1 día de lectura} other{{days} días de lectura}}'**
  String planDerivedFinish(String date, int days);

  /// No description provided for @planDerivedPace.
  ///
  /// In es, this message translates to:
  /// **'Ritmo necesario: ≈ {pace} {unit}'**
  String planDerivedPace(int pace, String unit);

  /// No description provided for @planTooMany.
  ///
  /// In es, this message translates to:
  /// **'Demasiados eventos ({count}). Aumenta el ritmo o acorta el rango.'**
  String planTooMany(int count);

  /// No description provided for @planManyWarning.
  ///
  /// In es, this message translates to:
  /// **'Plan extenso. {count} eventos.'**
  String planManyWarning(int count);

  /// No description provided for @planEventsCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 evento} other{{count} eventos}}'**
  String planEventsCount(int count);

  /// No description provided for @planRange.
  ///
  /// In es, this message translates to:
  /// **'{start} - {end}'**
  String planRange(String start, String end);

  /// No description provided for @planMilestonePage.
  ///
  /// In es, this message translates to:
  /// **'Página {n}'**
  String planMilestonePage(int n);

  /// No description provided for @planMilestoneChapter.
  ///
  /// In es, this message translates to:
  /// **'Capítulo {n}'**
  String planMilestoneChapter(int n);

  /// No description provided for @planEventStart.
  ///
  /// In es, this message translates to:
  /// **'Empezar la lectura'**
  String get planEventStart;

  /// No description provided for @planEventFinish.
  ///
  /// In es, this message translates to:
  /// **'Terminar el libro'**
  String get planEventFinish;

  /// No description provided for @planEventDeadline.
  ///
  /// In es, this message translates to:
  /// **'Fecha fin de lectura'**
  String get planEventDeadline;

  /// No description provided for @planCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear'**
  String get planCreate;

  /// No description provided for @planUpdate.
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get planUpdate;

  /// No description provided for @planUpdateConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizar plan'**
  String get planUpdateConfirmTitle;

  /// No description provided for @planUpdateConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se actualizará 1 evento} other{Se actualizarán {count} eventos}} entre el {start} y el {end}.'**
  String planUpdateConfirmMessage(int count, String start, String end);

  /// No description provided for @planUpdateProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Actualizando el plan'**
  String get planUpdateProgressTitle;

  /// No description provided for @planUpdateCompleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Plan actualizado!'**
  String get planUpdateCompleteTitle;

  /// No description provided for @planUpdateFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar el plan.'**
  String get planUpdateFailed;

  /// No description provided for @planConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear plan'**
  String get planConfirmTitle;

  /// No description provided for @planConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Se creará 1 evento} other{Se crearán {count} eventos}} entre el {start} y el {end}.'**
  String planConfirmMessage(int count, String start, String end);

  /// No description provided for @planConfirmOverlap.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Este libro ya tiene 1 evento en este periodo.} other{Este libro ya tiene {count} eventos en este periodo.}}'**
  String planConfirmOverlap(int count);

  /// No description provided for @planConfirmMarkReading.
  ///
  /// In es, this message translates to:
  /// **'Marcar como leyendo'**
  String get planConfirmMarkReading;

  /// No description provided for @planProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Creando el plan'**
  String get planProgressTitle;

  /// No description provided for @planRollingBack.
  ///
  /// In es, this message translates to:
  /// **'Deshaciendo…'**
  String get planRollingBack;

  /// No description provided for @planFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo crear el plan.'**
  String get planFailed;

  /// No description provided for @planCompleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¡Plan creado!'**
  String get planCompleteTitle;

  /// No description provided for @planViewInCalendar.
  ///
  /// In es, this message translates to:
  /// **'Ver en el calendario'**
  String get planViewInCalendar;

  /// No description provided for @planListView.
  ///
  /// In es, this message translates to:
  /// **'Lista'**
  String get planListView;

  /// No description provided for @planCalendarView.
  ///
  /// In es, this message translates to:
  /// **'Calendario'**
  String get planCalendarView;

  /// No description provided for @planPreviewHint.
  ///
  /// In es, this message translates to:
  /// **'Pulsa “Calcular eventos” o “Recalcular desde cero” para ver tu plan.'**
  String get planPreviewHint;

  /// No description provided for @planAlreadyReadChapters.
  ///
  /// In es, this message translates to:
  /// **'Capítulos leídos'**
  String get planAlreadyReadChapters;

  /// No description provided for @planAlreadyReadPages.
  ///
  /// In es, this message translates to:
  /// **'Páginas leídas'**
  String get planAlreadyReadPages;

  /// No description provided for @planSectionSchedule.
  ///
  /// In es, this message translates to:
  /// **'Fechas y ritmo'**
  String get planSectionSchedule;

  /// No description provided for @planSectionBookends.
  ///
  /// In es, this message translates to:
  /// **'Eventos y avisos'**
  String get planSectionBookends;

  /// No description provided for @planIncludeStart.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento de inicio'**
  String get planIncludeStart;

  /// No description provided for @planIncludeFinish.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento de fin'**
  String get planIncludeFinish;

  /// No description provided for @planIncludeDeadline.
  ///
  /// In es, this message translates to:
  /// **'Añadir evento de fecha fin'**
  String get planIncludeDeadline;

  /// No description provided for @planExclusionsBlocked.
  ///
  /// In es, this message translates to:
  /// **'Estas exclusiones rompen el plan'**
  String get planExclusionsBlocked;

  /// No description provided for @planExclusionsTight.
  ///
  /// In es, this message translates to:
  /// **'Los días excluidos hacen el ritmo más exigente de lo previsto.'**
  String get planExclusionsTight;

  /// No description provided for @planAdvicePending.
  ///
  /// In es, this message translates to:
  /// **'Completa los campos para ver tu estimación.'**
  String get planAdvicePending;

  /// No description provided for @planRemovedDay.
  ///
  /// In es, this message translates to:
  /// **'Sin lectura'**
  String get planRemovedDay;

  /// No description provided for @planHistoryViewLink.
  ///
  /// In es, this message translates to:
  /// **'Ver planificaciones pasadas'**
  String get planHistoryViewLink;

  /// No description provided for @planHistoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Planificaciones pasadas'**
  String get planHistoryTitle;

  /// No description provided for @planHistoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay planificaciones para este libro.'**
  String get planHistoryEmpty;

  /// No description provided for @planHistorySummaryPace.
  ///
  /// In es, this message translates to:
  /// **'Meta diaria'**
  String get planHistorySummaryPace;

  /// No description provided for @planHistorySummaryDeadline.
  ///
  /// In es, this message translates to:
  /// **'Terminar en una fecha'**
  String get planHistorySummaryDeadline;

  /// No description provided for @planHistoryPerDayPages.
  ///
  /// In es, this message translates to:
  /// **'{count} pág/día'**
  String planHistoryPerDayPages(int count);

  /// No description provided for @planHistoryPerDayChapters.
  ///
  /// In es, this message translates to:
  /// **'{count} cap/día'**
  String planHistoryPerDayChapters(int count);

  /// No description provided for @planUndo.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get planUndo;

  /// No description provided for @planUndoConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Deshacer este plan?'**
  String get planUndoConfirmTitle;

  /// No description provided for @planUndoConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán los eventos que creó este plan y que aún existen. Los que ya hayas eliminado o completado no se ven afectados.'**
  String get planUndoConfirmMessage;

  /// No description provided for @planUndone.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{No se borró ningún evento} one{Se ha borrado 1 evento del plan} other{Se han borrado {count} eventos del plan}}'**
  String planUndone(int count);

  /// No description provided for @planUndoFailed.
  ///
  /// In es, this message translates to:
  /// **'No se pudo deshacer el plan.'**
  String get planUndoFailed;

  /// No description provided for @planConfirmReassurance.
  ///
  /// In es, this message translates to:
  /// **'No te preocupes: podrás deshacerlo cuando quieras.'**
  String get planConfirmReassurance;

  /// No description provided for @planUndoCreated.
  ///
  /// In es, this message translates to:
  /// **'Deshacer este plan'**
  String get planUndoCreated;

  /// No description provided for @myStatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Métricas'**
  String get myStatsTitle;

  /// No description provided for @myStatsSummary.
  ///
  /// In es, this message translates to:
  /// **'Resumen'**
  String get myStatsSummary;

  /// No description provided for @myStatsReadingSince.
  ///
  /// In es, this message translates to:
  /// **'Leyendo desde {date}'**
  String myStatsReadingSince(String date);

  /// No description provided for @myStatsBooksRead.
  ///
  /// In es, this message translates to:
  /// **'Leídos'**
  String get myStatsBooksRead;

  /// No description provided for @myStatsBooksReading.
  ///
  /// In es, this message translates to:
  /// **'Leyendo'**
  String get myStatsBooksReading;

  /// No description provided for @myStatsBooksQueued.
  ///
  /// In es, this message translates to:
  /// **'Por leer'**
  String get myStatsBooksQueued;

  /// No description provided for @myStatsBooksWanted.
  ///
  /// In es, this message translates to:
  /// **'Deseados'**
  String get myStatsBooksWanted;

  /// No description provided for @myStatsBooksAbandoned.
  ///
  /// In es, this message translates to:
  /// **'Abandonados'**
  String get myStatsBooksAbandoned;

  /// No description provided for @myStatsActivity.
  ///
  /// In es, this message translates to:
  /// **'Actividad'**
  String get myStatsActivity;

  /// No description provided for @myStatsTaste.
  ///
  /// In es, this message translates to:
  /// **'Gustos'**
  String get myStatsTaste;

  /// No description provided for @myStatsFinished30.
  ///
  /// In es, this message translates to:
  /// **'Acabados (30d)'**
  String get myStatsFinished30;

  /// No description provided for @myStatsFinishedYear.
  ///
  /// In es, this message translates to:
  /// **'Leídos'**
  String get myStatsFinishedYear;

  /// No description provided for @myStatsAdded30.
  ///
  /// In es, this message translates to:
  /// **'Añadidos (30d)'**
  String get myStatsAdded30;

  /// No description provided for @myStatsCurrentStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha actual'**
  String get myStatsCurrentStreak;

  /// No description provided for @myStatsLongestStreak.
  ///
  /// In es, this message translates to:
  /// **'Mejor racha'**
  String get myStatsLongestStreak;

  /// No description provided for @myStatsBestMonth.
  ///
  /// In es, this message translates to:
  /// **'Mejor mes'**
  String get myStatsBestMonth;

  /// No description provided for @myStatsFinishedChart.
  ///
  /// In es, this message translates to:
  /// **'Libros acabados por mes'**
  String get myStatsFinishedChart;

  /// No description provided for @myStatsPagesPreview.
  ///
  /// In es, this message translates to:
  /// **'{pages} págs.'**
  String myStatsPagesPreview(int pages);

  /// No description provided for @myStatsGranularityWeek.
  ///
  /// In es, this message translates to:
  /// **'Semana'**
  String get myStatsGranularityWeek;

  /// No description provided for @myStatsGranularityMonth.
  ///
  /// In es, this message translates to:
  /// **'Mes'**
  String get myStatsGranularityMonth;

  /// No description provided for @myStatsGranularityYear.
  ///
  /// In es, this message translates to:
  /// **'Año'**
  String get myStatsGranularityYear;

  /// No description provided for @myStatsGranularityAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get myStatsGranularityAll;

  /// No description provided for @myStatsPreviousPeriod.
  ///
  /// In es, this message translates to:
  /// **'Periodo anterior'**
  String get myStatsPreviousPeriod;

  /// No description provided for @myStatsNextPeriod.
  ///
  /// In es, this message translates to:
  /// **'Periodo siguiente'**
  String get myStatsNextPeriod;

  /// No description provided for @myStatsPagesInRange.
  ///
  /// In es, this message translates to:
  /// **'Páginas'**
  String get myStatsPagesInRange;

  /// No description provided for @myStatsPageActivityUnavailable.
  ///
  /// In es, this message translates to:
  /// **'La actividad de páginas no está disponible con esta versión del servidor.'**
  String get myStatsPageActivityUnavailable;

  /// No description provided for @myStatsPageChart.
  ///
  /// In es, this message translates to:
  /// **'Páginas leídas'**
  String get myStatsPageChart;

  /// No description provided for @myStatsUnitPagesPerDay.
  ///
  /// In es, this message translates to:
  /// **'págs./día'**
  String get myStatsUnitPagesPerDay;

  /// No description provided for @myStatsUnitPagesPerMonth.
  ///
  /// In es, this message translates to:
  /// **'págs./mes'**
  String get myStatsUnitPagesPerMonth;

  /// No description provided for @myStatsUnitPagesPerYear.
  ///
  /// In es, this message translates to:
  /// **'págs./año'**
  String get myStatsUnitPagesPerYear;

  /// No description provided for @myStatsReadingDays.
  ///
  /// In es, this message translates to:
  /// **'Días de lectura'**
  String get myStatsReadingDays;

  /// No description provided for @myStatsNoTaste.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay suficiente historial de lectura.'**
  String get myStatsNoTaste;

  /// No description provided for @myStatsAvgRating.
  ///
  /// In es, this message translates to:
  /// **'Valoración media'**
  String get myStatsAvgRating;

  /// No description provided for @myStatsTopGenres.
  ///
  /// In es, this message translates to:
  /// **'Tus géneros'**
  String get myStatsTopGenres;

  /// No description provided for @myStatsUnitMonths.
  ///
  /// In es, this message translates to:
  /// **'meses'**
  String get myStatsUnitMonths;

  /// No description provided for @widgetAddToHome.
  ///
  /// In es, this message translates to:
  /// **'Añadir a la pantalla de inicio'**
  String get widgetAddToHome;

  /// No description provided for @widgetHowToTitle.
  ///
  /// In es, this message translates to:
  /// **'Añade el widget de Readendar'**
  String get widgetHowToTitle;

  /// No description provided for @widgetHowToIos.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada la pantalla de inicio, toca el + de la esquina, busca «Readendar», elige un tamaño y añádelo.'**
  String get widgetHowToIos;

  /// No description provided for @widgetHowToAndroid.
  ///
  /// In es, this message translates to:
  /// **'Mantén pulsada la pantalla de inicio, toca Widgets, busca Readendar y arrastra un tamaño a la pantalla.'**
  String get widgetHowToAndroid;

  /// No description provided for @widgetPreviewEmptyEvents.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos próximos'**
  String get widgetPreviewEmptyEvents;

  /// No description provided for @widgetSeeMore.
  ///
  /// In es, this message translates to:
  /// **'Ver más en el calendario'**
  String get widgetSeeMore;

  /// No description provided for @widgetPreviewError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo actualizar'**
  String get widgetPreviewError;

  /// No description provided for @widgetPinnedToast.
  ///
  /// In es, this message translates to:
  /// **'Widget añadido a la pantalla de inicio'**
  String get widgetPinnedToast;

  /// No description provided for @widgetsTitle.
  ///
  /// In es, this message translates to:
  /// **'Widgets'**
  String get widgetsTitle;

  /// No description provided for @widgetsRowSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Lecturas, eventos y citas en tu pantalla de inicio'**
  String get widgetsRowSubtitle;

  /// No description provided for @widgetsIntro.
  ///
  /// In es, this message translates to:
  /// **'Añade widgets a tu pantalla de inicio para tener Readendar siempre a mano.'**
  String get widgetsIntro;

  /// No description provided for @widgetEventsTitle.
  ///
  /// In es, this message translates to:
  /// **'Próximos eventos'**
  String get widgetEventsTitle;

  /// No description provided for @quotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Citas'**
  String get quotesTitle;

  /// No description provided for @quotesSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en tus citas…'**
  String get quotesSearchHint;

  /// No description provided for @quoteAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir cita'**
  String get quoteAdd;

  /// No description provided for @quotePageAbbrev.
  ///
  /// In es, this message translates to:
  /// **'p. {n}'**
  String quotePageAbbrev(int n);

  /// No description provided for @quoteChapterAbbrev.
  ///
  /// In es, this message translates to:
  /// **'cap. {n}'**
  String quoteChapterAbbrev(int n);

  /// No description provided for @quoteComposerPageLabel.
  ///
  /// In es, this message translates to:
  /// **'Página'**
  String get quoteComposerPageLabel;

  /// No description provided for @quoteComposerChapterLabel.
  ///
  /// In es, this message translates to:
  /// **'Capítulo'**
  String get quoteComposerChapterLabel;

  /// No description provided for @quoteComposerNoteLabel.
  ///
  /// In es, this message translates to:
  /// **'Nota privada'**
  String get quoteComposerNoteLabel;

  /// No description provided for @quoteComposerNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Añade una nota personal…'**
  String get quoteComposerNoteHint;

  /// No description provided for @quoteShareIncludeNote.
  ///
  /// In es, this message translates to:
  /// **'Incluir mi nota'**
  String get quoteShareIncludeNote;

  /// No description provided for @quoteShareIncludeNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Tu nota privada aparecerá en lo que compartas.'**
  String get quoteShareIncludeNoteHint;

  /// No description provided for @quotesWidgetShowNote.
  ///
  /// In es, this message translates to:
  /// **'Mostrar nota'**
  String get quotesWidgetShowNote;

  /// No description provided for @quotesWidgetShowNoteHint.
  ///
  /// In es, this message translates to:
  /// **'Muestra tu nota privada en el widget cuando la cita tenga una.'**
  String get quotesWidgetShowNoteHint;

  /// No description provided for @quoteBookPickerTitle.
  ///
  /// In es, this message translates to:
  /// **'¿De qué libro es la cita?'**
  String get quoteBookPickerTitle;

  /// No description provided for @quoteBookPickerFilterHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en tu biblioteca…'**
  String get quoteBookPickerFilterHint;

  /// No description provided for @quoteBookPickerCreate.
  ///
  /// In es, this message translates to:
  /// **'Crear libro'**
  String get quoteBookPickerCreate;

  /// No description provided for @homeActionAddQuote.
  ///
  /// In es, this message translates to:
  /// **'Anotación'**
  String get homeActionAddQuote;

  /// No description provided for @quotesCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Citas'**
  String get quotesCardTitle;

  /// No description provided for @annotationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Anotaciones'**
  String get annotationsTitle;

  /// No description provided for @annotationsCardTitle.
  ///
  /// In es, this message translates to:
  /// **'Anotaciones'**
  String get annotationsCardTitle;

  /// No description provided for @annotationsEmptyMessage.
  ///
  /// In es, this message translates to:
  /// **'Aún no se ha añadido ninguna anotación.'**
  String get annotationsEmptyMessage;

  /// No description provided for @annotationsSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en tus anotaciones…'**
  String get annotationsSearchHint;

  /// No description provided for @annotationCategoryNote.
  ///
  /// In es, this message translates to:
  /// **'Notas'**
  String get annotationCategoryNote;

  /// No description provided for @annotationCategoryTheory.
  ///
  /// In es, this message translates to:
  /// **'Teoría'**
  String get annotationCategoryTheory;

  /// No description provided for @annotationCategoryQuestion.
  ///
  /// In es, this message translates to:
  /// **'Preguntas'**
  String get annotationCategoryQuestion;

  /// No description provided for @annotationCategoryQuote.
  ///
  /// In es, this message translates to:
  /// **'Citas'**
  String get annotationCategoryQuote;

  /// No description provided for @annotationPin.
  ///
  /// In es, this message translates to:
  /// **'Fijar'**
  String get annotationPin;

  /// No description provided for @annotationUnpin.
  ///
  /// In es, this message translates to:
  /// **'Quitar fijado'**
  String get annotationUnpin;

  /// No description provided for @annotationPinLimit.
  ///
  /// In es, this message translates to:
  /// **'Puedes fijar hasta 3 anotaciones por libro.'**
  String get annotationPinLimit;

  /// No description provided for @annotationSpoiler.
  ///
  /// In es, this message translates to:
  /// **'Contiene spoilers'**
  String get annotationSpoiler;

  /// No description provided for @annotationFavorite.
  ///
  /// In es, this message translates to:
  /// **'Favorita'**
  String get annotationFavorite;

  /// No description provided for @annotationUnfavorite.
  ///
  /// In es, this message translates to:
  /// **'Quitar de favoritas'**
  String get annotationUnfavorite;

  /// No description provided for @annotationAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir anotación'**
  String get annotationAdd;

  /// No description provided for @annotationAddNote.
  ///
  /// In es, this message translates to:
  /// **'Añadir nota'**
  String get annotationAddNote;

  /// No description provided for @annotationAddQuote.
  ///
  /// In es, this message translates to:
  /// **'Añadir cita'**
  String get annotationAddQuote;

  /// No description provided for @annotationAddTheory.
  ///
  /// In es, this message translates to:
  /// **'Añadir teoría'**
  String get annotationAddTheory;

  /// No description provided for @annotationAddQuestion.
  ///
  /// In es, this message translates to:
  /// **'Añadir pregunta'**
  String get annotationAddQuestion;

  /// No description provided for @annotationFilterCategories.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get annotationFilterCategories;

  /// No description provided for @annotationFilterFavorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritas'**
  String get annotationFilterFavorites;

  /// No description provided for @annotationsFilterEmpty.
  ///
  /// In es, this message translates to:
  /// **'Ninguna anotación coincide con estos filtros.'**
  String get annotationsFilterEmpty;

  /// No description provided for @annotationConfigTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get annotationConfigTitle;

  /// No description provided for @annotationDeleteConfirmTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar esta anotación?'**
  String get annotationDeleteConfirmTitle;

  /// No description provided for @annotationDeleteConfirmMessage.
  ///
  /// In es, this message translates to:
  /// **'La anotación se eliminará definitivamente.'**
  String get annotationDeleteConfirmMessage;

  /// No description provided for @annotationCreated.
  ///
  /// In es, this message translates to:
  /// **'Anotación guardada'**
  String get annotationCreated;

  /// No description provided for @annotationComposerTitleNew.
  ///
  /// In es, this message translates to:
  /// **'Nueva anotación'**
  String get annotationComposerTitleNew;

  /// No description provided for @annotationComposerTitleEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar'**
  String get annotationComposerTitleEdit;

  /// No description provided for @annotationComposerTextHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe la anotación…'**
  String get annotationComposerTextHint;

  /// No description provided for @annotationActionsTooltip.
  ///
  /// In es, this message translates to:
  /// **'Acciones de la anotación'**
  String get annotationActionsTooltip;

  /// No description provided for @quotesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 cita} other{{count} citas}}'**
  String quotesCount(int count);

  /// No description provided for @quoteQuickActionTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva anotación'**
  String get quoteQuickActionTitle;

  /// No description provided for @quoteOcrTooltip.
  ///
  /// In es, this message translates to:
  /// **'Escanear con la cámara'**
  String get quoteOcrTooltip;

  /// No description provided for @quoteOcrTitle.
  ///
  /// In es, this message translates to:
  /// **'Selecciona las líneas'**
  String get quoteOcrTitle;

  /// No description provided for @quoteOcrInstructions.
  ///
  /// In es, this message translates to:
  /// **'Toca las líneas que forman la cita (mantén pulsado y arrastra para varias).'**
  String get quoteOcrInstructions;

  /// No description provided for @quoteOcrUseText.
  ///
  /// In es, this message translates to:
  /// **'Usar texto'**
  String get quoteOcrUseText;

  /// No description provided for @quoteOcrNoText.
  ///
  /// In es, this message translates to:
  /// **'No se reconoció texto en la foto.'**
  String get quoteOcrNoText;

  /// No description provided for @quoteOcrSelectAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todo'**
  String get quoteOcrSelectAll;

  /// No description provided for @quoteOcrClearSelection.
  ///
  /// In es, this message translates to:
  /// **'Limpiar selección'**
  String get quoteOcrClearSelection;

  /// No description provided for @quoteVoiceTooltip.
  ///
  /// In es, this message translates to:
  /// **'Dictar por voz'**
  String get quoteVoiceTooltip;

  /// No description provided for @quoteVoiceStopTooltip.
  ///
  /// In es, this message translates to:
  /// **'Detener dictado'**
  String get quoteVoiceStopTooltip;

  /// No description provided for @quoteVoiceListening.
  ///
  /// In es, this message translates to:
  /// **'Escuchando…'**
  String get quoteVoiceListening;

  /// No description provided for @quoteVoiceUnavailable.
  ///
  /// In es, this message translates to:
  /// **'El dictado por voz no está disponible en este dispositivo.'**
  String get quoteVoiceUnavailable;

  /// No description provided for @quoteVoiceLocaleFallback.
  ///
  /// In es, this message translates to:
  /// **'Tu idioma no está disponible para dictado; se usará el idioma del sistema.'**
  String get quoteVoiceLocaleFallback;

  /// No description provided for @quoteVoicePermissionTitle.
  ///
  /// In es, this message translates to:
  /// **'Se necesita acceso al micrófono'**
  String get quoteVoicePermissionTitle;

  /// No description provided for @quoteVoicePermissionBody.
  ///
  /// In es, this message translates to:
  /// **'Readendar necesita acceso al micrófono para dictar citas. Puedes activarlo en Ajustes.'**
  String get quoteVoicePermissionBody;

  /// No description provided for @quoteShareTitle.
  ///
  /// In es, this message translates to:
  /// **'Compartir cita'**
  String get quoteShareTitle;

  /// No description provided for @quoteShareTitleNote.
  ///
  /// In es, this message translates to:
  /// **'Compartir nota'**
  String get quoteShareTitleNote;

  /// No description provided for @quoteShareTitleTheory.
  ///
  /// In es, this message translates to:
  /// **'Compartir teoría'**
  String get quoteShareTitleTheory;

  /// No description provided for @quoteShareTitleQuestion.
  ///
  /// In es, this message translates to:
  /// **'Compartir pregunta'**
  String get quoteShareTitleQuestion;

  /// No description provided for @quoteShareImage.
  ///
  /// In es, this message translates to:
  /// **'Imagen'**
  String get quoteShareImage;

  /// No description provided for @quoteShareText.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get quoteShareText;

  /// No description provided for @quotesWidgetPreviewEmpty.
  ///
  /// In es, this message translates to:
  /// **'Añade tu primera cita'**
  String get quotesWidgetPreviewEmpty;

  /// No description provided for @quotesWidgetConfigTitle.
  ///
  /// In es, this message translates to:
  /// **'Widget de citas'**
  String get quotesWidgetConfigTitle;

  /// No description provided for @quotesWidgetConfigMode.
  ///
  /// In es, this message translates to:
  /// **'Qué mostrar'**
  String get quotesWidgetConfigMode;

  /// No description provided for @quotesWidgetConfigStyle.
  ///
  /// In es, this message translates to:
  /// **'Aspecto'**
  String get quotesWidgetConfigStyle;

  /// No description provided for @quotesWidgetModeAll.
  ///
  /// In es, this message translates to:
  /// **'Todas las citas'**
  String get quotesWidgetModeAll;

  /// No description provided for @quotesWidgetModeFavorites.
  ///
  /// In es, this message translates to:
  /// **'Favoritas'**
  String get quotesWidgetModeFavorites;

  /// No description provided for @quotesWidgetModeBook.
  ///
  /// In es, this message translates to:
  /// **'Un libro'**
  String get quotesWidgetModeBook;

  /// No description provided for @quotesWidgetModeFixed.
  ///
  /// In es, this message translates to:
  /// **'Una cita fija'**
  String get quotesWidgetModeFixed;

  /// No description provided for @quotesWidgetConfigCadence.
  ///
  /// In es, this message translates to:
  /// **'Intervalo de rotación'**
  String get quotesWidgetConfigCadence;

  /// No description provided for @quotesWidgetCadenceHourly.
  ///
  /// In es, this message translates to:
  /// **'Cada hora'**
  String get quotesWidgetCadenceHourly;

  /// No description provided for @quotesWidgetCadence6h.
  ///
  /// In es, this message translates to:
  /// **'Cada 6 horas'**
  String get quotesWidgetCadence6h;

  /// No description provided for @quotesWidgetCadenceDaily.
  ///
  /// In es, this message translates to:
  /// **'Cada día'**
  String get quotesWidgetCadenceDaily;

  /// No description provided for @quotesWidgetPickBook.
  ///
  /// In es, this message translates to:
  /// **'Elegir el libro'**
  String get quotesWidgetPickBook;

  /// No description provided for @quotesWidgetPickQuote.
  ///
  /// In es, this message translates to:
  /// **'Elegir la cita'**
  String get quotesWidgetPickQuote;

  /// No description provided for @quotesWidgetConfigAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir widget'**
  String get quotesWidgetConfigAdd;

  /// No description provided for @quotesWidgetConfigNeedQuotes.
  ///
  /// In es, this message translates to:
  /// **'Añade una cita primero para configurar el widget.'**
  String get quotesWidgetConfigNeedQuotes;

  /// No description provided for @quotesWidgetConfigEditTitle.
  ///
  /// In es, this message translates to:
  /// **'Editar widget'**
  String get quotesWidgetConfigEditTitle;

  /// No description provided for @quotesWidgetUpdatedToast.
  ///
  /// In es, this message translates to:
  /// **'Widget actualizado'**
  String get quotesWidgetUpdatedToast;

  /// No description provided for @kindleImportTitle.
  ///
  /// In es, this message translates to:
  /// **'Importar de Kindle'**
  String get kindleImportTitle;

  /// No description provided for @kindleImportIntro.
  ///
  /// In es, this message translates to:
  /// **'Importa tus subrayados de Kindle: conecta el Kindle al ordenador o usa la app, y elige el archivo «My Clippings.txt».'**
  String get kindleImportIntro;

  /// No description provided for @kindleImportPick.
  ///
  /// In es, this message translates to:
  /// **'Elegir archivo'**
  String get kindleImportPick;

  /// No description provided for @kindleImportInvalidFile.
  ///
  /// In es, this message translates to:
  /// **'No se pudo leer el archivo.'**
  String get kindleImportInvalidFile;

  /// No description provided for @kindleImportNoHighlights.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron subrayados en el archivo.'**
  String get kindleImportNoHighlights;

  /// No description provided for @kindleImportGroups.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 libro con subrayados} other{{count} libros con subrayados}}'**
  String kindleImportGroups(int count);

  /// No description provided for @kindleImportSkipped.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 nota/marcador omitido} other{{count} notas/marcadores omitidos}}'**
  String kindleImportSkipped(int count);

  /// No description provided for @kindleImportDuplicates.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 duplicado} other{{count} duplicados}}'**
  String kindleImportDuplicates(int count);

  /// No description provided for @kindleImportUnmatched.
  ///
  /// In es, this message translates to:
  /// **'Sin libro en tu biblioteca. Toca para elegirlo'**
  String get kindleImportUnmatched;

  /// No description provided for @kindleImportSuggested.
  ///
  /// In es, this message translates to:
  /// **'Sugerido'**
  String get kindleImportSuggested;

  /// No description provided for @kindleImportStart.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, =0{Importar} one{Importar 1 cita} other{Importar {count} citas}}'**
  String kindleImportStart(int count);

  /// No description provided for @kindleImportProgress.
  ///
  /// In es, this message translates to:
  /// **'Importando citas…'**
  String get kindleImportProgress;

  /// No description provided for @kindleImportDone.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{¡1 cita importada!} other{¡{count} citas importadas!}}'**
  String kindleImportDone(int count);

  /// No description provided for @kindleImportFailed.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 cita falló} other{{count} citas fallaron}}'**
  String kindleImportFailed(int count);

  /// No description provided for @kindleImportContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get kindleImportContinue;

  /// No description provided for @kindleImportReviewTitle.
  ///
  /// In es, this message translates to:
  /// **'Revisa las citas'**
  String get kindleImportReviewTitle;

  /// No description provided for @kindleImportReviewSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desmarca las que no quieras importar.'**
  String get kindleImportReviewSubtitle;

  /// No description provided for @kindleImportSelectAll.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar todas'**
  String get kindleImportSelectAll;

  /// No description provided for @kindleImportGoToQuotes.
  ///
  /// In es, this message translates to:
  /// **'Ir a mis anotaciones'**
  String get kindleImportGoToQuotes;

  /// No description provided for @kindleImportRetry.
  ///
  /// In es, this message translates to:
  /// **'Volver a intentar'**
  String get kindleImportRetry;

  /// No description provided for @kindleImportErrorTitle.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron importar las citas.'**
  String get kindleImportErrorTitle;

  /// No description provided for @quoteDailyNotifTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu cita del día 📖'**
  String get quoteDailyNotifTitle;

  /// No description provided for @quoteDailySettingTitle.
  ///
  /// In es, this message translates to:
  /// **'Cita del día'**
  String get quoteDailySettingTitle;

  /// No description provided for @quoteDailySettingSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Una notificación diaria con una cita de tus libros.'**
  String get quoteDailySettingSubtitle;

  /// No description provided for @quoteDailyHourLabel.
  ///
  /// In es, this message translates to:
  /// **'Hora de la cita del día'**
  String get quoteDailyHourLabel;

  /// No description provided for @timeJustNow.
  ///
  /// In es, this message translates to:
  /// **'hace un momento'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {minutes} min'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {hours} h'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeDaysAgo.
  ///
  /// In es, this message translates to:
  /// **'hace {days} d'**
  String timeDaysAgo(int days);

  /// Title of the soft in-app store review modal
  ///
  /// In es, this message translates to:
  /// **'¿Te está gustando Readendar?'**
  String get storeReviewTitle;

  /// Short body copy for the soft store review modal
  ///
  /// In es, this message translates to:
  /// **'Una reseña breve ayuda a otros lectores a encontrarnos.'**
  String get storeReviewBody;

  /// CTA that opens the Apple App Store listing
  ///
  /// In es, this message translates to:
  /// **'Valorar en App Store'**
  String get storeReviewCtaAppStore;

  /// CTA that opens the Google Play listing
  ///
  /// In es, this message translates to:
  /// **'Valorar en Google Play'**
  String get storeReviewCtaPlayStore;

  /// Dismiss the soft store review modal
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get storeReviewNotNow;

  /// Friendly profile invite title asking for a store review (soft, not imperative)
  ///
  /// In es, this message translates to:
  /// **'¿Nos echas una mano?'**
  String get storeReviewSettingsRow;

  /// Short friendly profile invite body for leaving a store review
  ///
  /// In es, this message translates to:
  /// **'Si te gusta, una reseñita en la tienda ayuda mucho.'**
  String get storeReviewSettingsHint;

  /// Snackbar when the store listing URL fails to open
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir la tienda. Inténtalo de nuevo.'**
  String get storeReviewOpenFailed;

  /// Title of the soft in-app feedback modal
  ///
  /// In es, this message translates to:
  /// **'¿Cómo va Readendar?'**
  String get productFeedbackTitle;

  /// Body inviting useful feedback about the whole app
  ///
  /// In es, this message translates to:
  /// **'Si algo falla, no encaja o echas de menos una pieza en cualquier parte de la app, cuéntanoslo. Lo leemos todo.'**
  String get productFeedbackBody;

  /// Primary CTA that opens the in-app feedback form
  ///
  /// In es, this message translates to:
  /// **'Enviar feedback'**
  String get productFeedbackCta;

  /// Dismiss action for the in-app feedback modal
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get productFeedbackNotNow;

  /// Title of the in-app store update prompt
  ///
  /// In es, this message translates to:
  /// **'Actualización disponible'**
  String get appUpdateTitle;

  /// Generic body when store What's New is missing
  ///
  /// In es, this message translates to:
  /// **'Hay una versión nueva de Readendar en la tienda.'**
  String get appUpdateBody;

  /// Primary button that opens the store listing
  ///
  /// In es, this message translates to:
  /// **'Actualizar'**
  String get appUpdateCta;

  /// Dismiss the store update prompt until a newer version
  ///
  /// In es, this message translates to:
  /// **'Más tarde'**
  String get appUpdateLater;

  /// Debug tools hint for previewing the store review modal
  ///
  /// In es, this message translates to:
  /// **'Muestra el modal de valoración de la tienda sin guardar preferencias (solo vista previa).'**
  String get debugStoreReviewHint;

  /// Debug tools button to open the store review modal preview
  ///
  /// In es, this message translates to:
  /// **'Previsualizar modal de valoración'**
  String get debugStoreReviewAction;

  /// Debug Tools: hint for in-app feedback modal preview
  ///
  /// In es, this message translates to:
  /// **'Muestra el modal de feedback sin guardar preferencias (solo vista previa).'**
  String get debugProductFeedbackHint;

  /// Debug Tools: button to preview the in-app feedback modal
  ///
  /// In es, this message translates to:
  /// **'Previsualizar modal de feedback'**
  String get debugProductFeedbackAction;

  /// Debug tools hint for previewing the in-app update prompt
  ///
  /// In es, this message translates to:
  /// **'Muestra el aviso de actualización sin posponer ni consultar la tienda (solo vista previa).'**
  String get debugAppUpdateHint;

  /// Debug tools button to preview the update prompt with What's New notes
  ///
  /// In es, this message translates to:
  /// **'Previsualizar actualización con novedades'**
  String get debugAppUpdateAction;

  /// Debug tools button to preview the update prompt with generic body copy
  ///
  /// In es, this message translates to:
  /// **'Previsualizar actualización genérica'**
  String get debugAppUpdateGenericAction;

  /// Sample What's New body used by the debug update-prompt preview
  ///
  /// In es, this message translates to:
  /// **'Novedades de esta versión\n\n• Widgets de inicio\n• Listas de biblioteca más rápidas'**
  String get debugAppUpdateSampleNotes;

  /// Debug tools hint for the Reading Chapter archetype gallery
  ///
  /// In es, this message translates to:
  /// **'Muestra las 15 tarjetas de arquetipo del capítulo lector con el diseño real.'**
  String get debugArchetypePreviewHint;

  /// Debug tools button that opens the archetype card gallery
  ///
  /// In es, this message translates to:
  /// **'Ver arquetipos lectores'**
  String get debugArchetypePreviewAction;

  /// App bar title for the debug archetype gallery
  ///
  /// In es, this message translates to:
  /// **'Arquetipos lectores'**
  String get debugArchetypePreviewTitle;

  /// Intro copy above the debug archetype gallery
  ///
  /// In es, this message translates to:
  /// **'Las 15 combinaciones de gusto, ritmo, novedad y escala, con el mismo cromo invertido que el capítulo anual.'**
  String get debugArchetypePreviewIntro;

  /// No description provided for @shortcutLogProgressTitle.
  ///
  /// In es, this message translates to:
  /// **'Registrar progreso'**
  String get shortcutLogProgressTitle;

  /// No description provided for @shortcutWhatsNextTitle.
  ///
  /// In es, this message translates to:
  /// **'Qué toca leer'**
  String get shortcutWhatsNextTitle;

  /// No description provided for @bookCreateActions.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get bookCreateActions;

  /// No description provided for @planWizardBack.
  ///
  /// In es, this message translates to:
  /// **'Atrás'**
  String get planWizardBack;

  /// No description provided for @planWizardContinue.
  ///
  /// In es, this message translates to:
  /// **'Continuar'**
  String get planWizardContinue;

  /// Wizard progress label
  ///
  /// In es, this message translates to:
  /// **'Paso {step} de {total}'**
  String planWizardStepOf(int step, int total);

  /// No description provided for @planWizardGoalTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo quieres planificar?'**
  String get planWizardGoalTitle;

  /// No description provided for @planModePaceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige cuánto leer cada día. Calculamos cuándo terminas'**
  String get planModePaceSubtitle;

  /// No description provided for @planModeDeadlineSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige una fecha de fin. Calculamos cuánto leer al día'**
  String get planModeDeadlineSubtitle;

  /// No description provided for @planModeBeforeEvent.
  ///
  /// In es, this message translates to:
  /// **'Antes de un evento'**
  String get planModeBeforeEvent;

  /// No description provided for @planModeBeforeEventSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Elige algo de tu calendario. Planificamos terminar ese día'**
  String get planModeBeforeEventSubtitle;

  /// No description provided for @planHistorySummaryBeforeEvent.
  ///
  /// In es, this message translates to:
  /// **'Antes de un evento'**
  String get planHistorySummaryBeforeEvent;

  /// No description provided for @planUntilHere.
  ///
  /// In es, this message translates to:
  /// **'Planificar hasta aquí'**
  String get planUntilHere;

  /// No description provided for @planUntilHerePastHint.
  ///
  /// In es, this message translates to:
  /// **'Elige un evento de hoy o futuro.'**
  String get planUntilHerePastHint;

  /// No description provided for @planPickEventTitle.
  ///
  /// In es, this message translates to:
  /// **'Elige un evento'**
  String get planPickEventTitle;

  /// No description provided for @planPickEventHint.
  ///
  /// In es, this message translates to:
  /// **'Toca un evento y luego Planificar hasta aquí. Los días vacíos no se pueden elegir.'**
  String get planPickEventHint;

  /// No description provided for @planPickEventEmptyDay.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos este día. Elige un día que tenga alguno.'**
  String get planPickEventEmptyDay;

  /// No description provided for @planPickEventEmptyMonth.
  ///
  /// In es, this message translates to:
  /// **'No hay eventos este mes. Prueba otro mes.'**
  String get planPickEventEmptyMonth;

  /// No description provided for @planPickEventCta.
  ///
  /// In es, this message translates to:
  /// **'Elegir del calendario'**
  String get planPickEventCta;

  /// No description provided for @planAnchorEvent.
  ///
  /// In es, this message translates to:
  /// **'Terminar para el evento'**
  String get planAnchorEvent;

  /// No description provided for @planCalcNeedsEvent.
  ///
  /// In es, this message translates to:
  /// **'Elige un evento del calendario como meta.'**
  String get planCalcNeedsEvent;

  /// No description provided for @planSectionBook.
  ///
  /// In es, this message translates to:
  /// **'Libro'**
  String get planSectionBook;

  /// No description provided for @planCalcNeedsFields.
  ///
  /// In es, this message translates to:
  /// **'Completa los campos obligatorios para calcular.'**
  String get planCalcNeedsFields;

  /// No description provided for @planPickDate.
  ///
  /// In es, this message translates to:
  /// **'Elige una fecha'**
  String get planPickDate;

  /// No description provided for @bookCoverEnlarge.
  ///
  /// In es, this message translates to:
  /// **'Ver portada'**
  String get bookCoverEnlarge;

  /// No description provided for @bookCategoryAdventure.
  ///
  /// In es, this message translates to:
  /// **'Aventuras'**
  String get bookCategoryAdventure;

  /// No description provided for @bookCategoryArtsEntertainment.
  ///
  /// In es, this message translates to:
  /// **'Arte y entretenimiento'**
  String get bookCategoryArtsEntertainment;

  /// No description provided for @bookCategoryBiographyMemoir.
  ///
  /// In es, this message translates to:
  /// **'Biografía y memorias'**
  String get bookCategoryBiographyMemoir;

  /// No description provided for @bookCategoryBusinessEconomics.
  ///
  /// In es, this message translates to:
  /// **'Negocios y economía'**
  String get bookCategoryBusinessEconomics;

  /// No description provided for @bookCategoryChildrenYoungAdult.
  ///
  /// In es, this message translates to:
  /// **'Infantil y juvenil'**
  String get bookCategoryChildrenYoungAdult;

  /// No description provided for @bookCategoryComicsManga.
  ///
  /// In es, this message translates to:
  /// **'Cómics y manga'**
  String get bookCategoryComicsManga;

  /// No description provided for @bookCategoryEducationReference.
  ///
  /// In es, this message translates to:
  /// **'Educación y referencia'**
  String get bookCategoryEducationReference;

  /// No description provided for @bookCategoryFantasy.
  ///
  /// In es, this message translates to:
  /// **'Fantasía'**
  String get bookCategoryFantasy;

  /// No description provided for @bookCategoryFiction.
  ///
  /// In es, this message translates to:
  /// **'Ficción'**
  String get bookCategoryFiction;

  /// No description provided for @bookCategoryHealthWellness.
  ///
  /// In es, this message translates to:
  /// **'Salud y bienestar'**
  String get bookCategoryHealthWellness;

  /// No description provided for @bookCategoryHistoricalFiction.
  ///
  /// In es, this message translates to:
  /// **'Ficción histórica'**
  String get bookCategoryHistoricalFiction;

  /// No description provided for @bookCategoryHistory.
  ///
  /// In es, this message translates to:
  /// **'Historia'**
  String get bookCategoryHistory;

  /// No description provided for @bookCategoryHorrorParanormal.
  ///
  /// In es, this message translates to:
  /// **'Terror y paranormal'**
  String get bookCategoryHorrorParanormal;

  /// No description provided for @bookCategoryHumorSatire.
  ///
  /// In es, this message translates to:
  /// **'Humor y sátira'**
  String get bookCategoryHumorSatire;

  /// No description provided for @bookCategoryLifestyleLeisure.
  ///
  /// In es, this message translates to:
  /// **'Estilo de vida y ocio'**
  String get bookCategoryLifestyleLeisure;

  /// No description provided for @bookCategoryLiteraryClassics.
  ///
  /// In es, this message translates to:
  /// **'Ficción literaria y clásicos'**
  String get bookCategoryLiteraryClassics;

  /// No description provided for @bookCategoryMysteryCrime.
  ///
  /// In es, this message translates to:
  /// **'Misterio y crimen'**
  String get bookCategoryMysteryCrime;

  /// No description provided for @bookCategoryNonfiction.
  ///
  /// In es, this message translates to:
  /// **'No ficción'**
  String get bookCategoryNonfiction;

  /// No description provided for @bookCategoryOther.
  ///
  /// In es, this message translates to:
  /// **'Otros'**
  String get bookCategoryOther;

  /// No description provided for @bookCategoryPhilosophy.
  ///
  /// In es, this message translates to:
  /// **'Filosofía'**
  String get bookCategoryPhilosophy;

  /// No description provided for @bookCategoryPoetryDrama.
  ///
  /// In es, this message translates to:
  /// **'Poesía y teatro'**
  String get bookCategoryPoetryDrama;

  /// No description provided for @bookCategoryPoliticsSociety.
  ///
  /// In es, this message translates to:
  /// **'Política y sociedad'**
  String get bookCategoryPoliticsSociety;

  /// No description provided for @bookCategoryPsychology.
  ///
  /// In es, this message translates to:
  /// **'Psicología'**
  String get bookCategoryPsychology;

  /// No description provided for @bookCategoryReligionSpirituality.
  ///
  /// In es, this message translates to:
  /// **'Religión y espiritualidad'**
  String get bookCategoryReligionSpirituality;

  /// No description provided for @bookCategoryRomance.
  ///
  /// In es, this message translates to:
  /// **'Romance'**
  String get bookCategoryRomance;

  /// No description provided for @bookCategoryScienceFiction.
  ///
  /// In es, this message translates to:
  /// **'Ciencia ficción'**
  String get bookCategoryScienceFiction;

  /// No description provided for @bookCategoryScienceNature.
  ///
  /// In es, this message translates to:
  /// **'Ciencia y naturaleza'**
  String get bookCategoryScienceNature;

  /// No description provided for @bookCategorySelfHelp.
  ///
  /// In es, this message translates to:
  /// **'Autoayuda'**
  String get bookCategorySelfHelp;

  /// No description provided for @bookCategoryTechnology.
  ///
  /// In es, this message translates to:
  /// **'Tecnología'**
  String get bookCategoryTechnology;

  /// No description provided for @bookCategoryThriller.
  ///
  /// In es, this message translates to:
  /// **'Thriller'**
  String get bookCategoryThriller;

  /// No description provided for @eventReminderCannotFire.
  ///
  /// In es, this message translates to:
  /// **'Este recordatorio no puede avisarte porque su hora ya pasó. Elige una fecha posterior o un aviso más corto.'**
  String get eventReminderCannotFire;

  /// No description provided for @myStatsActiveDays.
  ///
  /// In es, this message translates to:
  /// **'Días activos'**
  String get myStatsActiveDays;

  /// No description provided for @myStatsAllTime.
  ///
  /// In es, this message translates to:
  /// **'Histórico'**
  String get myStatsAllTime;

  /// No description provided for @myStatsAverage.
  ///
  /// In es, this message translates to:
  /// **'Media'**
  String get myStatsAverage;

  /// No description provided for @myStatsBooksSeries.
  ///
  /// In es, this message translates to:
  /// **'Libros'**
  String get myStatsBooksSeries;

  /// No description provided for @myStatsComparedPreviousYear.
  ///
  /// In es, this message translates to:
  /// **'Frente al año anterior'**
  String get myStatsComparedPreviousYear;

  /// No description provided for @myStatsConsistency.
  ///
  /// In es, this message translates to:
  /// **'Constancia lectora'**
  String get myStatsConsistency;

  /// No description provided for @myStatsCurrentDayStreak.
  ///
  /// In es, this message translates to:
  /// **'Racha diaria actual'**
  String get myStatsCurrentDayStreak;

  /// No description provided for @myStatsFinishedBookPages.
  ///
  /// In es, this message translates to:
  /// **'Páginas de libros terminados'**
  String get myStatsFinishedBookPages;

  /// No description provided for @myStatsFormatAudiobook.
  ///
  /// In es, this message translates to:
  /// **'Audiolibro'**
  String get myStatsFormatAudiobook;

  /// No description provided for @myStatsFormatEbook.
  ///
  /// In es, this message translates to:
  /// **'Ebook'**
  String get myStatsFormatEbook;

  /// No description provided for @myStatsFormatOther.
  ///
  /// In es, this message translates to:
  /// **'Otro'**
  String get myStatsFormatOther;

  /// No description provided for @myStatsFormatPhysical.
  ///
  /// In es, this message translates to:
  /// **'Papel'**
  String get myStatsFormatPhysical;

  /// No description provided for @myStatsFormats.
  ///
  /// In es, this message translates to:
  /// **'Formatos'**
  String get myStatsFormats;

  /// No description provided for @myStatsGenreAffinity.
  ///
  /// In es, this message translates to:
  /// **'Afinidad por género'**
  String get myStatsGenreAffinity;

  /// No description provided for @myStatsHighRatings.
  ///
  /// In es, this message translates to:
  /// **'Valorados con 4 estrellas o más'**
  String get myStatsHighRatings;

  /// No description provided for @myStatsLibraryMix.
  ///
  /// In es, this message translates to:
  /// **'Composición de la biblioteca'**
  String get myStatsLibraryMix;

  /// No description provided for @myStatsLoggedPages.
  ///
  /// In es, this message translates to:
  /// **'Páginas leídas'**
  String get myStatsLoggedPages;

  /// No description provided for @myStatsRatingDistribution.
  ///
  /// In es, this message translates to:
  /// **'Distribución de valoraciones'**
  String get myStatsRatingDistribution;

  /// No description provided for @myStatsRepeatAuthors.
  ///
  /// In es, this message translates to:
  /// **'Autores repetidos'**
  String get myStatsRepeatAuthors;

  /// No description provided for @myStatsThisYear.
  ///
  /// In es, this message translates to:
  /// **'Este año'**
  String get myStatsThisYear;

  /// No description provided for @myStatsUnitDays.
  ///
  /// In es, this message translates to:
  /// **'días'**
  String get myStatsUnitDays;

  /// No description provided for @myStatsYearEvolution.
  ///
  /// In es, this message translates to:
  /// **'Evolución anual'**
  String get myStatsYearEvolution;

  /// No description provided for @quoteVoiceTryAgain.
  ///
  /// In es, this message translates to:
  /// **'No se pudo iniciar el dictado por voz. Inténtalo de nuevo.'**
  String get quoteVoiceTryAgain;

  /// No description provided for @annotationBodyTooLong.
  ///
  /// In es, this message translates to:
  /// **'Esta anotación debe tener como máximo {maxLength} caracteres.'**
  String annotationBodyTooLong(int maxLength);

  /// No description provided for @metaPublicationDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha de publicación'**
  String get metaPublicationDate;

  /// No description provided for @customFieldsTitle.
  ///
  /// In es, this message translates to:
  /// **'Campos personalizados'**
  String get customFieldsTitle;

  /// No description provided for @customFieldsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay campos personalizados'**
  String get customFieldsEmpty;

  /// No description provided for @customFieldsAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir campo'**
  String get customFieldsAdd;

  /// No description provided for @customFieldsEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar campo'**
  String get customFieldsEdit;

  /// No description provided for @customFieldsName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del campo'**
  String get customFieldsName;

  /// No description provided for @customFieldsType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de campo'**
  String get customFieldsType;

  /// No description provided for @customFieldsDeleteTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el campo personalizado?'**
  String get customFieldsDeleteTitle;

  /// No description provided for @customFieldsDeleteMessage.
  ///
  /// In es, this message translates to:
  /// **'Los libros que usan este campo conservarán sus valores hasta que confirmes la eliminación permanente.'**
  String get customFieldsDeleteMessage;

  /// No description provided for @customFieldsDeleteValuesTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar el campo y sus valores?'**
  String get customFieldsDeleteValuesTitle;

  /// No description provided for @customFieldsDeleteValuesMessage.
  ///
  /// In es, this message translates to:
  /// **'Esto elimina permanentemente este campo y sus valores de todos los libros.'**
  String get customFieldsDeleteValuesMessage;

  /// No description provided for @customFieldsManage.
  ///
  /// In es, this message translates to:
  /// **'Gestionar campos'**
  String get customFieldsManage;

  /// No description provided for @customFieldsOption.
  ///
  /// In es, this message translates to:
  /// **'Opción'**
  String get customFieldsOption;

  /// No description provided for @customFieldsAddOption.
  ///
  /// In es, this message translates to:
  /// **'Añadir opción'**
  String get customFieldsAddOption;

  /// No description provided for @customFieldsYes.
  ///
  /// In es, this message translates to:
  /// **'Sí'**
  String get customFieldsYes;

  /// No description provided for @customFieldsNo.
  ///
  /// In es, this message translates to:
  /// **'No'**
  String get customFieldsNo;

  /// No description provided for @customFieldsIcon.
  ///
  /// In es, this message translates to:
  /// **'Icono'**
  String get customFieldsIcon;

  /// No description provided for @customFieldsDeleteOptionTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar la opción?'**
  String get customFieldsDeleteOptionTitle;

  /// No description provided for @customFieldsDeleteOptionMessage.
  ///
  /// In es, this message translates to:
  /// **'Los libros que usan esta opción perderán el valor del campo personalizado.'**
  String get customFieldsDeleteOptionMessage;

  /// No description provided for @customFieldsTextMode.
  ///
  /// In es, this message translates to:
  /// **'Estilo de texto'**
  String get customFieldsTextMode;

  /// No description provided for @customFieldsSingleLine.
  ///
  /// In es, this message translates to:
  /// **'Una línea'**
  String get customFieldsSingleLine;

  /// No description provided for @customFieldsMultiline.
  ///
  /// In es, this message translates to:
  /// **'Varias líneas'**
  String get customFieldsMultiline;

  /// No description provided for @customFieldsShowTime.
  ///
  /// In es, this message translates to:
  /// **'Mostrar hora'**
  String get customFieldsShowTime;

  /// No description provided for @customFieldsShowTimeHint.
  ///
  /// In es, this message translates to:
  /// **'Incluye la hora al editar y mostrar este campo. Activado por defecto.'**
  String get customFieldsShowTimeHint;

  /// No description provided for @customFieldsUnavailable.
  ///
  /// In es, this message translates to:
  /// **'No se pudieron cargar los campos personalizados. Aun así puedes guardar los demás detalles del libro.'**
  String get customFieldsUnavailable;

  /// No description provided for @customFieldsSaved.
  ///
  /// In es, this message translates to:
  /// **'Campo personalizado guardado.'**
  String get customFieldsSaved;

  /// No description provided for @customFieldsDeleted.
  ///
  /// In es, this message translates to:
  /// **'Campo personalizado eliminado.'**
  String get customFieldsDeleted;

  /// No description provided for @customFieldsTypeText.
  ///
  /// In es, this message translates to:
  /// **'Texto'**
  String get customFieldsTypeText;

  /// No description provided for @customFieldsTypeNumber.
  ///
  /// In es, this message translates to:
  /// **'Número'**
  String get customFieldsTypeNumber;

  /// No description provided for @customFieldsTypeDateTime.
  ///
  /// In es, this message translates to:
  /// **'Fecha y hora'**
  String get customFieldsTypeDateTime;

  /// No description provided for @customFieldsTypeBoolean.
  ///
  /// In es, this message translates to:
  /// **'Sí o no'**
  String get customFieldsTypeBoolean;

  /// No description provided for @customFieldsOptions.
  ///
  /// In es, this message translates to:
  /// **'Opciones'**
  String get customFieldsOptions;

  /// No description provided for @customFieldsTypeSingleSelect.
  ///
  /// In es, this message translates to:
  /// **'Selector simple'**
  String get customFieldsTypeSingleSelect;

  /// No description provided for @customFieldsStandard.
  ///
  /// In es, this message translates to:
  /// **'Estándar'**
  String get customFieldsStandard;

  /// No description provided for @customFieldsShowField.
  ///
  /// In es, this message translates to:
  /// **'Mostrar campo'**
  String get customFieldsShowField;

  /// No description provided for @customFieldsHideField.
  ///
  /// In es, this message translates to:
  /// **'Ocultar campo'**
  String get customFieldsHideField;

  /// No description provided for @profileThemes.
  ///
  /// In es, this message translates to:
  /// **'Temas'**
  String get profileThemes;

  /// No description provided for @themesTitle.
  ///
  /// In es, this message translates to:
  /// **'Temas'**
  String get themesTitle;

  /// No description provided for @themesIntro.
  ///
  /// In es, this message translates to:
  /// **'Elige un estilo visual completo. El brillo sigue siendo independiente.'**
  String get themesIntro;

  /// No description provided for @themeOriginal.
  ///
  /// In es, this message translates to:
  /// **'Original'**
  String get themeOriginal;

  /// No description provided for @themeJade.
  ///
  /// In es, this message translates to:
  /// **'Jade'**
  String get themeJade;

  /// No description provided for @themeCelestial.
  ///
  /// In es, this message translates to:
  /// **'Celestial'**
  String get themeCelestial;

  /// No description provided for @themeOcean.
  ///
  /// In es, this message translates to:
  /// **'Océano'**
  String get themeOcean;

  /// No description provided for @themeNoir.
  ///
  /// In es, this message translates to:
  /// **'Noir'**
  String get themeNoir;

  /// No description provided for @themeSapphire.
  ///
  /// In es, this message translates to:
  /// **'Sapphire'**
  String get themeSapphire;

  /// No description provided for @themeVelvet.
  ///
  /// In es, this message translates to:
  /// **'Velvet'**
  String get themeVelvet;

  /// No description provided for @themeAurora.
  ///
  /// In es, this message translates to:
  /// **'Aurora'**
  String get themeAurora;

  /// No description provided for @themeArcade.
  ///
  /// In es, this message translates to:
  /// **'Arcade'**
  String get themeArcade;

  /// No description provided for @themePop.
  ///
  /// In es, this message translates to:
  /// **'Pop'**
  String get themePop;

  /// No description provided for @themeEthereal.
  ///
  /// In es, this message translates to:
  /// **'Etéreo'**
  String get themeEthereal;

  /// No description provided for @themeStormbound.
  ///
  /// In es, this message translates to:
  /// **'Tormenta'**
  String get themeStormbound;

  /// No description provided for @themeEvercourt.
  ///
  /// In es, this message translates to:
  /// **'Cortes'**
  String get themeEvercourt;

  /// No description provided for @themeNeonMoon.
  ///
  /// In es, this message translates to:
  /// **'Neón'**
  String get themeNeonMoon;

  /// No description provided for @themeTrail.
  ///
  /// In es, this message translates to:
  /// **'Rastro'**
  String get themeTrail;

  /// No description provided for @themeSerpents.
  ///
  /// In es, this message translates to:
  /// **'Serpientes'**
  String get themeSerpents;

  /// No description provided for @themeThornCrown.
  ///
  /// In es, this message translates to:
  /// **'Espina'**
  String get themeThornCrown;

  /// No description provided for @themeIridescent.
  ///
  /// In es, this message translates to:
  /// **'Prisma'**
  String get themeIridescent;

  /// No description provided for @themeLastLight.
  ///
  /// In es, this message translates to:
  /// **'Sol'**
  String get themeLastLight;

  /// No description provided for @premiumThemesEntryTitle.
  ///
  /// In es, this message translates to:
  /// **'Temas Premium'**
  String get premiumThemesEntryTitle;

  /// No description provided for @premiumThemesTitle.
  ///
  /// In es, this message translates to:
  /// **'Temas Premium'**
  String get premiumThemesTitle;

  /// No description provided for @premiumThemesHeroTitle.
  ///
  /// In es, this message translates to:
  /// **'Colección de temas animados'**
  String get premiumThemesHeroTitle;

  /// No description provided for @premiumCoverAtmosphereTitle.
  ///
  /// In es, this message translates to:
  /// **'Atmósfera de portada'**
  String get premiumCoverAtmosphereTitle;

  /// No description provided for @premiumCoverAtmosphereHint.
  ///
  /// In es, this message translates to:
  /// **'Usa localmente los colores de la portada en detalles cinematográficos y celebraciones.'**
  String get premiumCoverAtmosphereHint;

  /// No description provided for @premiumCoverAtmosphereSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar la preferencia de atmósfera de portada.'**
  String get premiumCoverAtmosphereSaveError;

  /// No description provided for @premiumThemeUnavailable.
  ///
  /// In es, this message translates to:
  /// **'Este tema Premium no está disponible en esta instalación.'**
  String get premiumThemeUnavailable;

  /// No description provided for @themeApplied.
  ///
  /// In es, this message translates to:
  /// **'Tema aplicado.'**
  String get themeApplied;

  /// No description provided for @themeSaveError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo guardar el tema.'**
  String get themeSaveError;

  /// No description provided for @themeWidgetSyncWarning.
  ///
  /// In es, this message translates to:
  /// **'Tema aplicado, pero no se pudieron actualizar los widgets.'**
  String get themeWidgetSyncWarning;

  /// No description provided for @readingChapterTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu capítulo lector'**
  String get readingChapterTitle;

  /// No description provided for @readingChapterProfileSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Revive el mes y el año en que tus lecturas se convirtieron en historia.'**
  String get readingChapterProfileSubtitle;

  /// No description provided for @readingChapterProfileLatest.
  ///
  /// In es, this message translates to:
  /// **'Último: {period}'**
  String readingChapterProfileLatest(String period);

  /// No description provided for @readingChapterNew.
  ///
  /// In es, this message translates to:
  /// **'NUEVO'**
  String get readingChapterNew;

  /// No description provided for @readingChapterHeroTitle.
  ///
  /// In es, this message translates to:
  /// **'Toda vida lectora deja una forma'**
  String get readingChapterHeroTitle;

  /// No description provided for @readingChapterHeroBody.
  ///
  /// In es, this message translates to:
  /// **'Tus meses y años terminados, reconstruidos desde los libros que realmente tocaste.'**
  String get readingChapterHeroBody;

  /// No description provided for @readingChapterNewAvailable.
  ///
  /// In es, this message translates to:
  /// **'Hay un capítulo nuevo listo'**
  String get readingChapterNewAvailable;

  /// No description provided for @readingChapterAll.
  ///
  /// In es, this message translates to:
  /// **'Todo'**
  String get readingChapterAll;

  /// No description provided for @readingChapterMonths.
  ///
  /// In es, this message translates to:
  /// **'Meses'**
  String get readingChapterMonths;

  /// No description provided for @readingChapterYears.
  ///
  /// In es, this message translates to:
  /// **'Años'**
  String get readingChapterYears;

  /// No description provided for @readingChapterArchiveTitle.
  ///
  /// In es, this message translates to:
  /// **'Archivo de capítulos'**
  String get readingChapterArchiveTitle;

  /// No description provided for @readingChapterArchiveWorks.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 obra} other{{count} obras}}'**
  String readingChapterArchiveWorks(int count);

  /// No description provided for @readingChapterArchiveEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'{kind, select, all{Un mes o año terminado con lectura crea tu capítulo} month{Un mes terminado con lectura crea tu capítulo} year{Un año terminado con lectura crea tu capítulo} other{Un mes o año terminado con lectura crea tu capítulo}}'**
  String readingChapterArchiveEmptyTitle(String kind);

  /// No description provided for @readingChapterOpeningTitle.
  ///
  /// In es, this message translates to:
  /// **'Capítulo de apertura'**
  String get readingChapterOpeningTitle;

  /// No description provided for @readingChapterOpeningMonth.
  ///
  /// In es, this message translates to:
  /// **'TU {period} ENTRE LIBROS'**
  String readingChapterOpeningMonth(String period);

  /// No description provided for @readingChapterOpeningYear.
  ///
  /// In es, this message translates to:
  /// **'TU {period} ENTRE LIBROS'**
  String readingChapterOpeningYear(String period);

  /// No description provided for @readingChapterOpeningBody.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{Un libro dio forma a este capítulo.} other{{count} libros dieron forma a este capítulo.}}'**
  String readingChapterOpeningBody(int count);

  /// No description provided for @readingChapterTotalsTitle.
  ///
  /// In es, this message translates to:
  /// **'Los números detrás de las páginas'**
  String get readingChapterTotalsTitle;

  /// No description provided for @readingChapterUniqueWorks.
  ///
  /// In es, this message translates to:
  /// **'obras únicas'**
  String get readingChapterUniqueWorks;

  /// No description provided for @readingChapterOccurrences.
  ///
  /// In es, this message translates to:
  /// **'lecturas terminadas'**
  String get readingChapterOccurrences;

  /// No description provided for @readingChapterPages.
  ///
  /// In es, this message translates to:
  /// **'páginas en total'**
  String get readingChapterPages;

  /// No description provided for @readingChapterPageCoverage.
  ///
  /// In es, this message translates to:
  /// **'Recuento de páginas en {known} de {total} libros'**
  String readingChapterPageCoverage(int known, int total);

  /// No description provided for @readingChapterRhythmTitle.
  ///
  /// In es, this message translates to:
  /// **'Lectura por periodo'**
  String get readingChapterRhythmTitle;

  /// No description provided for @readingChapterRhythmBody.
  ///
  /// In es, this message translates to:
  /// **'La lectura de este capítulo, repartida en el tiempo.'**
  String get readingChapterRhythmBody;

  /// No description provided for @readingChapterComparisonTitle.
  ///
  /// In es, this message translates to:
  /// **'Respecto al anterior'**
  String get readingChapterComparisonTitle;

  /// No description provided for @readingChapterJourneyTitle.
  ///
  /// In es, this message translates to:
  /// **'Caminos distintos'**
  String get readingChapterJourneyTitle;

  /// No description provided for @readingChapterJourneyBody.
  ///
  /// In es, this message translates to:
  /// **'Los comienzos, las pausas y los libros sin terminar también forman parte de la historia.'**
  String get readingChapterJourneyBody;

  /// No description provided for @readingChapterStarted.
  ///
  /// In es, this message translates to:
  /// **'Empezados'**
  String get readingChapterStarted;

  /// No description provided for @readingChapterOngoing.
  ///
  /// In es, this message translates to:
  /// **'Aún leyendo'**
  String get readingChapterOngoing;

  /// No description provided for @readingChapterAbandoned.
  ///
  /// In es, this message translates to:
  /// **'Sin terminar'**
  String get readingChapterAbandoned;

  /// No description provided for @readingChapterFormatsTitle.
  ///
  /// In es, this message translates to:
  /// **'Cómo llegaron las historias hasta ti'**
  String get readingChapterFormatsTitle;

  /// No description provided for @readingChapterTasteTitle.
  ///
  /// In es, this message translates to:
  /// **'Géneros y autores'**
  String get readingChapterTasteTitle;

  /// No description provided for @readingChapterGenres.
  ///
  /// In es, this message translates to:
  /// **'Géneros'**
  String get readingChapterGenres;

  /// No description provided for @readingChapterAuthors.
  ///
  /// In es, this message translates to:
  /// **'Autores'**
  String get readingChapterAuthors;

  /// No description provided for @readingChapterRatingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Los que se quedaron'**
  String get readingChapterRatingsTitle;

  /// No description provided for @readingChapterAverageRating.
  ///
  /// In es, this message translates to:
  /// **'valoración privada media'**
  String get readingChapterAverageRating;

  /// No description provided for @readingChapterArchetypeTitle.
  ///
  /// In es, this message translates to:
  /// **'Tu arquetipo lector'**
  String get readingChapterArchetypeTitle;

  /// No description provided for @readingChapterArchetypeBody.
  ///
  /// In es, this message translates to:
  /// **'Un año lector con ritmo propio.'**
  String get readingChapterArchetypeBody;

  /// No description provided for @readingChapterArchetypeKeeper.
  ///
  /// In es, this message translates to:
  /// **'El Guardián'**
  String get readingChapterArchetypeKeeper;

  /// No description provided for @readingChapterArchetypeCurator.
  ///
  /// In es, this message translates to:
  /// **'El Catador'**
  String get readingChapterArchetypeCurator;

  /// No description provided for @readingChapterArchetypeHearth.
  ///
  /// In es, this message translates to:
  /// **'El Hogar'**
  String get readingChapterArchetypeHearth;

  /// No description provided for @readingChapterArchetypeSpark.
  ///
  /// In es, this message translates to:
  /// **'La Chispa'**
  String get readingChapterArchetypeSpark;

  /// No description provided for @readingChapterArchetypeCartographer.
  ///
  /// In es, this message translates to:
  /// **'El Cartógrafo'**
  String get readingChapterArchetypeCartographer;

  /// No description provided for @readingChapterArchetypeConstellation.
  ///
  /// In es, this message translates to:
  /// **'La Constelación'**
  String get readingChapterArchetypeConstellation;

  /// No description provided for @readingChapterArchetypeComet.
  ///
  /// In es, this message translates to:
  /// **'El Cometa'**
  String get readingChapterArchetypeComet;

  /// No description provided for @readingChapterArchetypeVault.
  ///
  /// In es, this message translates to:
  /// **'El Archivo'**
  String get readingChapterArchetypeVault;

  /// No description provided for @readingChapterArchetypeScholar.
  ///
  /// In es, this message translates to:
  /// **'El Erudito'**
  String get readingChapterArchetypeScholar;

  /// No description provided for @readingChapterArchetypeOak.
  ///
  /// In es, this message translates to:
  /// **'El Roble'**
  String get readingChapterArchetypeOak;

  /// No description provided for @readingChapterArchetypeForge.
  ///
  /// In es, this message translates to:
  /// **'La Forja'**
  String get readingChapterArchetypeForge;

  /// No description provided for @readingChapterArchetypeBeacon.
  ///
  /// In es, this message translates to:
  /// **'El Faro'**
  String get readingChapterArchetypeBeacon;

  /// No description provided for @readingChapterArchetypeAtlas.
  ///
  /// In es, this message translates to:
  /// **'El Atlas'**
  String get readingChapterArchetypeAtlas;

  /// No description provided for @readingChapterArchetypeNebula.
  ///
  /// In es, this message translates to:
  /// **'La Nebulosa'**
  String get readingChapterArchetypeNebula;

  /// No description provided for @readingChapterArchetypeLeviathan.
  ///
  /// In es, this message translates to:
  /// **'El Leviatán'**
  String get readingChapterArchetypeLeviathan;

  /// No description provided for @readingChapterArchetypeKeeperBody.
  ///
  /// In es, this message translates to:
  /// **'Terminas lo que empiezas y vuelves a las estanterías en las que ya confías.'**
  String get readingChapterArchetypeKeeperBody;

  /// No description provided for @readingChapterArchetypeCuratorBody.
  ///
  /// In es, this message translates to:
  /// **'Tu gusto está claro, pero en la lista siempre queda sitio para probar otros estilos.'**
  String get readingChapterArchetypeCuratorBody;

  /// No description provided for @readingChapterArchetypeHearthBody.
  ///
  /// In es, this message translates to:
  /// **'Lees en rachas conocidas, a menudo volviendo a los mismos autores y tonos.'**
  String get readingChapterArchetypeHearthBody;

  /// No description provided for @readingChapterArchetypeSparkBody.
  ///
  /// In es, this message translates to:
  /// **'Leías poco… hasta que algo nuevo te enciende y no paras.'**
  String get readingChapterArchetypeSparkBody;

  /// No description provided for @readingChapterArchetypeCartographerBody.
  ///
  /// In es, this message translates to:
  /// **'Lees de todo con regularidad, siempre con un ojo puesto en lo siguiente distinto.'**
  String get readingChapterArchetypeCartographerBody;

  /// No description provided for @readingChapterArchetypeConstellationBody.
  ///
  /// In es, this message translates to:
  /// **'Muchos libros, meses irregulares y sagas que te enganchan.'**
  String get readingChapterArchetypeConstellationBody;

  /// No description provided for @readingChapterArchetypeCometBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando lees, lees de verdad… y casi siempre es algo distinto a lo de antes.'**
  String get readingChapterArchetypeCometBody;

  /// No description provided for @readingChapterArchetypeVaultBody.
  ///
  /// In es, this message translates to:
  /// **'Libros largos, estanterías conocidas y la tentación de quedarte donde ya encajas.'**
  String get readingChapterArchetypeVaultBody;

  /// No description provided for @readingChapterArchetypeScholarBody.
  ///
  /// In es, this message translates to:
  /// **'Tu gusto está claro, pero en lecturas largas siempre queda sitio para probar otros estilos.'**
  String get readingChapterArchetypeScholarBody;

  /// No description provided for @readingChapterArchetypeOakBody.
  ///
  /// In es, this message translates to:
  /// **'Libros largos y viejos favoritos, en tramos lentos y densos a lo largo del año.'**
  String get readingChapterArchetypeOakBody;

  /// No description provided for @readingChapterArchetypeForgeBody.
  ///
  /// In es, this message translates to:
  /// **'Leías poco… hasta que un libro largo te enciende y no paras.'**
  String get readingChapterArchetypeForgeBody;

  /// No description provided for @readingChapterArchetypeBeaconBody.
  ///
  /// In es, this message translates to:
  /// **'Lees con regularidad a través de géneros, y vuelves a autores de confianza.'**
  String get readingChapterArchetypeBeaconBody;

  /// No description provided for @readingChapterArchetypeAtlasBody.
  ///
  /// In es, this message translates to:
  /// **'Lees de todo con regularidad, en libros largos, siempre con un ojo puesto en lo siguiente distinto.'**
  String get readingChapterArchetypeAtlasBody;

  /// No description provided for @readingChapterArchetypeNebulaBody.
  ///
  /// In es, this message translates to:
  /// **'Libros largos, meses irregulares y sagas que te enganchan.'**
  String get readingChapterArchetypeNebulaBody;

  /// No description provided for @readingChapterArchetypeLeviathanBody.
  ///
  /// In es, this message translates to:
  /// **'Cuando lees, lees de verdad… en lecturas densas, y casi siempre es algo distinto a lo de antes.'**
  String get readingChapterArchetypeLeviathanBody;

  /// No description provided for @readingChapterAxisAnchored.
  ///
  /// In es, this message translates to:
  /// **'arraigado'**
  String get readingChapterAxisAnchored;

  /// No description provided for @readingChapterAxisWide.
  ///
  /// In es, this message translates to:
  /// **'amplio'**
  String get readingChapterAxisWide;

  /// No description provided for @readingChapterAxisSteady.
  ///
  /// In es, this message translates to:
  /// **'constante'**
  String get readingChapterAxisSteady;

  /// No description provided for @readingChapterAxisTidal.
  ///
  /// In es, this message translates to:
  /// **'por mareas'**
  String get readingChapterAxisTidal;

  /// No description provided for @readingChapterAxisExplore.
  ///
  /// In es, this message translates to:
  /// **'explorar'**
  String get readingChapterAxisExplore;

  /// No description provided for @readingChapterAxisSwift.
  ///
  /// In es, this message translates to:
  /// **'breves'**
  String get readingChapterAxisSwift;

  /// No description provided for @readingChapterAxisTome.
  ///
  /// In es, this message translates to:
  /// **'densas'**
  String get readingChapterAxisTome;

  /// No description provided for @readingChapterAxisReturn.
  ///
  /// In es, this message translates to:
  /// **'volver'**
  String get readingChapterAxisReturn;

  /// No description provided for @readingChapterReflectionTitle.
  ///
  /// In es, this message translates to:
  /// **'Un libro que merece ser recordado'**
  String get readingChapterReflectionTitle;

  /// No description provided for @readingChapterSummaryTitle.
  ///
  /// In es, this message translates to:
  /// **'Este fue tu capítulo'**
  String get readingChapterSummaryTitle;

  /// No description provided for @readingChapterPromptFavorite.
  ///
  /// In es, this message translates to:
  /// **'Libro favorito'**
  String get readingChapterPromptFavorite;

  /// No description provided for @readingChapterPromptSurprise.
  ///
  /// In es, this message translates to:
  /// **'Mayor sorpresa'**
  String get readingChapterPromptSurprise;

  /// No description provided for @readingChapterPromptComfort.
  ///
  /// In es, this message translates to:
  /// **'Lectura refugio'**
  String get readingChapterPromptComfort;

  /// No description provided for @readingChapterPromptChallenged.
  ///
  /// In es, this message translates to:
  /// **'Libro que me desafió'**
  String get readingChapterPromptChallenged;

  /// No description provided for @readingChapterPromptBestCover.
  ///
  /// In es, this message translates to:
  /// **'Mejor portada'**
  String get readingChapterPromptBestCover;

  /// No description provided for @readingChapterPromptPassage.
  ///
  /// In es, this message translates to:
  /// **'Pasaje memorable'**
  String get readingChapterPromptPassage;

  /// No description provided for @readingChapterPromptReturn.
  ///
  /// In es, this message translates to:
  /// **'Regreso favorito'**
  String get readingChapterPromptReturn;

  /// No description provided for @readingChapterPromptUnfinished.
  ///
  /// In es, this message translates to:
  /// **'Inacabado pero inolvidable'**
  String get readingChapterPromptUnfinished;

  /// No description provided for @readingChapterHighlightsTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus destacados'**
  String get readingChapterHighlightsTitle;

  /// No description provided for @readingChapterHighlightsAnnualBody.
  ///
  /// In es, this message translates to:
  /// **'Elige exactamente tres propuestas o déjalas todas vacías. Permanecen en tu capítulo hasta que las incluyas al compartir.'**
  String get readingChapterHighlightsAnnualBody;

  /// No description provided for @readingChapterHighlightsMonthBody.
  ///
  /// In es, this message translates to:
  /// **'Elige un favorito del mes o déjalo vacío. Permanece en tu capítulo hasta que lo incluyas al compartir.'**
  String get readingChapterHighlightsMonthBody;

  /// No description provided for @readingChapterPickExactlyThree.
  ///
  /// In es, this message translates to:
  /// **'Elige exactamente tres destacados o bórralos todos.'**
  String get readingChapterPickExactlyThree;

  /// No description provided for @readingChapterPickOne.
  ///
  /// In es, this message translates to:
  /// **'Un capítulo mensual puede tener un destacado.'**
  String get readingChapterPickOne;

  /// No description provided for @readingChapterChooseBook.
  ///
  /// In es, this message translates to:
  /// **'Elige un libro de este capítulo'**
  String get readingChapterChooseBook;

  /// No description provided for @readingChapterExcerptOptional.
  ///
  /// In es, this message translates to:
  /// **'Fragmento o nota breve (opcional)'**
  String get readingChapterExcerptOptional;

  /// No description provided for @readingChapterAttributionOptional.
  ///
  /// In es, this message translates to:
  /// **'Fuente de la cita (opcional)'**
  String get readingChapterAttributionOptional;

  /// No description provided for @readingChapterSafeToReveal.
  ///
  /// In es, this message translates to:
  /// **'Sin spoilers'**
  String get readingChapterSafeToReveal;

  /// No description provided for @readingChapterSafeToRevealBody.
  ///
  /// In es, this message translates to:
  /// **'Seguro para mostrar al compartir'**
  String get readingChapterSafeToRevealBody;

  /// No description provided for @readingChapterHighlightsSaved.
  ///
  /// In es, this message translates to:
  /// **'Destacados guardados'**
  String get readingChapterHighlightsSaved;

  /// No description provided for @readingChapterReadinessBanner.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{1 detalle podría enriquecer este capítulo} other{{count} detalles podrían enriquecer este capítulo}}'**
  String readingChapterReadinessBanner(int count);

  /// No description provided for @readingChapterReadinessTitle.
  ///
  /// In es, this message translates to:
  /// **'Enriquece este capítulo'**
  String get readingChapterReadinessTitle;

  /// No description provided for @readingChapterReadinessBody.
  ///
  /// In es, this message translates to:
  /// **'Son sugerencias, nunca bloqueos. Los datos que faltan se muestran con honestidad.'**
  String get readingChapterReadinessBody;

  /// No description provided for @readingChapterReadinessUnconfirmedDate.
  ///
  /// In es, this message translates to:
  /// **'Confirma la fecha de finalización'**
  String get readingChapterReadinessUnconfirmedDate;

  /// No description provided for @readingChapterReadinessMissingPages.
  ///
  /// In es, this message translates to:
  /// **'Añade el número de páginas'**
  String get readingChapterReadinessMissingPages;

  /// No description provided for @readingChapterReadinessMissingFormat.
  ///
  /// In es, this message translates to:
  /// **'Añade el formato de lectura'**
  String get readingChapterReadinessMissingFormat;

  /// No description provided for @readingChapterReadinessMissingGenres.
  ///
  /// In es, this message translates to:
  /// **'Añade géneros'**
  String get readingChapterReadinessMissingGenres;

  /// No description provided for @readingChapterReadinessMissingCover.
  ///
  /// In es, this message translates to:
  /// **'Añade una portada'**
  String get readingChapterReadinessMissingCover;

  /// No description provided for @readingChapterReadinessGrouping.
  ///
  /// In es, this message translates to:
  /// **'Este libro se ha leído más de una vez. Comprueba si esas copias deben contar como el mismo.'**
  String get readingChapterReadinessGrouping;

  /// No description provided for @readingChapterReadinessInvalidPick.
  ///
  /// In es, this message translates to:
  /// **'Revisa un destacado que ya no coincide'**
  String get readingChapterReadinessInvalidPick;

  /// No description provided for @readingChapterPreviousCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta anterior'**
  String get readingChapterPreviousCard;

  /// No description provided for @readingChapterNextCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta siguiente'**
  String get readingChapterNextCard;

  /// No description provided for @readingChapterEmptyTitle.
  ///
  /// In es, this message translates to:
  /// **'Este capítulo aún no tiene actividad lectora'**
  String get readingChapterEmptyTitle;

  /// No description provided for @readingChapterEmptyBody.
  ///
  /// In es, this message translates to:
  /// **'Solo los periodos cerrados y terminados se convierten en historias. Los finales planificados nunca cuentan.'**
  String get readingChapterEmptyBody;

  /// No description provided for @readingChapterShareTitle.
  ///
  /// In es, this message translates to:
  /// **'Comparte este capítulo'**
  String get readingChapterShareTitle;

  /// No description provided for @readingChapterSharePrivacyBody.
  ///
  /// In es, this message translates to:
  /// **'Nada se comparte hasta que pulses Compartir. Oculta cualquier libro o tarjeta.'**
  String get readingChapterSharePrivacyBody;

  /// No description provided for @readingChapterIncludedBooks.
  ///
  /// In es, this message translates to:
  /// **'Libros incluidos'**
  String get readingChapterIncludedBooks;

  /// No description provided for @readingChapterIncludedCards.
  ///
  /// In es, this message translates to:
  /// **'Tarjetas incluidas'**
  String get readingChapterIncludedCards;

  /// No description provided for @readingChapterIncludeExcerpt.
  ///
  /// In es, this message translates to:
  /// **'Incluir mi fragmento'**
  String get readingChapterIncludeExcerpt;

  /// No description provided for @readingChapterIncludeExcerptBody.
  ///
  /// In es, this message translates to:
  /// **'Este texto lo has escrito tú. Revísalo con cuidado antes de compartirlo.'**
  String get readingChapterIncludeExcerptBody;

  /// No description provided for @readingChapterShareLocalText.
  ///
  /// In es, this message translates to:
  /// **'{period}\n{books}'**
  String readingChapterShareLocalText(String period, String books);

  /// No description provided for @readingChapterSpoilerHiddenPreview.
  ///
  /// In es, this message translates to:
  /// **'El texto con spoilers permanece oculto en las vistas previas hasta que quien lo vea decida mostrarlo.'**
  String get readingChapterSpoilerHiddenPreview;

  /// No description provided for @readingChapterWeekShort.
  ///
  /// In es, this message translates to:
  /// **'Semana {number}'**
  String readingChapterWeekShort(int number);

  /// No description provided for @readingChapterNotificationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuevos capítulos de lectura'**
  String get readingChapterNotificationsTitle;

  /// No description provided for @readingChapterNotificationsBody.
  ///
  /// In es, this message translates to:
  /// **'Avísame cuando esté listo mi último resumen lector mensual o anual.'**
  String get readingChapterNotificationsBody;

  /// No description provided for @readingChapterNotificationsSaved.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de capítulos de lectura actualizadas'**
  String get readingChapterNotificationsSaved;

  /// No description provided for @statusHistoryConfirmDate.
  ///
  /// In es, this message translates to:
  /// **'Confirmar fecha de finalización'**
  String get statusHistoryConfirmDate;

  /// No description provided for @statusHistoryDateUnconfirmed.
  ///
  /// In es, this message translates to:
  /// **'Esta fecha se ha inferido. Confírmala o corrígela antes de que cuente en las estadísticas por fecha.'**
  String get statusHistoryDateUnconfirmed;

  /// No description provided for @migrationBannerBodyP1Before.
  ///
  /// In es, this message translates to:
  /// **'Lamentándolo mucho hemos decidido dejar de mantener online Readendar, apagaremos servidores el '**
  String get migrationBannerBodyP1Before;

  /// No description provided for @migrationBannerBodyP1After.
  ///
  /// In es, this message translates to:
  /// **'.'**
  String get migrationBannerBodyP1After;

  /// No description provided for @migrationBannerBodyP2Before.
  ///
  /// In es, this message translates to:
  /// **'La aplicación '**
  String get migrationBannerBodyP2Before;

  /// No description provided for @migrationBannerBodyP2EmphasisFunction.
  ///
  /// In es, this message translates to:
  /// **'seguirá funcionando'**
  String get migrationBannerBodyP2EmphasisFunction;

  /// No description provided for @migrationBannerBodyP2MidPrivacy.
  ///
  /// In es, this message translates to:
  /// **' manteniendo todos tus datos de forma '**
  String get migrationBannerBodyP2MidPrivacy;

  /// No description provided for @migrationBannerBodyP2EmphasisPrivacy.
  ///
  /// In es, this message translates to:
  /// **'privada y offline'**
  String get migrationBannerBodyP2EmphasisPrivacy;

  /// No description provided for @migrationBannerBodyP2MidRepo.
  ///
  /// In es, this message translates to:
  /// **' en tu dispositivo, además hemos decidido liberar su código haciéndola Open Source con licencia Apache 2.0, puedes acceder al repositorio '**
  String get migrationBannerBodyP2MidRepo;

  /// No description provided for @migrationBannerBodyP2LinkLabel.
  ///
  /// In es, this message translates to:
  /// **'aquí'**
  String get migrationBannerBodyP2LinkLabel;

  /// No description provided for @migrationBannerBodyP2After.
  ///
  /// In es, this message translates to:
  /// **' y colaborar con nosotros.'**
  String get migrationBannerBodyP2After;

  /// No description provided for @migrationBannerBodyP3Before.
  ///
  /// In es, this message translates to:
  /// **'En este teléfono seguirás teniendo tu '**
  String get migrationBannerBodyP3Before;

  /// No description provided for @migrationBannerBodyP3Emphasis.
  ///
  /// In es, this message translates to:
  /// **'biblioteca, calendario, progreso y anotaciones'**
  String get migrationBannerBodyP3Emphasis;

  /// No description provided for @migrationBannerBodyP3After.
  ///
  /// In es, this message translates to:
  /// **' como hasta ahora, simplemente tendrás que descargar los datos con el botón de más abajo.'**
  String get migrationBannerBodyP3After;

  /// No description provided for @migrationBannerHide.
  ///
  /// In es, this message translates to:
  /// **'No volver a mostrar'**
  String get migrationBannerHide;

  /// No description provided for @migrationBannerImport.
  ///
  /// In es, this message translates to:
  /// **'Descargar mis datos'**
  String get migrationBannerImport;

  /// No description provided for @migrationBannerContinue.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get migrationBannerContinue;

  /// No description provided for @migrationHomeRowTitle.
  ///
  /// In es, this message translates to:
  /// **'Descarga tu biblioteca antes del cierre'**
  String get migrationHomeRowTitle;

  /// No description provided for @migrationHomeRowBody.
  ///
  /// In es, this message translates to:
  /// **'Los servidores de Readendar se apagarán el {date}. Importa tus datos a este dispositivo para seguir funcionando sin conexión.'**
  String migrationHomeRowBody(String date);

  /// No description provided for @migrationImportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Biblioteca copiada a este dispositivo'**
  String get migrationImportSuccess;

  /// No description provided for @migrationImportFailure.
  ///
  /// In es, this message translates to:
  /// **'No se pudo importar. Inténtalo de nuevo.'**
  String get migrationImportFailure;

  /// No description provided for @migrationImportPersisting.
  ///
  /// In es, this message translates to:
  /// **'Guardando tu biblioteca en el dispositivo…'**
  String get migrationImportPersisting;

  /// No description provided for @migrationImportCovers.
  ///
  /// In es, this message translates to:
  /// **'Descargando portadas…'**
  String get migrationImportCovers;

  /// No description provided for @migrationImportCoversProgress.
  ///
  /// In es, this message translates to:
  /// **'Portadas {done} de {total}'**
  String migrationImportCoversProgress(int done, int total);

  /// No description provided for @profileExportPreparing.
  ///
  /// In es, this message translates to:
  /// **'Preparando archivo…'**
  String get profileExportPreparing;

  /// No description provided for @profileExportSharing.
  ///
  /// In es, this message translates to:
  /// **'Abriendo opciones para guardar…'**
  String get profileExportSharing;

  /// No description provided for @settingsRestoreServer.
  ///
  /// In es, this message translates to:
  /// **'Restaurar desde el servidor'**
  String get settingsRestoreServer;

  /// No description provided for @settingsRestoreZip.
  ///
  /// In es, this message translates to:
  /// **'Restaurar copia local'**
  String get settingsRestoreZip;

  /// No description provided for @settingsRestoreZipHint.
  ///
  /// In es, this message translates to:
  /// **'Elige el .zip o .json que descargaste con «Descargar mis datos».'**
  String get settingsRestoreZipHint;

  /// No description provided for @settingsImportLocal.
  ///
  /// In es, this message translates to:
  /// **'Importar biblioteca a este dispositivo'**
  String get settingsImportLocal;

  /// No description provided for @settingsImportLocalHint.
  ///
  /// In es, this message translates to:
  /// **'Copia tu biblioteca a este teléfono. El servidor se apaga después; esta es la vía si ocultaste el aviso.'**
  String get settingsImportLocalHint;

  /// No description provided for @settingsRestoreZipDone.
  ///
  /// In es, this message translates to:
  /// **'Copia restaurada.'**
  String get settingsRestoreZipDone;

  /// No description provided for @settingsWipeLocal.
  ///
  /// In es, this message translates to:
  /// **'Borrar datos de este dispositivo'**
  String get settingsWipeLocal;

  /// No description provided for @settingsWipeLocalConfirm.
  ///
  /// In es, this message translates to:
  /// **'Se borrarán todos los datos de la app en este dispositivo. No hay marcha atrás.'**
  String get settingsWipeLocalConfirm;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'es':
      return AppL10nEs();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
