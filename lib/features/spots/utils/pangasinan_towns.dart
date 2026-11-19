/// Fixed place lists for posting a spot (team review 2026-11-19: "have a
/// predetermined set of location combobox for municipality and province").
///
/// Mirrors backend `PANGASINAN_MUNICIPALITIES` (src/routes/affiliates.ts),
/// the same names `/me/home-town` and `/affiliate/options` use, so the value
/// sent as `municipality` matches the rest of the system.
const Map<String, List<String>> spotProvinceTowns = {
  'Pangasinan': [
    'Agno',
    'Aguilar',
    'Alaminos City',
    'Alcala',
    'Anda',
    'Asingan',
    'Balungao',
    'Bani',
    'Basista',
    'Bautista',
    'Bayambang',
    'Binalonan',
    'Binmaley',
    'Bolinao',
    'Bugallon',
    'Burgos',
    'Calasiao',
    'Dagupan City',
    'Dasol',
    'Infanta',
    'Labrador',
    'Laoac',
    'Lingayen',
    'Mabini',
    'Malasiqui',
    'Manaoag',
    'Mangaldan',
    'Mangatarem',
    'Mapandan',
    'Natividad',
    'Pozorrubio',
    'Rosales',
    'San Carlos City',
    'San Fabian',
    'San Jacinto',
    'San Manuel',
    'San Nicolas',
    'San Quintin',
    'Santa Barbara',
    'Santa Maria',
    'Santo Tomas',
    'Sison',
    'Sual',
    'Tayug',
    'Umingan',
    'Urbiztondo',
    'Urdaneta City',
    'Villasis',
  ],
};

const String defaultSpotProvince = 'Pangasinan';

String _townKey(String raw) {
  var s = raw.toLowerCase().replaceAll(RegExp(r'\(.*?\)'), ' ');
  s = s
      .replaceAll(RegExp(r'\bcity of\b'), ' ')
      .replaceAll(RegExp(r'\bmunicipality of\b'), ' ')
      .replaceAll(RegExp(r'\bcity\b'), ' ')
      .replaceAll(RegExp(r'\bsta\.?(?=\s)'), 'santa')
      .replaceAll(RegExp(r'\bsto\.?(?=\s)'), 'santo');
  return s.replaceAll(RegExp(r'[^a-z]+'), ' ').trim();
}

/// The listed town a GPS/PSGC name refers to ("City of Dagupan",
/// "Lingayen (Capital)", "Sta. Barbara"), or null when it is not listed.
String? canonicalSpotTown(String? raw,
    {String province = defaultSpotProvince}) {
  if (raw == null || raw.trim().isEmpty) return null;
  final key = _townKey(raw);
  for (final town in spotProvinceTowns[province] ?? const <String>[]) {
    if (_townKey(town) == key) return town;
  }
  return null;
}
