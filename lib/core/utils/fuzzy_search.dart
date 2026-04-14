import 'package:characters/characters.dart';

class FuzzySearch {
  FuzzySearch._();

  /// Remove acentos e normaliza para lowercase
  static String _normalize(String s) {
    const accents = 'àáâãäåèéêëìíîïòóôõöùúûüýÿñçÀÁÂÃÄÅÈÉÊËÌÍÎÏÒÓÔÕÖÙÚÛÜÝŸÑÇ';
    const normal  = 'aaaaaaeeeeiiiioooooouuuuyyñcAAAAAAEEEEIIIIOOOOOOUUUUYYNC';
    final buffer = StringBuffer();
    for (final ch in s.characters) {
      final idx = accents.indexOf(ch);
      buffer.write(idx >= 0 ? normal[idx] : ch);
    }
    return buffer.toString().toLowerCase();
  }

  /// Distância de Levenshtein entre duas strings curtas
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => i == 0 ? j : (j == 0 ? i : 0)),
    );
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  /// Verifica se [query] corresponde a [target] com tolerância a erros.
  /// Divide a query em palavras e verifica cada uma contra os tokens do target.
  static bool matches(String query, String target) {
    if (query.isEmpty) return true;
    final q = _normalize(query);
    final t = _normalize(target);

    // Busca exata por substring primeiro (mais rápida)
    if (t.contains(q)) return true;

    final queryTokens  = q.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final targetTokens = t.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();

    // Cada palavra da query deve ter um match no target
    for (final qToken in queryTokens) {
      final hasMatch = targetTokens.any((tToken) {
        if (tToken.contains(qToken) || qToken.contains(tToken)) return true;
        // Tolerância: até 2 erros para palavras longas, 1 para curtas
        final maxDist = qToken.length <= 4 ? 1 : 2;
        return _levenshtein(qToken, tToken) <= maxDist;
      });
      if (!hasMatch) return false;
    }
    return true;
  }
}