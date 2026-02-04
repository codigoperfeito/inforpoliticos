import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SummaryResult {
  SummaryResult({required this.summary, required this.fromCache});

  final String summary;
  final bool fromCache;
}

class SummaryService {
  SummaryService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _endpoint =
      String.fromEnvironment('SUMMARY_API_URL', defaultValue: '');

  Future<SummaryResult> getSummary({
    required int propositionId,
    required String text,
  }) async {
    final cacheKey = 'summary_$propositionId';
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      return SummaryResult(summary: cached, fromCache: true);
    }

    if (_endpoint.isEmpty) {
      final summary = _offlineSummary(text);
      await prefs.setString(cacheKey, summary);
      return SummaryResult(summary: summary, fromCache: false);
    }

    final uri = Uri.parse(_endpoint);
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
      }),
    );
    if (response.statusCode != 200) {
      final summary = _offlineSummary(text);
      await prefs.setString(cacheKey, summary);
      return SummaryResult(summary: summary, fromCache: false);
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final summary = (json['summary'] ?? '') as String;
    final cleaned = summary.isNotEmpty ? summary : _offlineSummary(text);
    await prefs.setString(cacheKey, cleaned);
    return SummaryResult(summary: cleaned, fromCache: false);
  }

  String _offlineSummary(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Sem resumo disponível.';
    }
    final sentences = trimmed.split(RegExp(r'(?<=[.!?])\s+'));
    final first = sentences.isNotEmpty ? sentences.first : trimmed;
    final second = sentences.length > 1 ? sentences[1] : '';
    final simpleAim = _inferSimpleAim(trimmed);
    final impacts = _inferImpacts(trimmed);
    final complex = _extractComplexTerms(trimmed);

    final buffer = StringBuffer()
      ..writeln('Sobre o que trata:')
      ..writeln(first.trim())
      ..writeln()
      ..writeln('Em termos simples:')
      ..writeln(simpleAim)
      ..writeln();

    if (second.isNotEmpty) {
      buffer.writeln('Ponto importante:');
      buffer.writeln(second.trim());
      buffer.writeln();
    }

    buffer.writeln('Possíveis efeitos:');
    for (final item in impacts) {
      buffer.writeln('- $item');
    }

    buffer.writeln();
    buffer.writeln('Possíveis prós:');
    buffer.writeln('- Pode deixar regras mais claras e fáceis de aplicar.');
    buffer.writeln('- Pode reduzir dúvidas sobre direitos e deveres.');
    buffer.writeln();
    buffer.writeln('Possíveis contras:');
    buffer.writeln('- Pode exigir adaptação de órgãos ou cidadãos.');
    buffer.writeln('- Pode gerar custos ou mudanças de rotina.');

    if (complex.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Termos mais complexos (em linguagem simples):');
      for (final item in complex) {
        buffer.writeln('- $item');
      }
    }

    return buffer.toString().trim();
  }

  String _inferSimpleAim(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('institui') || lower.contains('cria')) {
      return 'Cria uma regra ou programa novo para organizar melhor o tema.';
    }
    if (lower.contains('altera') || lower.contains('modifica')) {
      return 'Muda regras já existentes para ajustar como algo funciona.';
    }
    if (lower.contains('dispõe') || lower.contains('estabelece')) {
      return 'Define regras sobre o assunto para dar mais clareza.';
    }
    if (lower.contains('autoriza')) {
      return 'Permite oficialmente que algo seja feito.';
    }
    if (lower.contains('proíbe') || lower.contains('vedar')) {
      return 'Impede oficialmente que algo seja feito.';
    }
    return 'Explica o objetivo e as regras principais sobre o tema.';
  }

  List<String> _inferImpacts(String text) {
    final lower = text.toLowerCase();
    final impacts = <String>[];
    if (lower.contains('orçament') || lower.contains('fiscal')) {
      impacts.add('Pode impactar gastos públicos ou regras fiscais.');
    }
    if (lower.contains('tribut') || lower.contains('imposto')) {
      impacts.add('Pode alterar impostos ou cobranças.');
    }
    if (lower.contains('saúde')) {
      impacts.add('Pode mudar serviços de saúde ou acesso da população.');
    }
    if (lower.contains('educa')) {
      impacts.add('Pode afetar escolas, universidades ou formação profissional.');
    }
    if (impacts.isEmpty) {
      impacts.add('Pode mudar procedimentos e responsabilidades no tema.');
    }
    return impacts;
  }

  List<String> _extractComplexTerms(String text) {
    final terms = <String, String>{
      'orçamentário': 'relacionado ao orçamento público',
      'fiscal': 'regras sobre gastos e contas públicas',
      'tributário': 'regras sobre impostos e taxas',
      'previdenciário': 'relacionado à previdência e aposentadoria',
      'licitatório': 'regras de contratação e compras do governo',
      'regulamenta': 'detalha como a lei será aplicada',
      'sanção': 'aprovação final pelo chefe do executivo',
      'concessão': 'permissão para empresas operarem serviços públicos',
    };
    final lower = text.toLowerCase();
    final matches = <String>[];
    terms.forEach((key, value) {
      if (lower.contains(key)) {
        matches.add('$key: $value');
      }
    });
    return matches;
  }
}
