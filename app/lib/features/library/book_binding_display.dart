import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/features/library/catalog_key.dart';

/// Canonical binding codes shown in the standard Binding field.
///
/// Storage stays on the English catalog terms sources and Goodreads use.
/// Display always goes through [bookBindingDisplayName] so every locale sees a
/// real translation, not the raw English wire value.
const List<String> bookBindingCodes = <String>[
  'hardcover',
  'paperback',
  'massMarket',
  'tradePaperback',
  'boardBook',
  'library',
  'turtleback',
  'spiral',
  'leather',
  'imitationLeather',
  'flexibound',
  'looseLeaf',
  'unbound',
  'comic',
  'kindle',
  'ebook',
  'audiobook',
  'unknownBinding',
];

const Map<String, String> _bindingStorage = {
  'hardcover': 'Hardcover',
  'paperback': 'Paperback',
  'massMarket': 'Mass Market Paperback',
  'tradePaperback': 'Trade Paperback',
  'boardBook': 'Board Book',
  'library': 'Library Binding',
  'turtleback': 'Turtleback',
  'spiral': 'Spiral-bound',
  'leather': 'Leather Bound',
  'imitationLeather': 'Imitation Leather',
  'flexibound': 'Flexibound',
  'looseLeaf': 'Loose Leaf',
  'unbound': 'Unbound',
  'comic': 'Comic',
  'kindle': 'Kindle Edition',
  'ebook': 'eBook',
  'audiobook': 'Audiobook',
  'unknownBinding': 'Unknown Binding',
};

/// Localized label for a catalog binding string.
///
/// Unknown values stay visible verbatim so a rare catalog term is not blanked.
String bookBindingDisplayName(AppL10n l, String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  final code = canonicalBookBindingCode(trimmed);
  return code == null ? trimmed : l.bookBindingName(code);
}

/// Maps a catalog/user binding string onto a [bookBindingCodes] id.
///
/// Accepts English catalog terms and the localized labels we ship, so a value
/// typed as "Tapa dura" still displays correctly after a locale switch.
String? canonicalBookBindingCode(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  if (bookBindingCodes.contains(trimmed)) return trimmed;
  final key = normalizeCatalogKey(trimmed);
  if (key.isEmpty) return null;
  final exact = _bindingAliases[key];
  if (exact != null) return exact;
  return _bindingCodeFromContains(key);
}

/// English catalog term persisted for a known binding, otherwise the trimmed
/// original. Empty input yields null so the field stays unset.
String? canonicalBookBindingStorage(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final code = canonicalBookBindingCode(trimmed);
  return code == null ? trimmed : _bindingStorage[code];
}

String? _bindingCodeFromContains(String key) {
  if (_containsAny(key, const [
    'mass market',
    'livre de poche',
    'bolsillo',
    'tascabile',
    'cep boy',
    'kieszonk',
    'taskukirja',
  ])) {
    return 'massMarket';
  }
  if (_containsAny(key, const [
    'trade paper',
    'grand format',
    'broszur',
    'storpocket',
  ])) {
    return 'tradePaperback';
  }
  if (_containsAny(key, const [
    'board book',
    'libro de carton',
    'llibre de cartro',
    'livre cartonne',
    'pappbilder',
    'kartonboek',
    'pahvikirja',
    'livro de cartao',
    'livro de papelao',
  ])) {
    return 'boardBook';
  }
  if (_containsAny(key, const [
    'unknown bind',
    'encuadernacion desconocida',
    'enquadernacio desconeguda',
    'reliure inconnue',
    'unbekannter einband',
    'rilegatura sconosciuta',
    'encadernacao desconhecida',
    'onbekende binding',
    'nieznana oprawa',
    'bilinmeyen cilt',
    'okant band',
    'ukendt indbinding',
    'ukjent innbinding',
    'tuntematon sidos',
  ])) {
    return 'unknownBinding';
  }
  if (_containsAny(key, const [
    'imitation leather',
    'faux leather',
    'piel sintetica',
    'pell sintetica',
    'simili cuir',
    'kunstleder',
    'finta pelle',
    'imitacao de pele',
    'couro sintetico',
    'imitatieleer',
    'imitacja skory',
    'suni deri',
    'konstlader',
    'kunstlaeder',
    'kunstskinn',
    'keinonahka',
  ])) {
    return 'imitationLeather';
  }
  if (key.contains('turtleback')) return 'turtleback';
  if (_containsAny(key, const [
    'unbound',
    'sin encuadernar',
    'sense enquadernar',
    'non relie',
    'ungebunden',
    'non rilegato',
    'sem encadernacao',
    'ongebonden',
    'bez oprawy',
    'obunden',
    'ubundet',
    'sidomaton',
  ])) {
    return 'unbound';
  }
  if (_containsAny(key, const [
    'library bind',
    'library edition',
    'encuadernacion de biblioteca',
    'enquadernacio de biblioteca',
    'reliure bibliotheque',
    'bibliothekseinband',
    'bibliotheekband',
    'encadernacao de biblioteca',
    'kirjastokansi',
  ])) {
    return 'library';
  }
  if (_containsAny(key, const ['spiral', 'espiral', 'kierreselka'])) {
    return 'spiral';
  }
  if (_containsAny(key, const [
    'leather',
    'piel',
    'cuir',
    'pelle',
    'leder',
    'nahka',
    'deri',
    'couro',
    'skinn',
    'laeder',
    'skorzana',
  ])) {
    return 'leather';
  }
  if (key.contains('kindle')) return 'kindle';
  if (_containsAny(key, const [
    'audio',
    'audible',
    'audiolibro',
    'audiollibre',
    'hoerbuch',
    'horbuch',
    'lydbog',
    'lydbok',
    'aanikirja',
    'sesli kitap',
    'audiolivro',
    'livre audio',
  ])) {
    return 'audiobook';
  }
  if (_containsAny(key, const ['ebook', 'e book', 'e-book', 'digital'])) {
    return 'ebook';
  }
  if (_containsAny(key, const [
    'hardcover',
    'hardback',
    'hard cover',
    'tapa dura',
    'copertina rigida',
    'gebunden',
    'capa dura',
    'kovakant',
    'innbundet',
    'inbunden',
    'indbundet',
    'ciltli',
  ])) {
    return 'hardcover';
  }
  if (_containsAny(key, const [
    'paperback',
    'softcover',
    'tapa blanda',
    'tapa tova',
    'copertina flessibile',
    'taschenbuch',
    'capa mole',
    'capa comum',
    'pehmeakant',
    'haftad',
    'heftet',
    'haeftet',
    'ciltsiz',
  ])) {
    return 'paperback';
  }
  if (_containsAny(key, const [
    'loose leaf',
    'hojas sueltas',
    'folhas soltas',
    'fulls solts',
  ])) {
    return 'looseLeaf';
  }
  if (_containsAny(key, const ['flexibound', 'flexcover'])) {
    return 'flexibound';
  }
  if (_containsAny(key, const [
    'comic',
    'fumetto',
    'tebeo',
    'historieta',
    'quadrinhos',
    'banda desenhada',
    'sarjakuva',
    'tegneserie',
    'cizgi roman',
  ])) {
    return 'comic';
  }
  return null;
}

bool _containsAny(String key, List<String> needles) {
  for (final needle in needles) {
    if (key.contains(needle)) return true;
  }
  return false;
}

const Map<String, String> _bindingAliases = {
  'hardcover': 'hardcover',
  'hard cover': 'hardcover',
  'hardback': 'hardcover',
  'hard back': 'hardcover',
  'hardcover edition': 'hardcover',
  'casebound': 'hardcover',
  'cloth': 'hardcover',
  'gebundene ausgabe': 'hardcover',
  'pasta dura': 'hardcover',
  'tapa dura': 'hardcover',
  'relie': 'hardcover',
  'copertina rigida': 'hardcover',
  'gebunden': 'hardcover',
  'gebonden': 'hardcover',
  'capa dura': 'hardcover',
  'twarda': 'hardcover',
  'ciltli': 'hardcover',
  'inbunden': 'hardcover',
  'indbundet': 'hardcover',
  'innbundet': 'hardcover',
  'kovakantinen': 'hardcover',
  'cartone': 'hardcover',
  'cartonato': 'boardBook',
  'broschur': 'tradePaperback',
  'loseblatt': 'looseLeaf',
  'paperback': 'paperback',
  'paper back': 'paperback',
  'softcover': 'paperback',
  'soft cover': 'paperback',
  'perfect paperback': 'paperback',
  'tapa blanda': 'paperback',
  'tapa tova': 'paperback',
  'pasta blanda': 'paperback',
  'rustica': 'tradePaperback',
  'broche': 'paperback',
  'copertina flessibile': 'paperback',
  'taschenbuch': 'paperback',
  'capa mole': 'paperback',
  'capa comum': 'paperback',
  'miekka': 'paperback',
  'ciltsiz': 'paperback',
  'haftad': 'paperback',
  'haeftet': 'paperback',
  'heftet': 'paperback',
  'pehmeakantinen': 'paperback',
  'mass market': 'massMarket',
  'mass market paperback': 'massMarket',
  'mmp': 'massMarket',
  'mmpb': 'massMarket',
  'pocket book': 'massMarket',
  'pocket': 'massMarket',
  'bolsillo': 'massMarket',
  'bols': 'massMarket',
  'bolso': 'massMarket',
  'livre de poche': 'massMarket',
  'poche': 'massMarket',
  'tascabile': 'massMarket',
  'cep boy': 'massMarket',
  'kieszonkowa': 'massMarket',
  'taskukirja': 'massMarket',
  'trade paperback': 'tradePaperback',
  'trade paper': 'tradePaperback',
  'trade pb': 'tradePaperback',
  'grand format': 'tradePaperback',
  'brossura': 'tradePaperback',
  'brochura': 'tradePaperback',
  'flexivel': 'flexibound',
  'broszurowa': 'tradePaperback',
  'storpocket': 'tradePaperback',
  'board book': 'boardBook',
  'boardbook': 'boardBook',
  'libro de carton': 'boardBook',
  'llibre de cartro': 'boardBook',
  'livre cartonne': 'boardBook',
  'pappbilderbuch': 'boardBook',
  'kartonboek': 'boardBook',
  'pahvikirja': 'boardBook',
  'livro de cartao': 'boardBook',
  'livro de papelao': 'boardBook',
  'library binding': 'library',
  'library edition': 'library',
  'school library binding': 'library',
  'hardcover library binding': 'library',
  'turtleback': 'turtleback',
  'turtleback binding': 'turtleback',
  'unknown binding': 'unknownBinding',
  'unknown': 'unknownBinding',
  'encuadernacion desconocida': 'unknownBinding',
  'enquadernacio desconeguda': 'unknownBinding',
  'reliure inconnue': 'unknownBinding',
  'unbekannter einband': 'unknownBinding',
  'rilegatura sconosciuta': 'unknownBinding',
  'encadernacao desconhecida': 'unknownBinding',
  'onbekende binding': 'unknownBinding',
  'nieznana oprawa': 'unknownBinding',
  'bilinmeyen cilt': 'unknownBinding',
  'okant band': 'unknownBinding',
  'ukendt indbinding': 'unknownBinding',
  'ukjent innbinding': 'unknownBinding',
  'tuntematon sidos': 'unknownBinding',
  'unbound': 'unbound',
  'sin encuadernar': 'unbound',
  'sense enquadernar': 'unbound',
  'non relie': 'unbound',
  'ungebunden': 'unbound',
  'non rilegato': 'unbound',
  'sem encadernacao': 'unbound',
  'ongebonden': 'unbound',
  'bez oprawy': 'unbound',
  'obunden': 'unbound',
  'ubundet': 'unbound',
  'sidomaton': 'unbound',
  'imitation leather': 'imitationLeather',
  'faux leather': 'imitationLeather',
  'bonded leather': 'imitationLeather',
  'piel sintetica': 'imitationLeather',
  'pell sintetica': 'imitationLeather',
  'simili cuir': 'imitationLeather',
  'kunstleder': 'imitationLeather',
  'finta pelle': 'imitationLeather',
  'imitacao de pele': 'imitationLeather',
  'couro sintetico': 'imitationLeather',
  'imitatieleer': 'imitationLeather',
  'imitacja skory': 'imitationLeather',
  'suni deri': 'imitationLeather',
  'ciltsiz yaprak': 'unbound',
  'konstlader': 'imitationLeather',
  'kunstlaeder': 'imitationLeather',
  'kunstskinn': 'imitationLeather',
  'keinonahka': 'imitationLeather',
  'encuadernacion de biblioteca': 'library',
  'enquadernacio de biblioteca': 'library',
  'reliure bibliotheque': 'library',
  'bibliothekseinband': 'library',
  'bibliotheekband': 'library',
  'encadernacao de biblioteca': 'library',
  'kirjastokansi': 'library',
  'spiral': 'spiral',
  'spiral bound': 'spiral',
  'spiralbound': 'spiral',
  'plastic comb': 'spiral',
  'ring bound': 'spiral',
  'espiral': 'spiral',
  'spirale': 'spiral',
  'spiralbindung': 'spiral',
  'spiraalbinding': 'spiral',
  'kierreselka': 'spiral',
  'leather': 'leather',
  'leather bound': 'leather',
  'leatherbound': 'leather',
  'piel': 'leather',
  'pell': 'leather',
  'cuir': 'leather',
  'pelle': 'leather',
  'leder': 'leather',
  'leer': 'leather',
  'pele': 'leather',
  'couro': 'leather',
  'deri': 'leather',
  'skinn': 'leather',
  'laeder': 'leather',
  'nahkakansi': 'leather',
  'skorzana': 'leather',
  'flexibound': 'flexibound',
  'flexcover': 'flexibound',
  'flexible': 'flexibound',
  'souple': 'flexibound',
  'flessibile': 'flexibound',
  'loose leaf': 'looseLeaf',
  'looseleaf': 'looseLeaf',
  'hojas sueltas': 'looseLeaf',
  'fulls solts': 'looseLeaf',
  'feuilles mobiles': 'looseLeaf',
  'folhas soltas': 'looseLeaf',
  'comic': 'comic',
  'comics': 'comic',
  'comic book': 'comic',
  'fumetto': 'comic',
  'tebeo': 'comic',
  'historieta': 'comic',
  'bd': 'comic',
  'banda desenhada': 'comic',
  'quadrinhos': 'comic',
  'sarjakuva': 'comic',
  'tegneserie': 'comic',
  'cizgi roman': 'comic',
  'seriealbum': 'comic',
  'strip': 'comic',
  'komiks': 'comic',
  'rilegatura bibliotecaria': 'library',
  'fogli mobili': 'looseLeaf',
  'losbladig': 'looseLeaf',
  'grote paperback': 'tradePaperback',
  'kartonowa': 'boardBook',
  'biblioteczna': 'library',
  'spiralna': 'spiral',
  'luzne kartki': 'looseLeaf',
  'elastyczna': 'flexibound',
  'karton kapak': 'tradePaperback',
  'karton kitap': 'boardBook',
  'kutuphane cildi': 'library',
  'spiralli': 'spiral',
  'yaprak': 'looseLeaf',
  'esnek': 'flexibound',
  'pekbok': 'boardBook',
  'biblioteksband': 'library',
  'spiralbunden': 'spiral',
  'e bok': 'ebook',
  'losa blad': 'looseLeaf',
  'papbog': 'boardBook',
  'biblioteksbind': 'library',
  'spiralryg': 'spiral',
  'e bog': 'ebook',
  'losblade': 'looseLeaf',
  'pappebok': 'boardBook',
  'bibliotekbind': 'library',
  'spiralbundet': 'spiral',
  'lose ark': 'looseLeaf',
  'isokokoinen nidottu': 'tradePaperback',
  'e kirja': 'ebook',
  'irtosivut': 'looseLeaf',
  'joustokansi': 'flexibound',
  'kindle': 'kindle',
  'kindle edition': 'kindle',
  'ebook': 'ebook',
  'e book': 'ebook',
  'e-book': 'ebook',
  'digital': 'ebook',
  'nook': 'ebook',
  'nook book': 'ebook',
  'epub': 'ebook',
  'pdf': 'ebook',
  'google ebook': 'ebook',
  'audiobook': 'audiobook',
  'audio book': 'audiobook',
  'audible': 'audiobook',
  'audible audio': 'audiobook',
  'audio cd': 'audiobook',
  'mp3 cd': 'audiobook',
  'audiolibro': 'audiobook',
  'audiollibre': 'audiobook',
  'livre audio': 'audiobook',
  'horbuch': 'audiobook',
  'audioboek': 'audiobook',
  'audiolivro': 'audiobook',
  'sesli kitap': 'audiobook',
  'ljudbok': 'audiobook',
  'lydbog': 'audiobook',
  'lydbok': 'audiobook',
  'aanikirja': 'audiobook',
};
