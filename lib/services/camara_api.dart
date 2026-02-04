import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/deputy.dart';
import '../models/proposition.dart';
import '../models/voting.dart';

class CamaraApi {
  CamaraApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl = 'https://dadosabertos.camara.leg.br/api/v2';

  Future<List<Deputy>> fetchDeputies() async {
    final uri = Uri.parse('$_baseUrl/deputados?ordem=ASC&ordenarPor=nome');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar deputados.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    final deputies = list
        .whereType<Map<String, dynamic>>()
        .map(Deputy.fromListJson)
        .toList();
    try {
      final emailMap = await _fetchDeputyEmailsXml();
      if (emailMap.isNotEmpty) {
        return deputies
            .map(
              (item) => item.copyWithEmail(emailMap[item.id]),
            )
            .toList();
      }
    } catch (_) {}
    return deputies;
  }

  Future<Deputy> fetchDeputyDetail(int id) async {
    final uri = Uri.parse('$_baseUrl/deputados/$id');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar detalhes do deputado.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['dados'] as Map<String, dynamic>? ?? {};
    return Deputy.fromDetailJson(data);
  }

  Future<List<Proposition>> fetchPropositions(
    int id, {
    int page = 1,
    int items = 10,
  }) async {
    final uri = Uri.parse('$_baseUrl/proposicoes').replace(
      queryParameters: {
        'idDeputadoAutor': id.toString(),
        'ordem': 'DESC',
        'ordenarPor': 'id',
        'itens': items.toString(),
        'pagina': page.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar proposições.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Proposition.fromJson)
        .toList();
  }

  Future<Proposition> fetchPropositionDetail(int id) async {
    final uri = Uri.parse('$_baseUrl/proposicoes/$id');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar detalhes da proposição.');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['dados'] as Map<String, dynamic>? ?? {};
    return Proposition.fromDetailJson(data);
  }

  Future<String?> fetchPropositionAuthor(int propositionId) async {
    final uri =
        Uri.parse('$_baseUrl/proposicoes/$propositionId/autores');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    if (list.isEmpty) {
      return null;
    }
    final first = list.first as Map<String, dynamic>? ?? {};
    final name = (first['nome'] ?? '') as String;
    return name.trim().isNotEmpty ? name.trim() : null;
  }

  Future<List<Voting>> fetchPropositionVotacoes(int propositionId) async {
    final uri = Uri.parse('$_baseUrl/proposicoes/$propositionId/votacoes');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return [];
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Voting.fromJson)
        .toList();
  }

  Future<List<DeputyVote>> fetchVotingVotes(String votingId) async {
    final uri = Uri.parse('$_baseUrl/votacoes/$votingId/votos');
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return [];
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(DeputyVote.fromJson)
        .toList();
  }

  Future<List<Voting>> fetchRecentVotacoes({
    int items = 5,
    int page = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/votacoes').replace(
      queryParameters: {
        'ordem': 'DESC',
        'ordenarPor': 'dataHoraRegistro',
        'itens': items.toString(),
        'pagina': page.toString(),
      },
    );
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      return [];
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final list = (json['dados'] as List<dynamic>? ?? []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Voting.fromJson)
        .toList();
  }

  Future<String?> fetchVotingEmentaXml(String votingId) async {
    final uri = Uri.parse('$_baseUrl/votacoes/$votingId');
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/xml'},
    );
    if (response.statusCode != 200) {
      return null;
    }
    try {
      final body = _decodeBody(response);
      final document = XmlDocument.parse(body);
      final ementa = document.findAllElements('ementa').isNotEmpty
          ? document.findAllElements('ementa').first.innerText
          : null;
      if (ementa != null && ementa.trim().isNotEmpty) {
        return ementa.trim();
      }
    } catch (_) {}
    return null;
  }
  Future<Map<int, String>> _fetchDeputyEmailsXml() async {
    final uri = Uri.parse('$_baseUrl/deputados')
        .replace(queryParameters: {'ordem': 'ASC', 'ordenarPor': 'nome'});
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/xml'},
    );
    if (response.statusCode != 200) {
      return {};
    }
    final body = _decodeBody(response);
    final document = XmlDocument.parse(body);
    final items = document.findAllElements('deputado');
    final result = <int, String>{};
    for (final item in items) {
      final idText = item.getElement('id')?.innerText ?? '';
      final email = item.getElement('email')?.innerText ?? '';
      final id = int.tryParse(idText);
      if (id != null && email.trim().isNotEmpty) {
        result[id] = email.trim();
      }
    }
    return result;
  }
}

String _decodeBody(http.Response response) {
  final contentType = response.headers['content-type'] ?? '';
  if (contentType.toLowerCase().contains('charset=iso-8859-1')) {
    return latin1.decode(response.bodyBytes);
  }
  return utf8.decode(response.bodyBytes, allowMalformed: true);
}
