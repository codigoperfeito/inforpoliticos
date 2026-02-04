class Proposition {
  Proposition({
    required this.id,
    required this.title,
    required this.summary,
    required this.uri,
    this.statusDescription,
    this.detailedSummary,
    this.relatorName,
    this.authorName,
  });

  final int id;
  final String title;
  final String summary;
  final String uri;
  final String? statusDescription;
  final String? detailedSummary;
  final String? relatorName;
  final String? authorName;

  bool get isApproved {
    final text = (statusDescription ?? '').toLowerCase();
    return text.contains('aprovad') ||
        text.contains('transformado') ||
        text.contains('promulgad');
  }

  String get statusLabel {
    if (statusDescription == null || statusDescription!.isEmpty) {
      return 'Status não informado';
    }
    return statusDescription!;
  }

  static Proposition fromJson(Map<String, dynamic> json) {
    final sigla = (json['siglaTipo'] ?? '') as String;
    final numero = (json['numero'] ?? '') as Object;
    final ano = (json['ano'] ?? '') as Object;
    final title = '$sigla $numero/$ano'.trim();

    return Proposition(
      id: json['id'] as int,
      title: title.isEmpty ? 'Proposição' : title,
      summary: (json['ementa'] ?? '') as String,
      uri: (json['uri'] ?? '') as String,
    );
  }

  static Proposition fromDetailJson(Map<String, dynamic> json) {
    final base = fromJson(json);
    final status = json['statusProposicao'] as Map<String, dynamic>? ?? {};
    final description = (status['descricaoSituacao'] ?? '') as String;
    final detailed = (json['ementaDetalhada'] ??
            json['justificativa'] ??
            '') as String;
    String? relatorName;
    final relator = status['relator'];
    if (relator is Map<String, dynamic>) {
      relatorName = (relator['nome'] ?? '') as String;
    } else if (relator is String) {
      relatorName = relator;
    }
    if ((relatorName ?? '').isEmpty) {
      final fallback = status['nomeRelator'] as String?;
      if ((fallback ?? '').isNotEmpty) {
        relatorName = fallback;
      }
    }
    return Proposition(
      id: base.id,
      title: base.title,
      summary: base.summary,
      uri: base.uri,
      statusDescription: description,
      detailedSummary: detailed,
      relatorName: relatorName?.trim().isNotEmpty == true ? relatorName : null,
    );
  }

  static Proposition fromCacheJson(Map<String, dynamic> json) {
    return Proposition(
      id: json['id'] as int,
      title: (json['title'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      uri: (json['uri'] ?? '') as String,
      statusDescription: json['statusDescription'] as String?,
      detailedSummary: json['detailedSummary'] as String?,
      relatorName: json['relatorName'] as String?,
      authorName: json['authorName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'uri': uri,
      'statusDescription': statusDescription,
      'detailedSummary': detailedSummary,
      'relatorName': relatorName,
      'authorName': authorName,
    };
  }

  Proposition copyWith({
    String? relatorName,
    String? authorName,
  }) {
    return Proposition(
      id: id,
      title: title,
      summary: summary,
      uri: uri,
      statusDescription: statusDescription,
      detailedSummary: detailedSummary,
      relatorName: relatorName ?? this.relatorName,
      authorName: authorName ?? this.authorName,
    );
  }
}
