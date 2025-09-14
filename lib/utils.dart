// ---------------- Shared extractor ----------------
List<String> extractUkupnoValues(String text) {
  final regex = RegExp(r'\d{1,3},\d{2}');
  final matches = <double>[];

  final idx1 = text.toUpperCase().indexOf('UKUP');
  final idx2 = text.toUpperCase().indexOf('TOTAL');
  final idx3 = text.toUpperCase().indexOf('IZNO');

  if (idx1 == -1 && idx2 == -1 && idx3 == -1) return [];

  final start = [idx1, idx2, idx3].reduce((a, b) => a > b ? a : b);
  final after = text.substring(start);

  for (final m in regex.allMatches(after)) {
    matches.add(double.parse(m.group(0)!.replaceAll(',', '.')));
    if (matches.length == 5) break;
  }

  matches.sort((a, b) => b.compareTo(a));
  return matches.map((e) => e.toStringAsFixed(2).replaceAll('.', ',')).toList();
}
