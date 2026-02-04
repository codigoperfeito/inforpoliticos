import 'dart:convert';

import 'package:http/http.dart' as http;

class IbgeApi {
  IbgeApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  Future<List<String>> fetchMunicipios(String uf) async {
    final uri = Uri.parse('$_baseUrl/estados/$uf/municipios');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar municipios.');
    }
    final list = jsonDecode(response.body) as List<dynamic>;
    final names = list
        .whereType<Map<String, dynamic>>()
        .map((item) => (item['nome'] ?? '') as String)
        .where((name) => name.isNotEmpty)
        .toList();
    names.sort();
    return names;
  }
}
