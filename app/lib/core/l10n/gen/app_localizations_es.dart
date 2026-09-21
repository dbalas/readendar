// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get betaBadge => 'BETA';

  @override
  String get reviewTitle => 'Reseña';

  @override
  String get reviewHint => 'Escribe una reseña…';

  @override
  String get finishWithoutReview => 'Terminar sin reseña';

  @override
  String get bookSectionExpand => 'Mostrar libros';

  @override
  String get bookSectionCollapse => 'Ocultar libros';

  @override
  String get loadMore => 'Cargar más';

  @override
  String get pushPermissionDenied =>
      'Activa los permisos de notificación para recibir avisos.';

  @override
  String get pushTokenUnavailable =>
      'No se pudo preparar el aviso de notificación.';

  @override
  String get bannerEditTitle => 'Personalizar banner';

  @override
  String get imageCropTitle => 'Recortar imagen';

  @override
  String get bannerCustomize => 'Personalizar banner';

  @override
  String get bannerSectionColors => 'Colores y fondos';

  @override
  String get bannerSectionImage => 'Imagen';

  @override
  String get bannerChoosePhoto => 'Elegir foto';

  @override
  String get bannerRemovePhoto => 'Quitar foto';

  @override
  String get bannerReset => 'Restablecer';

  @override
  String bannerPresetA11y(int index) {
    return 'Fondo $index';
  }

  @override
  String get appName => 'Readendar';

  @override
  String get tourSkip => 'Saltar';

  @override
  String get tourNext => 'Siguiente';

  @override
  String get tourGetStarted => 'Empezar';

  @override
  String get tourWelcomeTitle => 'Bienvenido a Readendar';

  @override
  String get tourWelcomeSubtitle =>
      'Tu vida lectora, perfectamente organizada.';

  @override
  String get tourCalendarTitle => 'Tu calendario de lectura';

  @override
  String get tourCalendarSubtitle =>
      'Ve cada inicio, hito y fecha límite de un vistazo.';

  @override
  String get tourPlannerTitle => 'Planifica tus lecturas';

  @override
  String get tourPlannerSubtitle =>
      'Nuestro asistente te crea un plan de lectura a tu ritmo, para cualquier libro.';

  @override
  String get tourLibraryTitle => 'Trae tu biblioteca';

  @override
  String get tourLibrarySubtitle =>
      'Importa tu biblioteca desde tus aplicaciones de lectura en segundos.';

  @override
  String get tourQuotesTitle =>
      'Guarda cada línea y cada nota que no quieres olvidar';

  @override
  String get tourQuotesSubtitle =>
      'Notas, citas, teoría y preguntas. Escríbelas, díctalas o hazles una foto, y compártelas a tu manera.';

  @override
  String get tourMoreTitle => 'Y mucho más';

  @override
  String get tourMoreSubtitle =>
      'Widgets, estadísticas, ruleta, tu capítulo lector y recordatorios. Todo está aquí.';

  @override
  String get tourMoreRoulette => 'Ruleta de lectura';

  @override
  String get tourMoreWidgets => 'Widgets';

  @override
  String get tourMoreStats => 'Estadísticas';

  @override
  String get navHome => 'Inicio';

  @override
  String get navLibrary => 'Libros';

  @override
  String get navCalendar => 'Calendario';

  @override
  String get navYou => 'Perfil';

  @override
  String get exploreCatalogMatchOfferRelease => 'Añadir evento de Lanzamiento';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String greetingMorning(String name) {
    return 'Buenos días, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Buenas tardes, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Buenas noches, $name';
  }

  @override
  String get sectionToday => 'Hoy';

  @override
  String get sectionReading => 'Leyendo';

  @override
  String get sectionEvents => 'Eventos';

  @override
  String get sectionSynopsis => 'Sinopsis';

  @override
  String get ratingLabel => 'Valoración';

  @override
  String get ratingUnrated => 'Sin valorar';

  @override
  String get ratingClear => 'Restablecer';

  @override
  String get notesEditTitle => 'Editar notas';

  @override
  String get notesHint => 'Escribe tus notas privadas…';

  @override
  String get notesPrivateHint => 'Solo tú puedes ver esto.';

  @override
  String get emptyToday => 'Día tranquilo. Sin eventos.';

  @override
  String get emptyEvents =>
      'Aún no hay eventos para este libro. Añade un hito, una fecha límite o un fin de lectura.';

  @override
  String get homeMetricPending => 'Pendientes';

  @override
  String get homeMetricWanted => 'Deseados';

  @override
  String get homeNoReading => 'Aún no estás leyendo ninguno';

  @override
  String get homeStartReading => 'Empezar a leer';

  @override
  String get homeTodayLabel => 'hoy';

  @override
  String get homeTomorrowLabel => 'mañana';

  @override
  String homeInDays(int days) {
    return 'en $days días';
  }

  @override
  String get libraryEmptyMessage =>
      'Tu biblioteca está vacía. Añade tu primer libro para empezar.';

  @override
  String get quickAddBook => 'Añadir libro';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusWanted => 'Deseado';

  @override
  String get statusReading => 'Leyendo';

  @override
  String get statusRead => 'Leído';

  @override
  String get statusAbandoned => 'Abandonado';

  @override
  String get statusLabel => 'Estado';

  @override
  String get statusHistoryTitle => 'Historial de estados';

  @override
  String get statusHistoryView => 'Ver historial de estados';

  @override
  String get statusHistoryEmpty => 'Aún no hay cambios de estado registrados.';

  @override
  String get statusHistoryDeletedAccount => 'Cuenta eliminada';

  @override
  String get statusHistoryBaseline =>
      'Estado registrado al activar el historial';

  @override
  String get statusHistoryDateUpdated => 'Fecha del estado actualizada';

  @override
  String get eventTypeStart => 'Inicio';

  @override
  String get eventTypeFinish => 'Fin';

  @override
  String get eventTypeAbandoned => 'Abandono';

  @override
  String get eventTypeChapterMilestone => 'Hito de capítulo';

  @override
  String get eventTypePageMilestone => 'Hito de página';

  @override
  String get eventTypeDeadline => 'Fecha límite';

  @override
  String get eventTypeBookReturn => 'Devolución de libro';

  @override
  String get eventTypeRelease => 'Lanzamiento';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionDelete => 'Eliminar';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionSave => 'Guardar';

  @override
  String get actionConfirm => 'Confirmar';

  @override
  String get actionMarkCompleted => '¡Completar!';

  @override
  String get actionMarkUncompleted => 'Reabrir';

  @override
  String get actionAddBook => 'Añadir libro';

  @override
  String get actionAddEvent => 'Añadir evento';

  @override
  String get actionUpdateProgress => 'Actualizar progreso';

  @override
  String get progressUpdatedToast => 'Progreso actualizado';

  @override
  String get actionNotNow => 'Ahora no';

  @override
  String get actionShare => 'Compartir';

  @override
  String bookShareMessage(String title, String url) {
    return 'Mira $title en Readendar: $url';
  }

  @override
  String get bookShareUnavailable => 'Este libro no se puede compartir ahora';

  @override
  String get actionReread => 'Relectura';

  @override
  String get actionSeeMore => 'Ver más';

  @override
  String get actionApply => 'Aplicar';

  @override
  String get actionReset => 'Restablecer';

  @override
  String get reminderAtTime => 'En el momento del evento';

  @override
  String reminderMinutesPlural(int n) {
    return '$n min';
  }

  @override
  String reminderHoursPlural(int n) {
    return '$n h';
  }

  @override
  String reminderDaysPlural(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n días',
      one: '$n día',
    );
    return '$_temp0';
  }

  @override
  String reminderWeeksPlural(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n semanas',
      one: '$n semana',
    );
    return '$_temp0';
  }

  @override
  String get sourceCamera => 'Cámara';

  @override
  String get sourceGallery => 'Galería';

  @override
  String get profileDisplayName => 'Nombre visible';

  @override
  String get settingsAppBehaviorTitle => 'Comportamiento';

  @override
  String get settingsAppBehaviorSubtitle =>
      'Automatizaciones y preferencias de la app';

  @override
  String get settingsAppBehaviorIntro =>
      'Opciones que cambian cómo se comporta Readendar al gestionar tu actividad.';

  @override
  String get settingsAutoStatusEventsTitle => 'Eventos al cambiar estado';

  @override
  String get settingsAutoStatusEventsBulletStart =>
      'Evento de **inicio** al pasar a **Leyendo**.';

  @override
  String get settingsAutoStatusEventsBulletFinish =>
      'Evento de **fin** al marcar como **Leído**.';

  @override
  String get profileAppearance => 'Apariencia';

  @override
  String get profileNotifications => 'Notificaciones';

  @override
  String get profileEditAction => 'Editar perfil';

  @override
  String get profileEditTitle => 'Editar perfil';

  @override
  String get profileTimezone => 'Zona horaria';

  @override
  String get profileChooseTimezone => 'Elegir zona horaria';

  @override
  String get profileSearchTimezone => 'Buscar zona horaria';

  @override
  String get onboardingConsentLabel =>
      'Acepto los términos de uso y confirmo que he leído la política de privacidad.';

  @override
  String get termsUpdateTitle => 'Términos actualizados';

  @override
  String get termsUpdateDescription =>
      'Revisa los términos y la política de privacidad vigentes antes de continuar.';

  @override
  String get termsUpdateAccept => 'Aceptar y continuar';

  @override
  String get legalTerms => 'Términos de uso';

  @override
  String get profileSaved => 'Cambios guardados';

  @override
  String get profileExportData => 'Descargar mis datos';

  @override
  String get profileExportHint =>
      'Copia local de tus libros, eventos, notas y portadas.';

  @override
  String get profileExportInProgress => 'Preparando tus datos…';

  @override
  String get profileExportTitle => 'Exportación de datos de Readendar';

  @override
  String get profilePrivacy => 'Política de privacidad';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionClear => 'Borrar';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get a11yCompleted => 'Completado';

  @override
  String get offlineBanner => 'Sin conexión: se muestran datos guardados';

  @override
  String get onboardingTitle => 'Configura el perfil de lectura';

  @override
  String get onboardingSubtitle => 'Nombre y zona horaria para tu biblioteca.';

  @override
  String get onboardingSave => 'Guardar y empezar';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearanceSystem => 'Sistema';

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filterStatus => 'Estado';

  @override
  String get filterDate => 'Fecha';

  @override
  String get filterEventType => 'Tipo de evento';

  @override
  String get filterCompletion => 'Finalización';

  @override
  String get filterCompletedOnly => 'Solo con finalización';

  @override
  String get filterUncompletedOnly => 'Solo pendientes';

  @override
  String get filterSearchHint => 'Buscar en esta página';

  @override
  String get filtersClear => 'Limpiar filtros';

  @override
  String get calendarEventsTitle => 'Eventos del mes';

  @override
  String get calendarWeekEventsTitle => 'Eventos de la semana';

  @override
  String get calendarMonthNoEvents => 'No hay eventos este mes';

  @override
  String get calendarWeekNoEvents => 'No hay eventos esta semana';

  @override
  String get calendarDayNoEvents => 'No hay eventos este día';

  @override
  String get calendarViewMonth => 'Mes';

  @override
  String get calendarViewWeek => 'Semana';

  @override
  String get calendarViewDay => 'Día';

  @override
  String get calendarShowMap => 'Ver calendario';

  @override
  String get calendarShowList => 'Ver lista';

  @override
  String get errorGeneric => 'Algo ha ido mal. Inténtalo de nuevo.';

  @override
  String get errorNetwork => 'Sin conexión. Revisa la red.';

  @override
  String get errorUnauthorized => 'Tu sesión ha expirado.';

  @override
  String get errorValidation => 'Revisa los datos introducidos.';

  @override
  String get errorRateLimited => 'Demasiadas peticiones. Espera un momento.';

  @override
  String errorRateLimitedSeconds(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Demasiados intentos de acceso. Inténtalo de nuevo en $n segundos.',
      one: 'Demasiados intentos de acceso. Inténtalo de nuevo en 1 segundo.',
    );
    return '$_temp0';
  }

  @override
  String errorRateLimitedMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'Demasiados intentos de acceso. Inténtalo de nuevo en $n minutos.',
      one: 'Demasiados intentos de acceso. Inténtalo de nuevo en 1 minuto.',
    );
    return '$_temp0';
  }

  @override
  String get errFieldRequired => 'Campo requerido.';

  @override
  String get errInvalidEmail => 'Introduce un correo válido.';

  @override
  String get authSignInTitle => 'Accede o regístrate';

  @override
  String get authSignInSubtitle =>
      'Escribe el correo y enviaremos un código. Si no hay cuenta, se creará al verificarlo.';

  @override
  String get authEmail => 'Correo electrónico';

  @override
  String get authEmailHint => 'hola@correo.com';

  @override
  String get authSubmitSignIn => 'Continuar';

  @override
  String authMagicLinkSent(String email) {
    return 'Hemos enviado un código a $email.';
  }

  @override
  String get authMagicLinkInstructions =>
      'Escribe el código del correo o abre el enlace desde este dispositivo.';

  @override
  String get authCodeTitle => 'Introduce el código';

  @override
  String authCodeSubtitle(String email) {
    return 'Usa el código enviado a $email.';
  }

  @override
  String get authCode => 'Código';

  @override
  String get authCodeHint => 'ABC234XY';

  @override
  String get authCodeRequired => 'Introduce el código.';

  @override
  String get authVerifyCode => 'Continuar';

  @override
  String get authChangeEmail => 'Cambiar correo';

  @override
  String get authResendCode => 'Reenviar código';

  @override
  String authResendCodeCountdown(int seconds) {
    return 'Reenviar en ${seconds}s';
  }

  @override
  String authWaitCountdown(String time) {
    return 'Espera $time';
  }

  @override
  String get authPasswordlessNote =>
      'El mismo código sirve para entrar o crear la cuenta, según el correo.';

  @override
  String get authDevCodeTitle => 'Modo dev: código devuelto por el backend.';

  @override
  String get authDevCodeAction => 'Continuar con este código';

  @override
  String get authSignInWithGoogle => 'Continuar con Google';

  @override
  String get authSignInWithApple => 'Continuar con Apple';

  @override
  String get magicLinkInvalid =>
      'El enlace de acceso no es válido o ha caducado. Solicita uno nuevo aquí.';

  @override
  String get loading => 'Cargando…';

  @override
  String get retry => 'Reintentar';

  @override
  String get copied => 'En el portapapeles.';

  @override
  String get searchTitle => 'Buscar libros';

  @override
  String get searchHint => 'Buscar por título o autor';

  @override
  String get searchEmptyHint => 'Escribe un título o autor para buscar.';

  @override
  String get searchNoResults => 'Sin resultados.';

  @override
  String get searchSearching => 'Buscando libros…';

  @override
  String get searchCreateManually => 'Añadir manualmente';

  @override
  String get searchScanIsbn => 'Escanear ISBN';

  @override
  String get scanIsbnTooltip => 'Escanear ISBN';

  @override
  String get scanIsbnTitle => 'Escanear código';

  @override
  String get scanIsbnInstruction =>
      'Apunta la cámara al código de barras del libro';

  @override
  String get scanIsbnTorch => 'Flash';

  @override
  String get scanIsbnManualEntry => 'Introducir ISBN manualmente';

  @override
  String get scanIsbnNotABook => 'Ese no es un código de barras de libro';

  @override
  String get scanIsbnManualHint => '978…';

  @override
  String get scanIsbnManualInvalid => 'Introduce un ISBN válido.';

  @override
  String get scanPermissionTitle => 'Se necesita acceso a la cámara';

  @override
  String get scanPermissionBody =>
      'Readendar necesita acceso a la cámara para escanear códigos de barras de libros. Puedes activarlo en Ajustes.';

  @override
  String get scanPermissionOpenSettings => 'Abrir ajustes';

  @override
  String get cameraPermissionBody =>
      'Readendar necesita acceso a la cámara para hacer una foto. Puedes activarlo en Ajustes.';

  @override
  String get photosPermissionTitle => 'Se necesita acceso a las fotos';

  @override
  String get photosPermissionBody =>
      'Readendar necesita acceso a tus fotos para buscar libros en una imagen. Puedes activarlo en Ajustes.';

  @override
  String get bookDetailTitle => 'Detalle';

  @override
  String get bookEditInfo => 'Editar libro';

  @override
  String get bookConfirmDelete => '¿Eliminar este libro de la biblioteca?';

  @override
  String get bookDeleteSuccess => 'Libro eliminado de tu biblioteca';

  @override
  String get rereadConfirmTitle => '¿Quieres releerlo?';

  @override
  String get rereadConfirmBody =>
      'Añadiremos una copia nueva a Pendientes con la misma información del libro. Empezarás de cero: el progreso y los eventos se quedan en el original.';

  @override
  String get bookTitleRequired => 'Añade un título.';

  @override
  String get bookAuthorsRequired => 'Añade al menos un autor.';

  @override
  String get bookPagesInvalid => 'Introduce un número de páginas válido.';

  @override
  String get bookOptionalHint => 'Opcional';

  @override
  String rereadSuccess(String title) {
    return 'Relectura: «$title»';
  }

  @override
  String get metaTitle => 'Título';

  @override
  String get metaAuthors => 'Autor';

  @override
  String get metaAuthorsHint => 'Separar nombres con comas';

  @override
  String get metaIsbn => 'ISBN';

  @override
  String get metaPublisher => 'Editorial';

  @override
  String get metaLanguage => 'Idioma';

  @override
  String bookLanguageName(String language) {
    String _temp0 = intl.Intl.selectLogic(
      language,
      {
        'es': 'Español',
        'ca': 'Catalán',
        'en': 'Inglés',
        'fr': 'Francés',
        'de': 'Alemán',
        'it': 'Italiano',
        'pt': 'Portugués',
        'nl': 'Neerlandés',
        'pl': 'Polaco',
        'tr': 'Turco',
        'sv': 'Sueco',
        'da': 'Danés',
        'nb': 'Noruego bokmål',
        'fi': 'Finés',
        'eu': 'Euskera',
        'gl': 'Gallego',
        'ru': 'Ruso',
        'uk': 'Ucraniano',
        'be': 'Bielorruso',
        'cs': 'Checo',
        'sk': 'Eslovaco',
        'hu': 'Húngaro',
        'ro': 'Rumano',
        'bg': 'Búlgaro',
        'hr': 'Croata',
        'sr': 'Serbio',
        'sl': 'Esloveno',
        'mk': 'Macedonio',
        'sq': 'Albanés',
        'et': 'Estonio',
        'lt': 'Lituano',
        'lv': 'Letón',
        'el': 'Griego',
        'la': 'Latín',
        'is': 'Islandés',
        'ga': 'Irlandés',
        'cy': 'Galés',
        'ja': 'Japonés',
        'zh': 'Chino',
        'ko': 'Coreano',
        'ar': 'Árabe',
        'he': 'Hebreo',
        'hi': 'Hindi',
        'bn': 'Bengalí',
        'ur': 'Urdu',
        'fa': 'Persa',
        'th': 'Tailandés',
        'vi': 'Vietnamita',
        'id': 'Indonesio',
        'ms': 'Malayo',
        'ta': 'Tamil',
        'tl': 'Filipino',
        'sw': 'Suajili',
        'af': 'Afrikáans',
        'eo': 'Esperanto',
        'ka': 'Georgiano',
        'hy': 'Armenio',
        'mn': 'Mongol',
        'other': '$language',
      },
    );
    return '$_temp0';
  }

  @override
  String get metaFormat => 'Formato';

  @override
  String get bookFormatPhysical => 'Físico';

  @override
  String get bookFormatEbook => 'Ebook';

  @override
  String get bookFormatAudiobook => 'Audiolibro';

  @override
  String get bookFormatOther => 'Otro';

  @override
  String get metaCategories => 'Categorías';

  @override
  String get metaEdition => 'Edición';

  @override
  String get metaBinding => 'Encuadernación';

  @override
  String bookBindingName(String binding) {
    String _temp0 = intl.Intl.selectLogic(
      binding,
      {
        'hardcover': 'Tapa dura',
        'paperback': 'Tapa blanda',
        'massMarket': 'Bolsillo',
        'tradePaperback': 'Rústica',
        'boardBook': 'Libro de cartón',
        'library': 'Encuadernación de biblioteca',
        'turtleback': 'Turtleback',
        'spiral': 'Espiral',
        'leather': 'Piel',
        'imitationLeather': 'Piel sintética',
        'flexibound': 'Flexible',
        'looseLeaf': 'Hojas sueltas',
        'unbound': 'Sin encuadernar',
        'comic': 'Cómic',
        'kindle': 'Kindle',
        'ebook': 'Ebook',
        'audiobook': 'Audiolibro',
        'unknownBinding': 'Encuadernación desconocida',
        'other': '$binding',
      },
    );
    return '$_temp0';
  }

  @override
  String get metaDimensions => 'Dimensiones';

  @override
  String get metaMsrp => 'Precio de lista';

  @override
  String get metaMsrpCurrency => 'Moneda';

  @override
  String get sectionExcerpt => 'Fragmento';

  @override
  String get metaPages => 'Páginas';

  @override
  String get metaChapters => 'Capítulos';

  @override
  String get metaPagesTotal => 'Páginas totales';

  @override
  String get metaChaptersTotal => 'Capítulos totales';

  @override
  String get metaSynopsis => 'Sinopsis';

  @override
  String get progressCurrentPageLabel => 'Página actual';

  @override
  String get progressCurrentLabel => 'Progreso actual';

  @override
  String get bookSectionDetails => 'General';

  @override
  String get bookSectionTracking => 'Seguimiento';

  @override
  String get bookSectionMore => 'Detalles';

  @override
  String get progressTitle => 'Progreso';

  @override
  String get progressNoData => 'Sin progreso registrado';

  @override
  String get progressPercentageLabel => '%';

  @override
  String get progressPercentageInvalid =>
      'Introduce un porcentaje entre 0 y 100.';

  @override
  String get progressChapterLabel => 'Capítulo';

  @override
  String progressChapterValue(int chapter) {
    return 'Cap. $chapter';
  }

  @override
  String get chapterArbitraryHint =>
      'El capítulo es independiente: no se sincroniza con páginas ni porcentaje.';

  @override
  String get chapterDoneTitle => '¡Capítulo completado!';

  @override
  String get chapterDonePagePrompt =>
      '¿Quieres actualizar tu página de progreso?';

  @override
  String get chapterDoneDontShowAgain => 'No volver a mostrar para este libro';

  @override
  String get eventCreateTitle => 'Nuevo evento';

  @override
  String get eventEditTitle => 'Editar evento';

  @override
  String get eventSectionDetails => 'General';

  @override
  String get eventSectionSchedule => 'Programación';

  @override
  String get eventTypeLabel => 'Tipo';

  @override
  String get eventBookLabel => 'Libro';

  @override
  String get eventBookPlaceholder => 'Selecciona un libro';

  @override
  String get eventBookOptionalPlaceholder => 'Selecciona un libro (opcional)';

  @override
  String get eventDescriptionLabel => 'Notas';

  @override
  String get eventTargetPageLabel => 'Página objetivo';

  @override
  String get eventTargetPageRequired => 'Añade una página objetivo.';

  @override
  String get eventTargetPageInvalid => 'Introduce una página válida.';

  @override
  String get eventTargetChapterLabel => 'Capítulo objetivo';

  @override
  String get eventTargetChapterRequired => 'Añade un capítulo objetivo.';

  @override
  String get eventTargetChapterInvalid => 'Introduce un capítulo válido.';

  @override
  String get eventAllDayLabel => 'Todo el día';

  @override
  String get eventBookRequired => 'Selecciona un libro.';

  @override
  String get eventReminderLabel => 'Recordatorio';

  @override
  String get reminderOff => 'Sin recordatorio';

  @override
  String get eventReminderOffsetLabel => 'Tiempo antes';

  @override
  String get eventMute => 'Silenciar';

  @override
  String get eventUnmute => 'Reactivar';

  @override
  String get eventConfirmDelete => '¿Eliminar este evento?';

  @override
  String get eventDeleteSuccess => 'Evento eliminado';

  @override
  String get imagePendingUpload => 'La imagen se subirá al guardar.';

  @override
  String get coverSearchOption => 'Buscar portadas en línea';

  @override
  String get coverUploadOption => 'Subir una foto';

  @override
  String get notifSettingsTitle => 'Notificaciones';

  @override
  String get notifGlobalLabel => 'Notificaciones activas';

  @override
  String get notifGlobalSubtitle =>
      'Desactiva para silenciar todos los recordatorios.';

  @override
  String get notifDefaultOffsetLabel => 'Tiempo por defecto';

  @override
  String get notifAllDayHourLabel => 'Hora para eventos de día completo';

  @override
  String notifAllDayHourValue(String hour) {
    return 'A las $hour';
  }

  @override
  String get notifPermissionHint =>
      'Te pediremos permiso de notificaciones la primera vez que crees un recordatorio.';

  @override
  String get notifBgTitle => 'Recordatorios con la app cerrada';

  @override
  String get notifBgIntro =>
      'Para que los avisos lleguen aunque cierres Readendar, concede estos permisos del sistema.';

  @override
  String get notifBgEnableNotifs => 'Activar notificaciones';

  @override
  String get notifBgExactAlarms => 'Permitir alarmas exactas';

  @override
  String get notifBgBattery => 'Optimización de batería';

  @override
  String get notifBgBatteryHint =>
      'Si tu móvil tiene ahorro de batería agresivo, excluye Readendar para que los recordatorios lleguen puntuales.';

  @override
  String get notificationChannelName => 'Recordatorios de Readendar';

  @override
  String get notificationChannelDescription =>
      'Recordatorios de eventos de lectura';

  @override
  String get notifTitleStart => 'Empezar a leer';

  @override
  String get notifTitleFinish => 'Terminar el libro';

  @override
  String get notifTitleAbandon => 'Abandonar la lectura';

  @override
  String notifTitleReachChapter(int n) {
    return 'Llegar al capítulo $n';
  }

  @override
  String notifTitleReachPage(int n) {
    return 'Llegar a la página $n';
  }

  @override
  String get notifTitleDeadline => 'Fecha límite de lectura';

  @override
  String get notifTitleReturn => 'Devolver el libro';

  @override
  String get notifTitleRelease => 'Lanzamiento de libro';

  @override
  String notifBodyDeadlineTarget(int n) {
    return 'hasta la pág. $n';
  }

  @override
  String get notifActionComplete => 'Completar';

  @override
  String get notifActionSnooze1h => 'Posponer 1 h';

  @override
  String get notifActionSnoozeTonight => 'Esta noche';

  @override
  String notifActionCompletedSnack(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n recordatorios completados',
      one: '1 recordatorio completado',
    );
    return '$_temp0';
  }

  @override
  String get shareTitle => 'Biblioteca pública';

  @override
  String get profileDebugTools => 'Herramientas de depuración';

  @override
  String get feedbackTitle => 'Enviar comentarios';

  @override
  String get feedbackProfileHint => 'Informa de un error o comparte una idea';

  @override
  String get feedbackBadge => 'Te escuchamos';

  @override
  String get feedbackIntro =>
      '¿Has encontrado un error o tienes una idea? Escribe el mensaje y Enviar abre tu correo hacia hello@readendar.com.';

  @override
  String get feedbackKindBug => 'Error';

  @override
  String get feedbackKindIdea => 'Idea';

  @override
  String get feedbackKindOther => 'Otro';

  @override
  String get feedbackMessageLabel => 'Tu mensaje';

  @override
  String get feedbackMessageHint =>
      'Cuéntanoslo con tus palabras: qué ha pasado, qué esperabas o qué echas en falta. Cuanto más detalle nos des, mejor podremos ayudarte.';

  @override
  String get feedbackMessageRequired => 'Escribe un mensaje primero.';

  @override
  String get feedbackMessageTooShort =>
      'El mensaje debe tener al menos 10 caracteres.';

  @override
  String get feedbackDiagnosticsNote =>
      'Incluiremos la versión de la app y algunos datos del dispositivo en el correo.';

  @override
  String get feedbackSubmit => 'Enviar';

  @override
  String get feedbackMailOpenFailed =>
      'No se pudo abrir el correo. Escríbenos a hello@readendar.com.';

  @override
  String get feedbackThanksTitle => '¡Gracias!';

  @override
  String get feedbackThanksBody =>
      'Si envías el correo, lo leeremos. Gracias por ayudar a mejorar Readendar.';

  @override
  String get feedbackThanksDone => 'Listo';

  @override
  String get debugTitle => 'Herramientas de depuración';

  @override
  String get debugOpenOnboardingAction => 'Ver onboarding';

  @override
  String get debugOpenOnboardingHint =>
      'Abre el carrusel de bienvenida para previsualizarlo.';

  @override
  String get debugWarning =>
      'Acciones destructivas solo para compilaciones de depuración. No se puede deshacer.';

  @override
  String get debugDeleteAllEventsAction => 'Borrar todos los eventos';

  @override
  String get debugDeleteAllEventsHint =>
      'Elimina todos los eventos de tu calendario.';

  @override
  String get debugDeleteAllBooksAction => 'Borrar todos los libros';

  @override
  String get debugDeleteAllBooksHint =>
      'Elimina todos los libros y sus eventos relacionados.';

  @override
  String get debugConfirmEventsTitle => '¿Borrar todos los eventos?';

  @override
  String get debugConfirmEventsBody =>
      'Esto elimina permanentemente todos tus eventos. No se puede deshacer.';

  @override
  String get debugConfirmBooksTitle => '¿Borrar todos los libros?';

  @override
  String get debugConfirmBooksBody =>
      'Esto elimina permanentemente todos los libros y sus eventos. No se puede deshacer.';

  @override
  String debugDeletedEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos borrados',
      one: '$count evento borrado',
    );
    return '$_temp0';
  }

  @override
  String debugDeletedBooks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libros borrados',
      one: '$count libro borrado',
    );
    return '$_temp0';
  }

  @override
  String get debugSeedLocalAction => 'Cargar datos de prueba';

  @override
  String get debugSeedLocalHint =>
      'Vacía la base de datos local y la rellena con libros, valoraciones, anotaciones, progresos y eventos de todos los tipos.';

  @override
  String get debugSeedLocalConfirmTitle => '¿Sustituir los datos locales?';

  @override
  String get debugSeedLocalConfirmBody =>
      'Se borra lo que haya en el dispositivo y se carga un conjunto de prueba. No se puede deshacer.';

  @override
  String debugSeedLocalSuccess(int books, int events) {
    return 'Datos de prueba listos: $books libros y $events eventos.';
  }

  @override
  String get debugRestoreCloudImportAction => 'Restaurar token de importación';

  @override
  String get debugRestoreCloudImportHint =>
      'Temporal. Pide un JWT de la cuenta de importación de depuración al backend local y vuelve a mostrar el aviso y la tarjeta de descargar datos.';

  @override
  String get debugRestoreCloudImportSuccess =>
      'Token restaurado. Se muestra el aviso de descarga.';

  @override
  String get debugRestoreCloudImportMissing =>
      'No se ha podido emitir el token. Reinicia el API local en modo dev.';

  @override
  String get debugNotifPreviewTitle => 'Vista previa de notificaciones';

  @override
  String get debugNotifPreviewIntro =>
      'Toca un tipo para lanzarlo ahora y míralo en la bandeja del sistema o la pantalla de bloqueo.';

  @override
  String get debugNotifPreviewFireAll => 'Enviar todas';

  @override
  String get debugNotifPreviewSent => 'Enviada a la bandeja';

  @override
  String get debugScheduledRemindersAction => 'Recordatorios programados';

  @override
  String get debugScheduledRemindersHint =>
      'Lista los recordatorios en cola para los próximos 2 días y lanza cualquiera ahora.';

  @override
  String get debugScheduledRemindersTitle => 'Recordatorios programados';

  @override
  String get debugScheduledRemindersIntro =>
      'Recordatorios en cola para los próximos 2 días. Toca uno para lanzar su notificación exacta ahora.';

  @override
  String get debugScheduledRemindersEmpty =>
      'No hay recordatorios en los próximos 2 días.';

  @override
  String get debugScheduledRemindersNoBook => 'Sin libro';

  @override
  String get celebrationTitle => '¡Lo has terminado!';

  @override
  String get celebrationRoulette => 'Ruleta de lectura';

  @override
  String get celebrationShare => 'Compartir';

  @override
  String get celebrationRatePrompt => '¿Cómo lo valorarías?';

  @override
  String celebrationShareMessage(String title) {
    return '¡Acabo de terminar de leer «$title» en Readendar 📚\nhttps://readendar.com';
  }

  @override
  String celebrationDaysMetric(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Terminado en $count días',
      one: 'Terminado en 1 día',
      zero: 'Terminado en menos de un día',
    );
    return '$_temp0';
  }

  @override
  String celebrationPagesMetric(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count páginas leídas',
      one: '1 página leída',
    );
    return '$_temp0';
  }

  @override
  String celebrationSessionsMetric(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sesiones de lectura',
      one: '1 sesión de lectura',
    );
    return '$_temp0';
  }

  @override
  String get homeActionAddBook => 'Añadir\nlibro';

  @override
  String get homeActionAddEvent => 'Añadir\nevento';

  @override
  String get homeActionRoulette => 'Ruleta\nlibros';

  @override
  String get rouletteEntry => 'Ruleta de libros';

  @override
  String get rouletteTitle => '¡Gira la ruleta!';

  @override
  String get rouletteEmptyMessage =>
      'Añade libros en Leyendo, Pendiente o Deseado y la ruleta elegirá tu próxima lectura.';

  @override
  String get rouletteEmptyFilteredMessage =>
      'Activa Leyendo, Pendiente o Deseado para incluir libros en la ruleta.';

  @override
  String get rouletteAddBooks => 'Añadir libros';

  @override
  String rouletteSingleMessage(String title) {
    return '«$title» es tu único libro en la ruleta. Añade más o activa más estanterías para girar.';
  }

  @override
  String get rouletteAddMore => 'Añadir más libros';

  @override
  String get rouletteSwipeHint => 'Desliza para girar';

  @override
  String get rouletteWinnerLabel => 'Tu próxima lectura';

  @override
  String get rouletteOpenBook => 'Abrir libro';

  @override
  String get rouletteSpinAgain => 'Girar de nuevo';

  @override
  String get profileImportData => 'Importar datos';

  @override
  String get profileImportSubtitle =>
      'Trae tu biblioteca desde otras aplicaciones';

  @override
  String get profileSectionTools => 'Datos y widgets';

  @override
  String get libraryEmptyImport => 'Importar datos';

  @override
  String get importDataTitle => 'Importar datos';

  @override
  String get importChooseSource => '¿De dónde viene tu biblioteca?';

  @override
  String get importGoodreadsSourceName => 'Goodreads';

  @override
  String get importBookmorySourceName => 'Bookmory';

  @override
  String get importStoryGraphSourceName => 'StoryGraph';

  @override
  String get importBabelioSourceName => 'Babelio';

  @override
  String get importGoodreadsSourceSubtitle => 'Selecciona el CSV exportado';

  @override
  String get importBookmorySourceSubtitle =>
      'Selecciona un archivo Excel de Bookmory';

  @override
  String get importStoryGraphSourceSubtitle => 'Selecciona un CSV';

  @override
  String get importBabelioSourceSubtitle =>
      'Exporta tu biblioteca y selecciona el CSV';

  @override
  String get bookmoryImportTitle => 'Importar de Bookmory';

  @override
  String get bookmoryImportHeadline => 'Trae tu biblioteca de Bookmory';

  @override
  String get bookmoryImportBody =>
      'Usa la exportación Excel de Bookmory para añadir tus libros, estados, valoraciones y notas privadas.';

  @override
  String get bookmoryImportStep1 =>
      'En Bookmory, abre Mi página → Exportar y elige Excel (xlsx). Activa «Incluir notas» si quieres importarlas.';

  @override
  String get bookmoryImportStep2 =>
      'Pulsa Exportar y selecciona aquí el archivo descargado.';

  @override
  String get bookmoryImportPickFile => 'Seleccionar archivo Excel';

  @override
  String get bookmoryImportInvalidFile =>
      'Esto no parece una exportación Excel válida de Bookmory.';

  @override
  String get storygraphImportTitle => 'Importar de StoryGraph';

  @override
  String get storygraphImportHeadline => 'Trae tu biblioteca de StoryGraph';

  @override
  String get storygraphImportBody =>
      'Usa la exportación CSV de StoryGraph para añadir tus libros, estados, formatos, valoraciones y reseñas.';

  @override
  String get storygraphImportStep1 =>
      'En la app de StoryGraph, abre Perfil, toca el menú de arriba a la derecha (☰) y elige Manage Account.';

  @override
  String get storygraphImportStep2 =>
      'En Manage Your Data, toca Export StoryGraph Library y Generate Export. Cuando StoryGraph te envíe un correo, descarga el CSV y selecciónalo aquí.';

  @override
  String get storygraphImportPickFile => 'Seleccionar CSV de StoryGraph';

  @override
  String get storygraphImportInvalidFile =>
      'Esto no parece una exportación CSV válida de StoryGraph.';

  @override
  String get storygraphImportOpenExport => 'Abrir exportación de StoryGraph';

  @override
  String get storygraphImportOpenError =>
      'No hemos podido abrir StoryGraph. Sigue los pasos en la app de StoryGraph.';

  @override
  String get babelioImportTitle => 'Importar de Babelio';

  @override
  String get babelioImportHeadline => 'Trae tu biblioteca de Babelio';

  @override
  String get babelioImportBody =>
      'Usa la exportación CSV de Babelio para añadir tus libros, estados y valoraciones.';

  @override
  String get babelioImportStep1 =>
      'Abre la exportación de Babelio e inicia sesión si te lo pide.';

  @override
  String get babelioImportStep2 =>
      'Completa la verificación, descarga tu biblioteca con el primer botón y selecciona aquí el CSV.';

  @override
  String get babelioImportPickFile => 'Seleccionar CSV de Babelio';

  @override
  String get babelioImportInvalidFile =>
      'Esto no parece una exportación CSV válida de Babelio.';

  @override
  String get babelioImportOpenExport => 'Abrir exportación de Babelio';

  @override
  String get babelioImportOpenError =>
      'No hemos podido abrir Babelio. Prueba a exportar desde el navegador.';

  @override
  String importSkippedAuthorNote(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se han omitido $count filas sin autor',
      one: 'Se ha omitido 1 fila sin autor',
    );
    return '$_temp0';
  }

  @override
  String get importTitle => 'Importar de Goodreads';

  @override
  String get importIntroHeadline => 'Trae tu biblioteca de Goodreads';

  @override
  String get importIntroBody =>
      'Exporta tus libros desde Goodreads y los añadimos a tu biblioteca con sus portadas.';

  @override
  String get importIntroStep1 =>
      'En un ordenador, abre Goodreads → My Books → Import and export.';

  @override
  String get importIntroStep2 =>
      'Haz clic en «Export Library» y descarga el archivo CSV.';

  @override
  String get importIntroStep3 =>
      'Envíate el archivo al móvil y selecciónalo aquí.';

  @override
  String get importPickFile => 'Seleccionar archivo CSV';

  @override
  String get importInvalidFile => 'Esto no parece un export de Goodreads.';

  @override
  String get importEmptyFile => 'No encontramos libros en el archivo.';

  @override
  String get importFileTooLarge =>
      'Ese archivo es demasiado grande (máx. 10 MB).';

  @override
  String get importBadEncoding =>
      'No pudimos leer la codificación de texto del archivo. Vuelve a exportarlo como CSV en UTF-8 e inténtalo de nuevo.';

  @override
  String get importConfirmTitle => 'Revisar importación';

  @override
  String get importDuplicateInLibrary => 'Ya la tienes';

  @override
  String importFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hemos encontrado $count libros',
      one: 'Hemos encontrado 1 libro',
    );
    return '$_temp0';
  }

  @override
  String importDuplicatesNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron $count duplicados del archivo',
      one: 'Se omitió 1 duplicado del archivo',
    );
    return '$_temp0';
  }

  @override
  String importSkippedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se omitieron $count filas sin título',
      one: 'Se omitió 1 fila sin título',
    );
    return '$_temp0';
  }

  @override
  String importUnmatchedNotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron asociar las notas de $count libros',
      one: 'No se pudieron asociar las notas de 1 libro',
    );
    return '$_temp0';
  }

  @override
  String importTruncatedNote(int max) {
    return 'Solo se importarán los primeros $max libros.';
  }

  @override
  String importStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count libros',
      one: 'Importar 1 libro',
    );
    return '$_temp0';
  }

  @override
  String get importProgressTitle => 'Importando';

  @override
  String importProgressLabel(int done, int total) {
    return '$done de $total';
  }

  @override
  String get importCancel => 'Cancelar';

  @override
  String get importCancelling => 'Cancelando…';

  @override
  String get importProgressSubtitle => 'Añadiendo tus libros…';

  @override
  String get importCompleteTitle => '¡Importación completada!';

  @override
  String get importCancelledTitle => 'Importación cancelada';

  @override
  String importCompleteSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se añadieron $count libros a tu biblioteca',
      one: 'Se añadió 1 libro a tu biblioteca',
      zero: 'No se añadió ningún libro',
    );
    return '$_temp0';
  }

  @override
  String get importStatAdded => 'Añadidos';

  @override
  String get importStatNoCover => 'Sin portada';

  @override
  String get importStatFailed => 'Con error';

  @override
  String get importMetadataNote =>
      'Revisa los libros y estados antes de importar. No se importan las fechas, sesiones ni tiempo de lectura.';

  @override
  String importRoundedRatingsNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Se redondearon $count valoraciones de StoryGraph a la media estrella más cercana porque Readendar usa medias estrellas.',
      one:
          'Se redondeó 1 valoración de StoryGraph a la media estrella más cercana porque Readendar usa medias estrellas.',
    );
    return '$_temp0';
  }

  @override
  String importRetryFailed(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Reintentar $count libros',
      one: 'Reintentar 1 libro',
    );
    return '$_temp0';
  }

  @override
  String importImproveCovers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Añadir $count portadas',
      one: 'Añadir 1 portada',
    );
    return '$_temp0';
  }

  @override
  String get importGoToLibrary => 'Ver biblioteca';

  @override
  String get importImproveTitle => 'Añadir portadas';

  @override
  String get importDone => 'Hecho';

  @override
  String get importImproveHint =>
      'Estos libros se importaron sin portada. Búscalos para añadirles una.';

  @override
  String get importAllCoversDone => '¡Todas las portadas listas!';

  @override
  String get importCoverUpdated => 'Portada actualizada';

  @override
  String get importImproveSearchTitle => 'Buscar portada';

  @override
  String get importImproveSearchHint => 'Título o autor';

  @override
  String get statusEmptyReading =>
      'Aún no estás leyendo nada.\n¡Escoge tu próximo libro!';

  @override
  String get statusEmptyPending =>
      'Tu lista de pendientes está vacía.\n¡Añade libros que quieras leer!';

  @override
  String get statusEmptyWanted =>
      'Tu lista de deseados está vacía.\n¡Añade libros que quieras conseguir!';

  @override
  String get statusEmptyRead => 'Todavía no has terminado ningún libro.';

  @override
  String get statusEmptyAbandoned =>
      'No has abandonado ningún libro.\n¡Sigue así!';

  @override
  String get statusEmptyGoToLibrary => 'Ir a la biblioteca';

  @override
  String get planButton => 'Planificar lectura';

  @override
  String get planTitle => 'Planificar';

  @override
  String get planReplanTitle => 'Replanificar';

  @override
  String get planReplanCta => 'Replanificar';

  @override
  String get planReplanFromStart => 'Cambiar opciones';

  @override
  String get planReplanNothing =>
      'No hay eventos pendientes para replanificar.';

  @override
  String get planProgressAheadTitle =>
      '¿Está actualizado tu progreso de lectura?';

  @override
  String planProgressAheadMessage(int currentPage) {
    return 'Tu progreso registrado es $currentPage. Actualízalo para que el nuevo plan empiece donde estás de verdad.';
  }

  @override
  String get planProgressAheadAction => 'Actualizar progreso';

  @override
  String get planModePace => 'Meta diaria';

  @override
  String get planModeDeadline => 'Terminar en una fecha';

  @override
  String get planUnitPages => 'Páginas';

  @override
  String get planUnitChapters => 'Capítulos';

  @override
  String get planStart => 'Inicio';

  @override
  String get planDeadline => 'Fecha fin';

  @override
  String get planPace => 'Ritmo';

  @override
  String get planPerDayPages => 'pág/día';

  @override
  String get planPerDayChapters => 'cap/día';

  @override
  String get planTotalPages => 'Total de páginas';

  @override
  String get planTotalChapters => 'Total de capítulos';

  @override
  String get planReadingDays => 'Días de lectura';

  @override
  String get planReminders => 'Recordatorios';

  @override
  String get planRemindersHelp =>
      'Usa la hora de recordatorio predeterminada de Ajustes.';

  @override
  String get planReset => 'Reiniciar';

  @override
  String get planNeedChapters =>
      'Introduce el total de capítulos para ver tu plan.';

  @override
  String get planNeedPages =>
      'Añade el número de páginas del libro para planificar.';

  @override
  String get planAdjustHint => 'Ajusta los criterios para ver tu plan.';

  @override
  String get planIssueNothingToRead =>
      'Ya has alcanzado el total: no queda nada por planificar.';

  @override
  String get planIssueInvalidPace =>
      'Introduce un ritmo de al menos 1 por día.';

  @override
  String get planIssueInvalidRange =>
      'La fecha límite debe ser igual o posterior a la de inicio.';

  @override
  String get planIssueNoReadingDays =>
      'Has excluido todos los días de lectura.';

  @override
  String get planStartInPast => 'La fecha de inicio es anterior a hoy.';

  @override
  String get planPaceAggressive => 'Es un ritmo exigente.';

  @override
  String get planWeekdayToggleHint => 'Toca para incluir o excluir este día.';

  @override
  String get planCalendarTapHint => 'Toca un día para excluirlo o restaurarlo.';

  @override
  String planDerivedFinish(String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days días de lectura',
      one: '1 día de lectura',
    );
    return 'Terminas ≈ $date · $_temp0';
  }

  @override
  String planDerivedPace(int pace, String unit) {
    return 'Ritmo necesario: ≈ $pace $unit';
  }

  @override
  String planTooMany(int count) {
    return 'Demasiados eventos ($count). Aumenta el ritmo o acorta el rango.';
  }

  @override
  String planManyWarning(int count) {
    return 'Plan extenso. $count eventos.';
  }

  @override
  String planEventsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count eventos',
      one: '1 evento',
    );
    return '$_temp0';
  }

  @override
  String planRange(String start, String end) {
    return '$start - $end';
  }

  @override
  String planMilestonePage(int n) {
    return 'Página $n';
  }

  @override
  String planMilestoneChapter(int n) {
    return 'Capítulo $n';
  }

  @override
  String get planEventStart => 'Empezar la lectura';

  @override
  String get planEventFinish => 'Terminar el libro';

  @override
  String get planEventDeadline => 'Fecha fin de lectura';

  @override
  String get planCreate => 'Crear';

  @override
  String get planUpdate => 'Actualizar';

  @override
  String get planUpdateConfirmTitle => 'Actualizar plan';

  @override
  String planUpdateConfirmMessage(int count, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se actualizarán $count eventos',
      one: 'Se actualizará 1 evento',
    );
    return '$_temp0 entre el $start y el $end.';
  }

  @override
  String get planUpdateProgressTitle => 'Actualizando el plan';

  @override
  String get planUpdateCompleteTitle => '¡Plan actualizado!';

  @override
  String get planUpdateFailed => 'No se pudo actualizar el plan.';

  @override
  String get planConfirmTitle => 'Crear plan';

  @override
  String planConfirmMessage(int count, String start, String end) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se crearán $count eventos',
      one: 'Se creará 1 evento',
    );
    return '$_temp0 entre el $start y el $end.';
  }

  @override
  String planConfirmOverlap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Este libro ya tiene $count eventos en este periodo.',
      one: 'Este libro ya tiene 1 evento en este periodo.',
    );
    return '$_temp0';
  }

  @override
  String get planConfirmMarkReading => 'Marcar como leyendo';

  @override
  String get planProgressTitle => 'Creando el plan';

  @override
  String get planRollingBack => 'Deshaciendo…';

  @override
  String get planFailed => 'No se pudo crear el plan.';

  @override
  String get planCompleteTitle => '¡Plan creado!';

  @override
  String get planViewInCalendar => 'Ver en el calendario';

  @override
  String get planListView => 'Lista';

  @override
  String get planCalendarView => 'Calendario';

  @override
  String get planPreviewHint =>
      'Pulsa “Calcular eventos” o “Recalcular desde cero” para ver tu plan.';

  @override
  String get planAlreadyReadChapters => 'Capítulos leídos';

  @override
  String get planAlreadyReadPages => 'Páginas leídas';

  @override
  String get planSectionSchedule => 'Fechas y ritmo';

  @override
  String get planSectionBookends => 'Eventos y avisos';

  @override
  String get planIncludeStart => 'Añadir evento de inicio';

  @override
  String get planIncludeFinish => 'Añadir evento de fin';

  @override
  String get planIncludeDeadline => 'Añadir evento de fecha fin';

  @override
  String get planExclusionsBlocked => 'Estas exclusiones rompen el plan';

  @override
  String get planExclusionsTight =>
      'Los días excluidos hacen el ritmo más exigente de lo previsto.';

  @override
  String get planAdvicePending => 'Completa los campos para ver tu estimación.';

  @override
  String get planRemovedDay => 'Sin lectura';

  @override
  String get planHistoryViewLink => 'Ver planificaciones pasadas';

  @override
  String get planHistoryTitle => 'Planificaciones pasadas';

  @override
  String get planHistoryEmpty => 'Aún no hay planificaciones para este libro.';

  @override
  String get planHistorySummaryPace => 'Meta diaria';

  @override
  String get planHistorySummaryDeadline => 'Terminar en una fecha';

  @override
  String planHistoryPerDayPages(int count) {
    return '$count pág/día';
  }

  @override
  String planHistoryPerDayChapters(int count) {
    return '$count cap/día';
  }

  @override
  String get planUndo => 'Deshacer';

  @override
  String get planUndoConfirmTitle => '¿Deshacer este plan?';

  @override
  String get planUndoConfirmMessage =>
      'Se borrarán los eventos que creó este plan y que aún existen. Los que ya hayas eliminado o completado no se ven afectados.';

  @override
  String planUndone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se han borrado $count eventos del plan',
      one: 'Se ha borrado 1 evento del plan',
      zero: 'No se borró ningún evento',
    );
    return '$_temp0';
  }

  @override
  String get planUndoFailed => 'No se pudo deshacer el plan.';

  @override
  String get planConfirmReassurance =>
      'No te preocupes: podrás deshacerlo cuando quieras.';

  @override
  String get planUndoCreated => 'Deshacer este plan';

  @override
  String get myStatsTitle => 'Métricas';

  @override
  String get myStatsSummary => 'Resumen';

  @override
  String myStatsReadingSince(String date) {
    return 'Leyendo desde $date';
  }

  @override
  String get myStatsBooksRead => 'Leídos';

  @override
  String get myStatsBooksReading => 'Leyendo';

  @override
  String get myStatsBooksQueued => 'Por leer';

  @override
  String get myStatsBooksWanted => 'Deseados';

  @override
  String get myStatsBooksAbandoned => 'Abandonados';

  @override
  String get myStatsActivity => 'Actividad';

  @override
  String get myStatsTaste => 'Gustos';

  @override
  String get myStatsFinished30 => 'Acabados (30d)';

  @override
  String get myStatsFinishedYear => 'Leídos';

  @override
  String get myStatsAdded30 => 'Añadidos (30d)';

  @override
  String get myStatsCurrentStreak => 'Racha actual';

  @override
  String get myStatsLongestStreak => 'Mejor racha';

  @override
  String get myStatsBestMonth => 'Mejor mes';

  @override
  String get myStatsFinishedChart => 'Libros acabados por mes';

  @override
  String myStatsPagesPreview(int pages) {
    return '$pages págs.';
  }

  @override
  String get myStatsGranularityWeek => 'Semana';

  @override
  String get myStatsGranularityMonth => 'Mes';

  @override
  String get myStatsGranularityYear => 'Año';

  @override
  String get myStatsGranularityAll => 'Todo';

  @override
  String get myStatsPreviousPeriod => 'Periodo anterior';

  @override
  String get myStatsNextPeriod => 'Periodo siguiente';

  @override
  String get myStatsPagesInRange => 'Páginas';

  @override
  String get myStatsPageActivityUnavailable =>
      'La actividad de páginas no está disponible con esta versión del servidor.';

  @override
  String get myStatsPageChart => 'Páginas leídas';

  @override
  String get myStatsUnitPagesPerDay => 'págs./día';

  @override
  String get myStatsUnitPagesPerMonth => 'págs./mes';

  @override
  String get myStatsUnitPagesPerYear => 'págs./año';

  @override
  String get myStatsReadingDays => 'Días de lectura';

  @override
  String get myStatsNoTaste => 'Aún no hay suficiente historial de lectura.';

  @override
  String get myStatsAvgRating => 'Valoración media';

  @override
  String get myStatsTopGenres => 'Tus géneros';

  @override
  String get myStatsUnitMonths => 'meses';

  @override
  String get widgetAddToHome => 'Añadir a la pantalla de inicio';

  @override
  String get widgetHowToTitle => 'Añade el widget de Readendar';

  @override
  String get widgetHowToIos =>
      'Mantén pulsada la pantalla de inicio, toca el + de la esquina, busca «Readendar», elige un tamaño y añádelo.';

  @override
  String get widgetHowToAndroid =>
      'Mantén pulsada la pantalla de inicio, toca Widgets, busca Readendar y arrastra un tamaño a la pantalla.';

  @override
  String get widgetPreviewEmptyEvents => 'No hay eventos próximos';

  @override
  String get widgetSeeMore => 'Ver más en el calendario';

  @override
  String get widgetPreviewError => 'No se pudo actualizar';

  @override
  String get widgetPinnedToast => 'Widget añadido a la pantalla de inicio';

  @override
  String get widgetsTitle => 'Widgets';

  @override
  String get widgetsRowSubtitle =>
      'Lecturas, eventos y citas en tu pantalla de inicio';

  @override
  String get widgetsIntro =>
      'Añade widgets a tu pantalla de inicio para tener Readendar siempre a mano.';

  @override
  String get widgetEventsTitle => 'Próximos eventos';

  @override
  String get quotesTitle => 'Citas';

  @override
  String get quotesSearchHint => 'Buscar en tus citas…';

  @override
  String get quoteAdd => 'Añadir cita';

  @override
  String quotePageAbbrev(int n) {
    return 'p. $n';
  }

  @override
  String quoteChapterAbbrev(int n) {
    return 'cap. $n';
  }

  @override
  String get quoteComposerPageLabel => 'Página';

  @override
  String get quoteComposerChapterLabel => 'Capítulo';

  @override
  String get quoteComposerNoteLabel => 'Nota privada';

  @override
  String get quoteComposerNoteHint => 'Añade una nota personal…';

  @override
  String get quoteShareIncludeNote => 'Incluir mi nota';

  @override
  String get quoteShareIncludeNoteHint =>
      'Tu nota privada aparecerá en lo que compartas.';

  @override
  String get quotesWidgetShowNote => 'Mostrar nota';

  @override
  String get quotesWidgetShowNoteHint =>
      'Muestra tu nota privada en el widget cuando la cita tenga una.';

  @override
  String get quoteBookPickerTitle => '¿De qué libro es la cita?';

  @override
  String get quoteBookPickerFilterHint => 'Buscar en tu biblioteca…';

  @override
  String get quoteBookPickerCreate => 'Crear libro';

  @override
  String get homeActionAddQuote => 'Anotación';

  @override
  String get quotesCardTitle => 'Citas';

  @override
  String get annotationsTitle => 'Anotaciones';

  @override
  String get annotationsCardTitle => 'Anotaciones';

  @override
  String get annotationsEmptyMessage =>
      'Aún no se ha añadido ninguna anotación.';

  @override
  String get annotationsSearchHint => 'Buscar en tus anotaciones…';

  @override
  String get annotationCategoryNote => 'Notas';

  @override
  String get annotationCategoryTheory => 'Teoría';

  @override
  String get annotationCategoryQuestion => 'Preguntas';

  @override
  String get annotationCategoryQuote => 'Citas';

  @override
  String get annotationPin => 'Fijar';

  @override
  String get annotationUnpin => 'Quitar fijado';

  @override
  String get annotationPinLimit =>
      'Puedes fijar hasta 3 anotaciones por libro.';

  @override
  String get annotationSpoiler => 'Contiene spoilers';

  @override
  String get annotationFavorite => 'Favorita';

  @override
  String get annotationUnfavorite => 'Quitar de favoritas';

  @override
  String get annotationAdd => 'Añadir anotación';

  @override
  String get annotationAddNote => 'Añadir nota';

  @override
  String get annotationAddQuote => 'Añadir cita';

  @override
  String get annotationAddTheory => 'Añadir teoría';

  @override
  String get annotationAddQuestion => 'Añadir pregunta';

  @override
  String get annotationFilterCategories => 'Categorías';

  @override
  String get annotationFilterFavorites => 'Favoritas';

  @override
  String get annotationsFilterEmpty =>
      'Ninguna anotación coincide con estos filtros.';

  @override
  String get annotationConfigTitle => 'Configuración';

  @override
  String get annotationDeleteConfirmTitle => '¿Eliminar esta anotación?';

  @override
  String get annotationDeleteConfirmMessage =>
      'La anotación se eliminará definitivamente.';

  @override
  String get annotationCreated => 'Anotación guardada';

  @override
  String get annotationComposerTitleNew => 'Nueva anotación';

  @override
  String get annotationComposerTitleEdit => 'Editar';

  @override
  String get annotationComposerTextHint => 'Escribe la anotación…';

  @override
  String get annotationActionsTooltip => 'Acciones de la anotación';

  @override
  String quotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas',
      one: '1 cita',
    );
    return '$_temp0';
  }

  @override
  String get quoteQuickActionTitle => 'Nueva anotación';

  @override
  String get quoteOcrTooltip => 'Escanear con la cámara';

  @override
  String get quoteOcrTitle => 'Selecciona las líneas';

  @override
  String get quoteOcrInstructions =>
      'Toca las líneas que forman la cita (mantén pulsado y arrastra para varias).';

  @override
  String get quoteOcrUseText => 'Usar texto';

  @override
  String get quoteOcrNoText => 'No se reconoció texto en la foto.';

  @override
  String get quoteOcrSelectAll => 'Seleccionar todo';

  @override
  String get quoteOcrClearSelection => 'Limpiar selección';

  @override
  String get quoteVoiceTooltip => 'Dictar por voz';

  @override
  String get quoteVoiceStopTooltip => 'Detener dictado';

  @override
  String get quoteVoiceListening => 'Escuchando…';

  @override
  String get quoteVoiceUnavailable =>
      'El dictado por voz no está disponible en este dispositivo.';

  @override
  String get quoteVoiceLocaleFallback =>
      'Tu idioma no está disponible para dictado; se usará el idioma del sistema.';

  @override
  String get quoteVoicePermissionTitle => 'Se necesita acceso al micrófono';

  @override
  String get quoteVoicePermissionBody =>
      'Readendar necesita acceso al micrófono para dictar citas. Puedes activarlo en Ajustes.';

  @override
  String get quoteShareTitle => 'Compartir cita';

  @override
  String get quoteShareTitleNote => 'Compartir nota';

  @override
  String get quoteShareTitleTheory => 'Compartir teoría';

  @override
  String get quoteShareTitleQuestion => 'Compartir pregunta';

  @override
  String get quoteShareImage => 'Imagen';

  @override
  String get quoteShareText => 'Texto';

  @override
  String get quotesWidgetPreviewEmpty => 'Añade tu primera cita';

  @override
  String get quotesWidgetConfigTitle => 'Widget de citas';

  @override
  String get quotesWidgetConfigMode => 'Qué mostrar';

  @override
  String get quotesWidgetConfigStyle => 'Aspecto';

  @override
  String get quotesWidgetModeAll => 'Todas las citas';

  @override
  String get quotesWidgetModeFavorites => 'Favoritas';

  @override
  String get quotesWidgetModeBook => 'Un libro';

  @override
  String get quotesWidgetModeFixed => 'Una cita fija';

  @override
  String get quotesWidgetConfigCadence => 'Intervalo de rotación';

  @override
  String get quotesWidgetCadenceHourly => 'Cada hora';

  @override
  String get quotesWidgetCadence6h => 'Cada 6 horas';

  @override
  String get quotesWidgetCadenceDaily => 'Cada día';

  @override
  String get quotesWidgetPickBook => 'Elegir el libro';

  @override
  String get quotesWidgetPickQuote => 'Elegir la cita';

  @override
  String get quotesWidgetConfigAdd => 'Añadir widget';

  @override
  String get quotesWidgetConfigNeedQuotes =>
      'Añade una cita primero para configurar el widget.';

  @override
  String get quotesWidgetConfigEditTitle => 'Editar widget';

  @override
  String get quotesWidgetUpdatedToast => 'Widget actualizado';

  @override
  String get kindleImportTitle => 'Importar de Kindle';

  @override
  String get kindleImportIntro =>
      'Importa tus subrayados de Kindle: conecta el Kindle al ordenador o usa la app, y elige el archivo «My Clippings.txt».';

  @override
  String get kindleImportPick => 'Elegir archivo';

  @override
  String get kindleImportInvalidFile => 'No se pudo leer el archivo.';

  @override
  String get kindleImportNoHighlights =>
      'No se encontraron subrayados en el archivo.';

  @override
  String kindleImportGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libros con subrayados',
      one: '1 libro con subrayados',
    );
    return '$_temp0';
  }

  @override
  String kindleImportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notas/marcadores omitidos',
      one: '1 nota/marcador omitido',
    );
    return '$_temp0';
  }

  @override
  String kindleImportDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count duplicados',
      one: '1 duplicado',
    );
    return '$_temp0';
  }

  @override
  String get kindleImportUnmatched =>
      'Sin libro en tu biblioteca. Toca para elegirlo';

  @override
  String get kindleImportSuggested => 'Sugerido';

  @override
  String kindleImportStart(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importar $count citas',
      one: 'Importar 1 cita',
      zero: 'Importar',
    );
    return '$_temp0';
  }

  @override
  String get kindleImportProgress => 'Importando citas…';

  @override
  String kindleImportDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '¡$count citas importadas!',
      one: '¡1 cita importada!',
    );
    return '$_temp0';
  }

  @override
  String kindleImportFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count citas fallaron',
      one: '1 cita falló',
    );
    return '$_temp0';
  }

  @override
  String get kindleImportContinue => 'Continuar';

  @override
  String get kindleImportReviewTitle => 'Revisa las citas';

  @override
  String get kindleImportReviewSubtitle =>
      'Desmarca las que no quieras importar.';

  @override
  String get kindleImportSelectAll => 'Seleccionar todas';

  @override
  String get kindleImportGoToQuotes => 'Ir a mis anotaciones';

  @override
  String get kindleImportRetry => 'Volver a intentar';

  @override
  String get kindleImportErrorTitle => 'No se pudieron importar las citas.';

  @override
  String get quoteDailyNotifTitle => 'Tu cita del día 📖';

  @override
  String get quoteDailySettingTitle => 'Cita del día';

  @override
  String get quoteDailySettingSubtitle =>
      'Una notificación diaria con una cita de tus libros.';

  @override
  String get quoteDailyHourLabel => 'Hora de la cita del día';

  @override
  String get timeJustNow => 'hace un momento';

  @override
  String timeMinutesAgo(int minutes) {
    return 'hace $minutes min';
  }

  @override
  String timeHoursAgo(int hours) {
    return 'hace $hours h';
  }

  @override
  String timeDaysAgo(int days) {
    return 'hace $days d';
  }

  @override
  String get storeReviewTitle => '¿Te está gustando Readendar?';

  @override
  String get storeReviewBody =>
      'Una reseña breve ayuda a otros lectores a encontrarnos.';

  @override
  String get storeReviewCtaAppStore => 'Valorar en App Store';

  @override
  String get storeReviewCtaPlayStore => 'Valorar en Google Play';

  @override
  String get storeReviewNotNow => 'Ahora no';

  @override
  String get storeReviewSettingsRow => '¿Nos echas una mano?';

  @override
  String get storeReviewSettingsHint =>
      'Si te gusta, una reseñita en la tienda ayuda mucho.';

  @override
  String get storeReviewOpenFailed =>
      'No se pudo abrir la tienda. Inténtalo de nuevo.';

  @override
  String get productFeedbackTitle => '¿Cómo va Readendar?';

  @override
  String get productFeedbackBody =>
      'Si algo falla, no encaja o echas de menos una pieza en cualquier parte de la app, cuéntanoslo. Lo leemos todo.';

  @override
  String get productFeedbackCta => 'Enviar feedback';

  @override
  String get productFeedbackNotNow => 'Ahora no';

  @override
  String get appUpdateTitle => 'Actualización disponible';

  @override
  String get appUpdateBody =>
      'Hay una versión nueva de Readendar en la tienda.';

  @override
  String get appUpdateCta => 'Actualizar';

  @override
  String get appUpdateLater => 'Más tarde';

  @override
  String get debugStoreReviewHint =>
      'Muestra el modal de valoración de la tienda sin guardar preferencias (solo vista previa).';

  @override
  String get debugStoreReviewAction => 'Previsualizar modal de valoración';

  @override
  String get debugProductFeedbackHint =>
      'Muestra el modal de feedback sin guardar preferencias (solo vista previa).';

  @override
  String get debugProductFeedbackAction => 'Previsualizar modal de feedback';

  @override
  String get debugAppUpdateHint =>
      'Muestra el aviso de actualización sin posponer ni consultar la tienda (solo vista previa).';

  @override
  String get debugAppUpdateAction =>
      'Previsualizar actualización con novedades';

  @override
  String get debugAppUpdateGenericAction =>
      'Previsualizar actualización genérica';

  @override
  String get debugAppUpdateSampleNotes =>
      'Novedades de esta versión\n\n• Widgets de inicio\n• Listas de biblioteca más rápidas';

  @override
  String get debugArchetypePreviewHint =>
      'Muestra las 15 tarjetas de arquetipo del capítulo lector con el diseño real.';

  @override
  String get debugArchetypePreviewAction => 'Ver arquetipos lectores';

  @override
  String get debugArchetypePreviewTitle => 'Arquetipos lectores';

  @override
  String get debugArchetypePreviewIntro =>
      'Las 15 combinaciones de gusto, ritmo, novedad y escala, con el mismo cromo invertido que el capítulo anual.';

  @override
  String get shortcutLogProgressTitle => 'Registrar progreso';

  @override
  String get shortcutWhatsNextTitle => 'Qué toca leer';

  @override
  String get bookCreateActions => 'Añadir';

  @override
  String get planWizardBack => 'Atrás';

  @override
  String get planWizardContinue => 'Continuar';

  @override
  String planWizardStepOf(int step, int total) {
    return 'Paso $step de $total';
  }

  @override
  String get planWizardGoalTitle => '¿Cómo quieres planificar?';

  @override
  String get planModePaceSubtitle =>
      'Elige cuánto leer cada día. Calculamos cuándo terminas';

  @override
  String get planModeDeadlineSubtitle =>
      'Elige una fecha de fin. Calculamos cuánto leer al día';

  @override
  String get planModeBeforeEvent => 'Antes de un evento';

  @override
  String get planModeBeforeEventSubtitle =>
      'Elige algo de tu calendario. Planificamos terminar ese día';

  @override
  String get planHistorySummaryBeforeEvent => 'Antes de un evento';

  @override
  String get planUntilHere => 'Planificar hasta aquí';

  @override
  String get planUntilHerePastHint => 'Elige un evento de hoy o futuro.';

  @override
  String get planPickEventTitle => 'Elige un evento';

  @override
  String get planPickEventHint =>
      'Toca un evento y luego Planificar hasta aquí. Los días vacíos no se pueden elegir.';

  @override
  String get planPickEventEmptyDay =>
      'No hay eventos este día. Elige un día que tenga alguno.';

  @override
  String get planPickEventEmptyMonth =>
      'No hay eventos este mes. Prueba otro mes.';

  @override
  String get planPickEventCta => 'Elegir del calendario';

  @override
  String get planAnchorEvent => 'Terminar para el evento';

  @override
  String get planCalcNeedsEvent => 'Elige un evento del calendario como meta.';

  @override
  String get planSectionBook => 'Libro';

  @override
  String get planCalcNeedsFields =>
      'Completa los campos obligatorios para calcular.';

  @override
  String get planPickDate => 'Elige una fecha';

  @override
  String get bookCoverEnlarge => 'Ver portada';

  @override
  String get bookCategoryAdventure => 'Aventuras';

  @override
  String get bookCategoryArtsEntertainment => 'Arte y entretenimiento';

  @override
  String get bookCategoryBiographyMemoir => 'Biografía y memorias';

  @override
  String get bookCategoryBusinessEconomics => 'Negocios y economía';

  @override
  String get bookCategoryChildrenYoungAdult => 'Infantil y juvenil';

  @override
  String get bookCategoryComicsManga => 'Cómics y manga';

  @override
  String get bookCategoryEducationReference => 'Educación y referencia';

  @override
  String get bookCategoryFantasy => 'Fantasía';

  @override
  String get bookCategoryFiction => 'Ficción';

  @override
  String get bookCategoryHealthWellness => 'Salud y bienestar';

  @override
  String get bookCategoryHistoricalFiction => 'Ficción histórica';

  @override
  String get bookCategoryHistory => 'Historia';

  @override
  String get bookCategoryHorrorParanormal => 'Terror y paranormal';

  @override
  String get bookCategoryHumorSatire => 'Humor y sátira';

  @override
  String get bookCategoryLifestyleLeisure => 'Estilo de vida y ocio';

  @override
  String get bookCategoryLiteraryClassics => 'Ficción literaria y clásicos';

  @override
  String get bookCategoryMysteryCrime => 'Misterio y crimen';

  @override
  String get bookCategoryNonfiction => 'No ficción';

  @override
  String get bookCategoryOther => 'Otros';

  @override
  String get bookCategoryPhilosophy => 'Filosofía';

  @override
  String get bookCategoryPoetryDrama => 'Poesía y teatro';

  @override
  String get bookCategoryPoliticsSociety => 'Política y sociedad';

  @override
  String get bookCategoryPsychology => 'Psicología';

  @override
  String get bookCategoryReligionSpirituality => 'Religión y espiritualidad';

  @override
  String get bookCategoryRomance => 'Romance';

  @override
  String get bookCategoryScienceFiction => 'Ciencia ficción';

  @override
  String get bookCategoryScienceNature => 'Ciencia y naturaleza';

  @override
  String get bookCategorySelfHelp => 'Autoayuda';

  @override
  String get bookCategoryTechnology => 'Tecnología';

  @override
  String get bookCategoryThriller => 'Thriller';

  @override
  String get eventReminderCannotFire =>
      'Este recordatorio no puede avisarte porque su hora ya pasó. Elige una fecha posterior o un aviso más corto.';

  @override
  String get myStatsActiveDays => 'Días activos';

  @override
  String get myStatsAllTime => 'Histórico';

  @override
  String get myStatsAverage => 'Media';

  @override
  String get myStatsBooksSeries => 'Libros';

  @override
  String get myStatsComparedPreviousYear => 'Frente al año anterior';

  @override
  String get myStatsConsistency => 'Constancia lectora';

  @override
  String get myStatsCurrentDayStreak => 'Racha diaria actual';

  @override
  String get myStatsFinishedBookPages => 'Páginas de libros terminados';

  @override
  String get myStatsFormatAudiobook => 'Audiolibro';

  @override
  String get myStatsFormatEbook => 'Ebook';

  @override
  String get myStatsFormatOther => 'Otro';

  @override
  String get myStatsFormatPhysical => 'Papel';

  @override
  String get myStatsFormats => 'Formatos';

  @override
  String get myStatsGenreAffinity => 'Afinidad por género';

  @override
  String get myStatsHighRatings => 'Valorados con 4 estrellas o más';

  @override
  String get myStatsLibraryMix => 'Composición de la biblioteca';

  @override
  String get myStatsLoggedPages => 'Páginas leídas';

  @override
  String get myStatsRatingDistribution => 'Distribución de valoraciones';

  @override
  String get myStatsRepeatAuthors => 'Autores repetidos';

  @override
  String get myStatsThisYear => 'Este año';

  @override
  String get myStatsUnitDays => 'días';

  @override
  String get myStatsYearEvolution => 'Evolución anual';

  @override
  String get quoteVoiceTryAgain =>
      'No se pudo iniciar el dictado por voz. Inténtalo de nuevo.';

  @override
  String annotationBodyTooLong(int maxLength) {
    return 'Esta anotación debe tener como máximo $maxLength caracteres.';
  }

  @override
  String get metaPublicationDate => 'Fecha de publicación';

  @override
  String get customFieldsTitle => 'Campos personalizados';

  @override
  String get customFieldsEmpty => 'Todavía no hay campos personalizados';

  @override
  String get customFieldsAdd => 'Añadir campo';

  @override
  String get customFieldsEdit => 'Editar campo';

  @override
  String get customFieldsName => 'Nombre del campo';

  @override
  String get customFieldsType => 'Tipo de campo';

  @override
  String get customFieldsDeleteTitle => '¿Eliminar el campo personalizado?';

  @override
  String get customFieldsDeleteMessage =>
      'Los libros que usan este campo conservarán sus valores hasta que confirmes la eliminación permanente.';

  @override
  String get customFieldsDeleteValuesTitle =>
      '¿Eliminar el campo y sus valores?';

  @override
  String get customFieldsDeleteValuesMessage =>
      'Esto elimina permanentemente este campo y sus valores de todos los libros.';

  @override
  String get customFieldsManage => 'Gestionar campos';

  @override
  String get customFieldsOption => 'Opción';

  @override
  String get customFieldsAddOption => 'Añadir opción';

  @override
  String get customFieldsYes => 'Sí';

  @override
  String get customFieldsNo => 'No';

  @override
  String get customFieldsIcon => 'Icono';

  @override
  String get customFieldsDeleteOptionTitle => '¿Eliminar la opción?';

  @override
  String get customFieldsDeleteOptionMessage =>
      'Los libros que usan esta opción perderán el valor del campo personalizado.';

  @override
  String get customFieldsTextMode => 'Estilo de texto';

  @override
  String get customFieldsSingleLine => 'Una línea';

  @override
  String get customFieldsMultiline => 'Varias líneas';

  @override
  String get customFieldsShowTime => 'Mostrar hora';

  @override
  String get customFieldsShowTimeHint =>
      'Incluye la hora al editar y mostrar este campo. Activado por defecto.';

  @override
  String get customFieldsUnavailable =>
      'No se pudieron cargar los campos personalizados. Aun así puedes guardar los demás detalles del libro.';

  @override
  String get customFieldsSaved => 'Campo personalizado guardado.';

  @override
  String get customFieldsDeleted => 'Campo personalizado eliminado.';

  @override
  String get customFieldsTypeText => 'Texto';

  @override
  String get customFieldsTypeNumber => 'Número';

  @override
  String get customFieldsTypeDateTime => 'Fecha y hora';

  @override
  String get customFieldsTypeBoolean => 'Sí o no';

  @override
  String get customFieldsOptions => 'Opciones';

  @override
  String get customFieldsTypeSingleSelect => 'Selector simple';

  @override
  String get customFieldsStandard => 'Estándar';

  @override
  String get customFieldsShowField => 'Mostrar campo';

  @override
  String get customFieldsHideField => 'Ocultar campo';

  @override
  String get profileThemes => 'Temas';

  @override
  String get themesTitle => 'Temas';

  @override
  String get themesIntro =>
      'Elige un estilo visual completo. El brillo sigue siendo independiente.';

  @override
  String get themeOriginal => 'Original';

  @override
  String get themeJade => 'Jade';

  @override
  String get themeCelestial => 'Celestial';

  @override
  String get themeOcean => 'Océano';

  @override
  String get themeNoir => 'Noir';

  @override
  String get themeSapphire => 'Sapphire';

  @override
  String get themeVelvet => 'Velvet';

  @override
  String get themeAurora => 'Aurora';

  @override
  String get themeArcade => 'Arcade';

  @override
  String get themePop => 'Pop';

  @override
  String get themeEthereal => 'Etéreo';

  @override
  String get themeStormbound => 'Tormenta';

  @override
  String get themeEvercourt => 'Cortes';

  @override
  String get themeNeonMoon => 'Neón';

  @override
  String get themeTrail => 'Rastro';

  @override
  String get themeSerpents => 'Serpientes';

  @override
  String get themeThornCrown => 'Espina';

  @override
  String get themeIridescent => 'Prisma';

  @override
  String get themeLastLight => 'Sol';

  @override
  String get premiumThemesEntryTitle => 'Temas Premium';

  @override
  String get premiumThemesTitle => 'Temas Premium';

  @override
  String get premiumThemesHeroTitle => 'Colección de temas animados';

  @override
  String get premiumCoverAtmosphereTitle => 'Atmósfera de portada';

  @override
  String get premiumCoverAtmosphereHint =>
      'Usa localmente los colores de la portada en detalles cinematográficos y celebraciones.';

  @override
  String get premiumCoverAtmosphereSaveError =>
      'No se pudo guardar la preferencia de atmósfera de portada.';

  @override
  String get premiumThemeUnavailable =>
      'Este tema Premium no está disponible en esta instalación.';

  @override
  String get themeApplied => 'Tema aplicado.';

  @override
  String get themeSaveError => 'No se pudo guardar el tema.';

  @override
  String get themeWidgetSyncWarning =>
      'Tema aplicado, pero no se pudieron actualizar los widgets.';

  @override
  String get readingChapterTitle => 'Tu capítulo lector';

  @override
  String get readingChapterProfileSubtitle =>
      'Revive el mes y el año en que tus lecturas se convirtieron en historia.';

  @override
  String readingChapterProfileLatest(String period) {
    return 'Último: $period';
  }

  @override
  String get readingChapterNew => 'NUEVO';

  @override
  String get readingChapterHeroTitle => 'Toda vida lectora deja una forma';

  @override
  String get readingChapterHeroBody =>
      'Tus meses y años terminados, reconstruidos desde los libros que realmente tocaste.';

  @override
  String get readingChapterNewAvailable => 'Hay un capítulo nuevo listo';

  @override
  String get readingChapterAll => 'Todo';

  @override
  String get readingChapterMonths => 'Meses';

  @override
  String get readingChapterYears => 'Años';

  @override
  String get readingChapterArchiveTitle => 'Archivo de capítulos';

  @override
  String readingChapterArchiveWorks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obras',
      one: '1 obra',
    );
    return '$_temp0';
  }

  @override
  String readingChapterArchiveEmptyTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'all': 'Un mes o año terminado con lectura crea tu capítulo',
        'month': 'Un mes terminado con lectura crea tu capítulo',
        'year': 'Un año terminado con lectura crea tu capítulo',
        'other': 'Un mes o año terminado con lectura crea tu capítulo',
      },
    );
    return '$_temp0';
  }

  @override
  String get readingChapterOpeningTitle => 'Capítulo de apertura';

  @override
  String readingChapterOpeningMonth(String period) {
    return 'TU $period ENTRE LIBROS';
  }

  @override
  String readingChapterOpeningYear(String period) {
    return 'TU $period ENTRE LIBROS';
  }

  @override
  String readingChapterOpeningBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count libros dieron forma a este capítulo.',
      one: 'Un libro dio forma a este capítulo.',
    );
    return '$_temp0';
  }

  @override
  String get readingChapterTotalsTitle => 'Los números detrás de las páginas';

  @override
  String get readingChapterUniqueWorks => 'obras únicas';

  @override
  String get readingChapterOccurrences => 'lecturas terminadas';

  @override
  String get readingChapterPages => 'páginas en total';

  @override
  String readingChapterPageCoverage(int known, int total) {
    return 'Recuento de páginas en $known de $total libros';
  }

  @override
  String get readingChapterRhythmTitle => 'Lectura por periodo';

  @override
  String get readingChapterRhythmBody =>
      'La lectura de este capítulo, repartida en el tiempo.';

  @override
  String get readingChapterComparisonTitle => 'Respecto al anterior';

  @override
  String get readingChapterJourneyTitle => 'Caminos distintos';

  @override
  String get readingChapterJourneyBody =>
      'Los comienzos, las pausas y los libros sin terminar también forman parte de la historia.';

  @override
  String get readingChapterStarted => 'Empezados';

  @override
  String get readingChapterOngoing => 'Aún leyendo';

  @override
  String get readingChapterAbandoned => 'Sin terminar';

  @override
  String get readingChapterFormatsTitle =>
      'Cómo llegaron las historias hasta ti';

  @override
  String get readingChapterTasteTitle => 'Géneros y autores';

  @override
  String get readingChapterGenres => 'Géneros';

  @override
  String get readingChapterAuthors => 'Autores';

  @override
  String get readingChapterRatingsTitle => 'Los que se quedaron';

  @override
  String get readingChapterAverageRating => 'valoración privada media';

  @override
  String get readingChapterArchetypeTitle => 'Tu arquetipo lector';

  @override
  String get readingChapterArchetypeBody => 'Un año lector con ritmo propio.';

  @override
  String get readingChapterArchetypeKeeper => 'El Guardián';

  @override
  String get readingChapterArchetypeCurator => 'El Catador';

  @override
  String get readingChapterArchetypeHearth => 'El Hogar';

  @override
  String get readingChapterArchetypeSpark => 'La Chispa';

  @override
  String get readingChapterArchetypeCartographer => 'El Cartógrafo';

  @override
  String get readingChapterArchetypeConstellation => 'La Constelación';

  @override
  String get readingChapterArchetypeComet => 'El Cometa';

  @override
  String get readingChapterArchetypeVault => 'El Archivo';

  @override
  String get readingChapterArchetypeScholar => 'El Erudito';

  @override
  String get readingChapterArchetypeOak => 'El Roble';

  @override
  String get readingChapterArchetypeForge => 'La Forja';

  @override
  String get readingChapterArchetypeBeacon => 'El Faro';

  @override
  String get readingChapterArchetypeAtlas => 'El Atlas';

  @override
  String get readingChapterArchetypeNebula => 'La Nebulosa';

  @override
  String get readingChapterArchetypeLeviathan => 'El Leviatán';

  @override
  String get readingChapterArchetypeKeeperBody =>
      'Terminas lo que empiezas y vuelves a las estanterías en las que ya confías.';

  @override
  String get readingChapterArchetypeCuratorBody =>
      'Tu gusto está claro, pero en la lista siempre queda sitio para probar otros estilos.';

  @override
  String get readingChapterArchetypeHearthBody =>
      'Lees en rachas conocidas, a menudo volviendo a los mismos autores y tonos.';

  @override
  String get readingChapterArchetypeSparkBody =>
      'Leías poco… hasta que algo nuevo te enciende y no paras.';

  @override
  String get readingChapterArchetypeCartographerBody =>
      'Lees de todo con regularidad, siempre con un ojo puesto en lo siguiente distinto.';

  @override
  String get readingChapterArchetypeConstellationBody =>
      'Muchos libros, meses irregulares y sagas que te enganchan.';

  @override
  String get readingChapterArchetypeCometBody =>
      'Cuando lees, lees de verdad… y casi siempre es algo distinto a lo de antes.';

  @override
  String get readingChapterArchetypeVaultBody =>
      'Libros largos, estanterías conocidas y la tentación de quedarte donde ya encajas.';

  @override
  String get readingChapterArchetypeScholarBody =>
      'Tu gusto está claro, pero en lecturas largas siempre queda sitio para probar otros estilos.';

  @override
  String get readingChapterArchetypeOakBody =>
      'Libros largos y viejos favoritos, en tramos lentos y densos a lo largo del año.';

  @override
  String get readingChapterArchetypeForgeBody =>
      'Leías poco… hasta que un libro largo te enciende y no paras.';

  @override
  String get readingChapterArchetypeBeaconBody =>
      'Lees con regularidad a través de géneros, y vuelves a autores de confianza.';

  @override
  String get readingChapterArchetypeAtlasBody =>
      'Lees de todo con regularidad, en libros largos, siempre con un ojo puesto en lo siguiente distinto.';

  @override
  String get readingChapterArchetypeNebulaBody =>
      'Libros largos, meses irregulares y sagas que te enganchan.';

  @override
  String get readingChapterArchetypeLeviathanBody =>
      'Cuando lees, lees de verdad… en lecturas densas, y casi siempre es algo distinto a lo de antes.';

  @override
  String get readingChapterAxisAnchored => 'arraigado';

  @override
  String get readingChapterAxisWide => 'amplio';

  @override
  String get readingChapterAxisSteady => 'constante';

  @override
  String get readingChapterAxisTidal => 'por mareas';

  @override
  String get readingChapterAxisExplore => 'explorar';

  @override
  String get readingChapterAxisSwift => 'breves';

  @override
  String get readingChapterAxisTome => 'densas';

  @override
  String get readingChapterAxisReturn => 'volver';

  @override
  String get readingChapterReflectionTitle =>
      'Un libro que merece ser recordado';

  @override
  String get readingChapterSummaryTitle => 'Este fue tu capítulo';

  @override
  String get readingChapterPromptFavorite => 'Libro favorito';

  @override
  String get readingChapterPromptSurprise => 'Mayor sorpresa';

  @override
  String get readingChapterPromptComfort => 'Lectura refugio';

  @override
  String get readingChapterPromptChallenged => 'Libro que me desafió';

  @override
  String get readingChapterPromptBestCover => 'Mejor portada';

  @override
  String get readingChapterPromptPassage => 'Pasaje memorable';

  @override
  String get readingChapterPromptReturn => 'Regreso favorito';

  @override
  String get readingChapterPromptUnfinished => 'Inacabado pero inolvidable';

  @override
  String get readingChapterHighlightsTitle => 'Tus destacados';

  @override
  String get readingChapterHighlightsAnnualBody =>
      'Elige exactamente tres propuestas o déjalas todas vacías. Permanecen en tu capítulo hasta que las incluyas al compartir.';

  @override
  String get readingChapterHighlightsMonthBody =>
      'Elige un favorito del mes o déjalo vacío. Permanece en tu capítulo hasta que lo incluyas al compartir.';

  @override
  String get readingChapterPickExactlyThree =>
      'Elige exactamente tres destacados o bórralos todos.';

  @override
  String get readingChapterPickOne =>
      'Un capítulo mensual puede tener un destacado.';

  @override
  String get readingChapterChooseBook => 'Elige un libro de este capítulo';

  @override
  String get readingChapterExcerptOptional =>
      'Fragmento o nota breve (opcional)';

  @override
  String get readingChapterAttributionOptional =>
      'Fuente de la cita (opcional)';

  @override
  String get readingChapterSafeToReveal => 'Sin spoilers';

  @override
  String get readingChapterSafeToRevealBody =>
      'Seguro para mostrar al compartir';

  @override
  String get readingChapterHighlightsSaved => 'Destacados guardados';

  @override
  String readingChapterReadinessBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count detalles podrían enriquecer este capítulo',
      one: '1 detalle podría enriquecer este capítulo',
    );
    return '$_temp0';
  }

  @override
  String get readingChapterReadinessTitle => 'Enriquece este capítulo';

  @override
  String get readingChapterReadinessBody =>
      'Son sugerencias, nunca bloqueos. Los datos que faltan se muestran con honestidad.';

  @override
  String get readingChapterReadinessUnconfirmedDate =>
      'Confirma la fecha de finalización';

  @override
  String get readingChapterReadinessMissingPages =>
      'Añade el número de páginas';

  @override
  String get readingChapterReadinessMissingFormat =>
      'Añade el formato de lectura';

  @override
  String get readingChapterReadinessMissingGenres => 'Añade géneros';

  @override
  String get readingChapterReadinessMissingCover => 'Añade una portada';

  @override
  String get readingChapterReadinessGrouping =>
      'Este libro se ha leído más de una vez. Comprueba si esas copias deben contar como el mismo.';

  @override
  String get readingChapterReadinessInvalidPick =>
      'Revisa un destacado que ya no coincide';

  @override
  String get readingChapterPreviousCard => 'Tarjeta anterior';

  @override
  String get readingChapterNextCard => 'Tarjeta siguiente';

  @override
  String get readingChapterEmptyTitle =>
      'Este capítulo aún no tiene actividad lectora';

  @override
  String get readingChapterEmptyBody =>
      'Solo los periodos cerrados y terminados se convierten en historias. Los finales planificados nunca cuentan.';

  @override
  String get readingChapterShareTitle => 'Comparte este capítulo';

  @override
  String get readingChapterSharePrivacyBody =>
      'Nada se comparte hasta que pulses Compartir. Oculta cualquier libro o tarjeta.';

  @override
  String get readingChapterIncludedBooks => 'Libros incluidos';

  @override
  String get readingChapterIncludedCards => 'Tarjetas incluidas';

  @override
  String get readingChapterIncludeExcerpt => 'Incluir mi fragmento';

  @override
  String get readingChapterIncludeExcerptBody =>
      'Este texto lo has escrito tú. Revísalo con cuidado antes de compartirlo.';

  @override
  String readingChapterShareLocalText(String period, String books) {
    return '$period\n$books';
  }

  @override
  String get readingChapterSpoilerHiddenPreview =>
      'El texto con spoilers permanece oculto en las vistas previas hasta que quien lo vea decida mostrarlo.';

  @override
  String readingChapterWeekShort(int number) {
    return 'Semana $number';
  }

  @override
  String get readingChapterNotificationsTitle => 'Nuevos capítulos de lectura';

  @override
  String get readingChapterNotificationsBody =>
      'Avísame cuando esté listo mi último resumen lector mensual o anual.';

  @override
  String get readingChapterNotificationsSaved =>
      'Notificaciones de capítulos de lectura actualizadas';

  @override
  String get statusHistoryConfirmDate => 'Confirmar fecha de finalización';

  @override
  String get statusHistoryDateUnconfirmed =>
      'Esta fecha se ha inferido. Confírmala o corrígela antes de que cuente en las estadísticas por fecha.';

  @override
  String get migrationBannerBodyP1Before =>
      'Lamentándolo mucho hemos decidido dejar de mantener online Readendar, apagaremos servidores el ';

  @override
  String get migrationBannerBodyP1After => '.';

  @override
  String get migrationBannerBodyP2Before => 'La aplicación ';

  @override
  String get migrationBannerBodyP2EmphasisFunction => 'seguirá funcionando';

  @override
  String get migrationBannerBodyP2MidPrivacy =>
      ' manteniendo todos tus datos de forma ';

  @override
  String get migrationBannerBodyP2EmphasisPrivacy => 'privada y offline';

  @override
  String get migrationBannerBodyP2MidRepo =>
      ' en tu dispositivo, además hemos decidido liberar su código haciéndola Open Source con licencia Apache 2.0, puedes acceder al repositorio ';

  @override
  String get migrationBannerBodyP2LinkLabel => 'aquí';

  @override
  String get migrationBannerBodyP2After => ' y colaborar con nosotros.';

  @override
  String get migrationBannerBodyP3Before =>
      'En este teléfono seguirás teniendo tu ';

  @override
  String get migrationBannerBodyP3Emphasis =>
      'biblioteca, calendario, progreso y anotaciones';

  @override
  String get migrationBannerBodyP3After =>
      ' como hasta ahora, simplemente tendrás que descargar los datos con el botón de más abajo.';

  @override
  String get migrationBannerHide => 'No volver a mostrar';

  @override
  String get migrationBannerImport => 'Descargar mis datos';

  @override
  String get migrationBannerContinue => 'Ahora no';

  @override
  String get migrationHomeRowTitle => 'Descarga tu biblioteca antes del cierre';

  @override
  String migrationHomeRowBody(String date) {
    return 'Los servidores de Readendar se apagarán el $date. Importa tus datos a este dispositivo para seguir funcionando sin conexión.';
  }

  @override
  String get migrationImportSuccess => 'Biblioteca copiada a este dispositivo';

  @override
  String get migrationImportFailure =>
      'No se pudo importar. Inténtalo de nuevo.';

  @override
  String get migrationImportPersisting =>
      'Guardando tu biblioteca en el dispositivo…';

  @override
  String get migrationImportCovers => 'Descargando portadas…';

  @override
  String migrationImportCoversProgress(int done, int total) {
    return 'Portadas $done de $total';
  }

  @override
  String get profileExportPreparing => 'Preparando archivo…';

  @override
  String get profileExportSharing => 'Abriendo opciones para guardar…';

  @override
  String get settingsRestoreServer => 'Restaurar desde el servidor';

  @override
  String get settingsRestoreZip => 'Restaurar copia local';

  @override
  String get settingsRestoreZipHint =>
      'Elige el .zip o .json que descargaste con «Descargar mis datos».';

  @override
  String get settingsImportLocal => 'Importar biblioteca a este dispositivo';

  @override
  String get settingsImportLocalHint =>
      'Copia tu biblioteca a este teléfono. El servidor se apaga después; esta es la vía si ocultaste el aviso.';

  @override
  String get settingsRestoreZipDone => 'Copia restaurada.';

  @override
  String get settingsWipeLocal => 'Borrar datos de este dispositivo';

  @override
  String get settingsWipeLocalConfirm =>
      'Se borrarán todos los datos de la app en este dispositivo. No hay marcha atrás.';
}
