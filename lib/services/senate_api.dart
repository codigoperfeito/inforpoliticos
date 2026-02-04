import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/senator.dart';
import '../models/senator_ceaps.dart';
import '../models/senator_expense.dart';

class SenateApi {
  SenateApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _listUrl =
      'https://legis.senado.leg.br/dadosabertos/senador/lista/atual.json';
  static const _detailBaseUrl =
      'https://legis.senado.leg.br/dadosabertos/senador';
  static const _ceapsBaseUrl =
      'https://adm.senado.gov.br/adm-dadosabertos/api/v1/senadores/despesas_ceaps';

  static const _jsonHeaders = {'Accept': 'application/json'};
  static const _userAgent = 'InfoPoliticos/1.0';

  Future<List<Senator>> fetchSenators() async {
    final response = await _getJson(Uri.parse(_listUrl));
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar senadores. HTTP ${response.statusCode}.');
    }
    final body = utf8.decode(response.bodyBytes);
    return _parseSenatorsList(body);
  }

  Future<Senator> fetchSenatorDetail(int id) async {
    final uri = Uri.parse('$_detailBaseUrl/$id.json');
    final response = await _getJson(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Falha ao buscar detalhes do senador. HTTP ${response.statusCode}.',
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes))
        as Map<String, dynamic>;
    return Senator.fromDetailJson(json);
  }

  Future<SenatorCeaps> fetchSenatorCeaps({
    required int id,
    required int year,
  }) async {
    final uri = Uri.parse('$_ceapsBaseUrl/$year')
        .replace(queryParameters: {'senadorId': id.toString()});
    final response = await _getJson(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao buscar CEAPS. HTTP ${response.statusCode}.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    return _parseCeaps(decoded, id);
  }

  Future<http.Response> _getJson(Uri uri) async {
    final headers = <String, String>{
      ..._jsonHeaders,
      if (!kIsWeb) 'User-Agent': _userAgent,
    };
    final response =
        await _client.get(uri, headers: headers).timeout(const Duration(seconds: 20));
    if (kDebugMode) {
      debugPrint('SenateApi ${response.statusCode} ${uri.toString()}');
    }
    return response;
  }

  List<Senator> _parseSenatorsList(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final root = decoded['ListaParlamentarEmExercicio'] ??
        decoded['listaParlamentarEmExercicio'] ??
        decoded;
    final parlamentares = (root is Map<String, dynamic>)
        ? (root['Parlamentares'] ?? root['parlamentares'] ?? root)
        : root;
    final rawList = (parlamentares is Map<String, dynamic>)
        ? (parlamentares['Parlamentar'] ?? parlamentares['parlamentar'] ?? [])
        : parlamentares;
    final list = rawList is List ? rawList : (rawList == null ? [] : [rawList]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(Senator.fromJson)
        .where((s) => s.displayName.trim().isNotEmpty)
        .toList();
  }

  SenatorCeaps _parseCeaps(dynamic decoded, int senatorId) {
    final items = <SenatorExpense>[];
    num? totalFromApi;

    if (decoded is Map<String, dynamic>) {
      totalFromApi = _readNum(decoded, ['total', 'valorTotal', 'totalGasto']);
      final data = decoded['data'] ??
          decoded['dados'] ??
          decoded['lista'] ??
          decoded['despesas'] ??
          decoded['itens'];
      _collectExpenses(data, items, senatorId);
    } else if (decoded is List) {
      _collectExpenses(decoded, items, senatorId);
    }

    if (items.isEmpty) {
      // Fallback: if the API does not include senator id per item, keep all.
      _collectExpenses(
        (decoded is Map<String, dynamic>)
            ? (decoded['data'] ??
                decoded['dados'] ??
                decoded['lista'] ??
                decoded['despesas'] ??
                decoded['itens'])
            : decoded,
        items,
        null,
      );
    }

    final total = totalFromApi ??
        items.fold<num>(0, (sum, item) => sum + (item.amount ?? 0));
    return SenatorCeaps(total: total, expenses: items);
  }

  void _collectExpenses(
    dynamic data,
    List<SenatorExpense> out,
    int? senatorId,
  ) {
    if (data is List) {
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          if (senatorId == null || _matchesSenator(item, senatorId)) {
            out.add(SenatorExpense.fromJson(item));
          }
        }
      }
    } else if (data is Map<String, dynamic>) {
      if (senatorId == null || _matchesSenator(data, senatorId)) {
        out.add(SenatorExpense.fromJson(data));
      }
    }
  }

  bool _matchesSenator(Map<String, dynamic> json, int senatorId) {
    final possibleKeys = [
      'senadorId',
      'senador_id',
      'codSenador',
      'cod_senador',
      'codigoParlamentar',
      'CodigoParlamentar',
      'idParlamentar',
      'parlamentarId',
      'idSenador',
    ];
    for (final key in possibleKeys) {
      final value = json[key];
      final parsed = _toInt(value);
      if (parsed != 0 && parsed == senatorId) {
        return true;
      }
    }
    return false;
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  num? _readNum(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value is num) return value;
      if (value is String) {
        final parsed = num.tryParse(value.replaceAll(',', '.'));
        if (parsed != null) return parsed;
      }
    }
    return null;
  }
}
