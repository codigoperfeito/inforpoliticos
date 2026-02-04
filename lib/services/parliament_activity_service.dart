import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/expense.dart';
import '../models/presence_stats.dart';

class ParliamentActivityService {
  ParliamentActivityService({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://dadosabertos.camara.leg.br/api/v2';
  static const _presenceUrl =
      'https://www.camara.gov.br/SitCamaraWS/SessoesReunioes.asmx/'
      'ListarPresencasParlamentar';

  Future<List<ExpenseItem>> fetchExpenses(
    int deputyId, {
    int page = 1,
    int items = 10,
    int? year,
  }) async {
    final params = <String, String>{
      'ordem': 'DESC',
      'ordenarPor': 'dataDocumento',
      'itens': items.toString(),
      'pagina': page.toString(),
    };
    if (year != null) {
      params['ano'] = year.toString();
    }
    final uri = Uri.parse('$_baseUrl/deputados/$deputyId/despesas')
        .replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return [];
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(ExpenseItem.fromJson)
        .toList();
  }

  Future<PresenceStats?> fetchPresence(int deputyId) async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));
    final startStr = _formatDate(start);
    final endStr = _formatDate(now);

    final uri = Uri.parse(_presenceUrl).replace(
      queryParameters: {
        'dataIni': startStr,
        'dataFim': endStr,
        'numMatriculaParlamentar': deputyId.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    final document = XmlDocument.parse(response.body);
    final sessions = document.findAllElements('diaDeSessao');
    if (sessions.isEmpty) {
      return null;
    }

    var presences = 0;
    var absences = 0;
    for (final session in sessions) {
      final value = session.getElement('presenca')?.innerText.toLowerCase() ??
          session.getElement('descricaoPresenca')?.innerText.toLowerCase() ??
          '';
      if (value.contains('presente') || value == 'p') {
        presences += 1;
      } else {
        absences += 1;
      }
    }

    return PresenceStats(
      presences: presences,
      absences: absences,
      total: sessions.length,
      startDate: startStr,
      endDate: endStr,
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
